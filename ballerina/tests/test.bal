// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/os;
import ballerina/test;

final boolean isLiveServer = os:getEnv("IS_LIVE_SERVER") == "true";

final string serviceUrl = isLiveServer ?
    os:getEnv("ORACLE_FUSION_SERVICE_URL") :
    "http://localhost:9090/ess/rest/scheduler/v1";

final string username = isLiveServer ? os:getEnv("ORACLE_FUSION_USERNAME") : "testUsername";
final string password = isLiveServer ? os:getEnv("ORACLE_FUSION_PASSWORD") : "testPassword";

# A job definition ID that exists on the target instance. Only used by the live tests.
final string jobDefinitionId = isLiveServer ?
    os:getEnv("ORACLE_FUSION_JOB_DEFINITION_ID") :
    "oracle/apps/ess/financials/payables/invoices/transactions/ImportPayablesInvoicesJob";

final Client scheduler = check initClient();

isolated function initClient() returns Client|error {
    http:CredentialsConfig auth = {username, password};
    ConnectionConfig config = {auth};
    return new Client(config, serviceUrl);
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testQueryJobRequests() returns error? {
    RequestQueryResponse response = check scheduler->queryJobRequests();
    test:assertTrue(response.items !is (), "Expected an items collection in the query response");
    RequestDetails[] items = response.items ?: [];
    if items.length() == 0 {
        // A live tenant may legitimately hold no job requests yet, so only the response shape is
        // guaranteed there. The mock always serves fixtures, so an empty collection is a failure.
        test:assertTrue(isLiveServer, "Expected at least one job request from the mock server");
        return;
    }
    test:assertTrue(items[0].requestId !is (), "Expected each job request to carry a requestId");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testQueryJobRequestsWithFilter() returns error? {
    RequestQueryResponse response = check scheduler->queryJobRequests(
        queries = {q: "state eq \"SUCCEEDED\"", orderBy: "submissionTime:desc", fields: "requestId,state,description"}
    );
    RequestDetails[] items = response.items ?: [];
    if items.length() == 0 {
        // Nothing in this suite can produce a SUCCEEDED request - a submitted request is still
        // WAIT/READY/RUNNING when the test ends - so on a live tenant this depends entirely on
        // pre-existing history. The per-item filter and projection checks below still run whenever
        // the tenant does have SUCCEEDED requests.
        test:assertTrue(isLiveServer, "Expected at least one SUCCEEDED job request from the mock server");
        return;
    }

    string previousSubmissionTime = "";
    foreach RequestDetails item in items {
        // `q` was applied - nothing outside the requested state came back.
        test:assertEquals(item.state, "SUCCEEDED", "The `q` filter was not applied to the result");

        // `fields` was applied - a field outside the projection is absent.
        test:assertTrue(item.requestId !is (), "`requestId` was requested but is missing");
        test:assertTrue(item.submitter is (), "`submitter` was outside `fields` but was returned");
        test:assertTrue(item.jobDefinitionId is (), "`jobDefinitionId` was outside `fields` but was returned");

        // `orderBy` was applied - submissionTime is non-increasing. Skipped when the field was
        // projected away, which is the case here, so this only guards a widened `fields` list.
        string submissionTime = item.submissionTime ?: "";
        if previousSubmissionTime != "" && submissionTime != "" {
            test:assertTrue(submissionTime <= previousSubmissionTime,
                    "`orderBy` submissionTime:desc was not applied to the result");
        }
        previousSubmissionTime = submissionTime;
    }
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testQueryJobRequestsByIdAndExcludeFields() returns error? {
    // Resolve a real request ID first so the test works against a live instance too.
    RequestQueryResponse all = check scheduler->queryJobRequests(queries = {orderBy: "submissionTime:desc"});
    RequestDetails[] allItems = all.items ?: [];
    if allItems.length() == 0 {
        // No request to filter on. Live tenants may be empty; the mock never is.
        test:assertTrue(isLiveServer, "Cannot resolve a requestId - the mock server returned no items");
        return;
    }

    string previousSubmissionTime = "";
    foreach RequestDetails item in allItems {
        string submissionTime = item.submissionTime ?: "";
        if previousSubmissionTime != "" && submissionTime != "" {
            test:assertTrue(submissionTime <= previousSubmissionTime,
                    "`orderBy` submissionTime:desc was not applied to the unfiltered query");
        }
        previousSubmissionTime = submissionTime;
    }

    int? resolvedRequestId = allItems[0].requestId;
    if resolvedRequestId is () {
        test:assertFail("The query response did not carry a requestId to filter on");
    }

    RequestQueryResponse response = check scheduler->queryJobRequests(
        queries = {id: resolvedRequestId.toString(), excludeFields: "requestParameters,links"}
    );

    RequestDetails[] items = response.items ?: [];
    // `id` was applied - exactly the requested request came back.
    test:assertEquals(items.length(), 1, "The `id` filter was not applied to the result");
    test:assertEquals(items[0].requestId, resolvedRequestId, "The `id` filter returned the wrong request");

    // `excludeFields` was applied - the excluded fields are absent, others survive.
    test:assertTrue(items[0].requestParameters is (), "`requestParameters` was excluded but was returned");
    test:assertTrue(items[0].links is (), "`links` was excluded but was returned");
    test:assertTrue(items[0].state !is (), "`state` was not excluded and should have been returned");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testSubmitJobRequest() returns error? {
    SubmitRequestBody payload = {
        jobDefinitionId,
        application: "FinancialsEss",
        description: "Submitted by the Ballerina connector test suite",
        priority: 4,
        requestParameters: [
            {name: "BusinessUnit", paramType: "STRING", value: "US1 Business Unit"}
        ]
    };
    SubmitRequestResponse response = check scheduler->submitJobRequest(payload);
    test:assertTrue(response.id !is (), "Expected the submitted request to return an id");
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testSubmitJobRequest]
}
isolated function testGetJobRequest() returns error? {
    RequestQueryResponse queryResponse = check scheduler->queryJobRequests();
    RequestDetails[] items = queryResponse.items ?: [];
    test:assertTrue(items.length() > 0, "Cannot resolve a requestId to fetch - the query returned no items");

    int? resolvedRequestId = items[0].requestId;
    if resolvedRequestId is () {
        // Fail on the missing precondition itself. Falling back to a placeholder ID would fetch
        // the wrong resource and let the assertions below pass against it.
        test:assertFail("The query response did not carry a requestId to fetch");
    }

    RequestDetails response = check scheduler->getJobRequest(resolvedRequestId);
    test:assertEquals(response.requestId, resolvedRequestId, "Fetched the wrong job request");
    test:assertTrue(response.state !is (), "Expected the job request to carry an execution state");
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testSubmitJobRequest]
}
isolated function testGetJobRequestWithFieldsAndLinks() returns error? {
    // Resolve a real request ID first so the test works against a live instance too.
    RequestQueryResponse queryResponse = check scheduler->queryJobRequests();
    RequestDetails[] items = queryResponse.items ?: [];
    test:assertTrue(items.length() > 0, "Cannot resolve a requestId to fetch - the query returned no items");

    int? resolvedRequestId = items[0].requestId;
    if resolvedRequestId is () {
        test:assertFail("The query response did not carry a requestId to fetch");
    }

    // `fields` was applied - the requested fields are present, anything outside is absent.
    RequestDetails projected = check scheduler->getJobRequest(resolvedRequestId,
        queries = {fields: "requestId,state,links"}
    );
    test:assertTrue(projected.requestId !is (), "`requestId` was requested but is missing");
    test:assertTrue(projected.state !is (), "`state` was requested but is missing");
    test:assertTrue(projected.submitter is (), "`submitter` was outside `fields` but was returned");
    test:assertTrue(projected.requestParameters is (), "`requestParameters` was outside `fields` but was returned");

    // `excludeFields` was applied - the excluded field is gone, others survive.
    RequestDetails trimmed = check scheduler->getJobRequest(resolvedRequestId,
        queries = {excludeFields: "requestParameters,jobDefinitionId"}
    );
    test:assertTrue(trimmed.requestParameters is (), "`requestParameters` was excluded but was returned");
    test:assertTrue(trimmed.jobDefinitionId is (), "`jobDefinitionId` was excluded but was returned");
    test:assertTrue(trimmed.state !is (), "`state` was not excluded and should have been returned");

    // `links` was applied - only the requested relation comes back.
    RequestDetails linked = check scheduler->getJobRequest(resolvedRequestId, queries = {links: "self"});
    RequestLink[] relations = linked.links ?: [];
    test:assertTrue(relations.length() > 0, "Expected the `self` link relation to be returned");
    foreach RequestLink link in relations {
        test:assertEquals(link.rel, "self", "The `links` filter was not applied to the result");
    }
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testSubmitSubRequestWithExecutionContext() returns error? {
    // `requestExecutionContext` identifies the running request creating a sub-request, so a valid
    // `requestHandle` can only come from inside an executing ESS job. That cannot be fabricated
    // against a live instance, which is why this case is `mock_tests`-only.
    SubmitRequestBody payload = {
        jobDefinitionId,
        application: "FinancialsEss",
        description: "Sub-request submitted by the Ballerina connector test suite",
        requestExecutionContext: {requestHandle: "test-request-handle", requestId: 300000012345678}
    };

    SubmitRequestResponse response = check scheduler->submitJobRequest(payload);
    test:assertTrue(response.id !is (), "Expected the submitted sub-request to return an id");

    // The parent came back, so `requestExecutionContext` reached the server.
    RequestLink[] links = response.links ?: [];
    RequestLink[] parentLinks = from RequestLink link in links
        where link.rel == "parentRequest"
        select link;
    test:assertEquals(parentLinks.length(), 1, "`requestExecutionContext` was not transmitted");
    test:assertTrue(parentLinks[0].href.endsWith("/300000012345678"),
            "The `parentRequest` link does not reference the supplied parent requestId");
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testSubmitJobRequestWithEmptyJobDefinition() returns error? {
    SubmitRequestBody payload = {jobDefinitionId: ""};
    SubmitRequestResponse|error response = scheduler->submitJobRequest(payload);
    test:assertTrue(response is error, "Expected an error for an empty jobDefinitionId");
}
