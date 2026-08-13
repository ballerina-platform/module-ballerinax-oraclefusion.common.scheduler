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
    RequestQueryResponse response = check scheduler->/requests();
    test:assertTrue(response.items !is (), "Expected an items collection in the query response");
    RequestDetails[] items = response.items ?: [];
    test:assertTrue(items.length() > 0, "Expected at least one job request");
    test:assertTrue(items[0].requestId !is (), "Expected each job request to carry a requestId");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testQueryJobRequestsWithFilter() returns error? {
    RequestQueryResponse response = check scheduler->/requests(
        queries = {q: "state eq \"SUCCEEDED\"", orderBy: "submissionTime:desc", fields: "requestId,state,description"}
    );
    RequestDetails[] items = response.items ?: [];
    test:assertTrue(items.length() > 0, "Expected at least one SUCCEEDED job request");

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
    RequestQueryResponse all = check scheduler->/requests(queries = {orderBy: "submissionTime:desc"});
    RequestDetails[] allItems = all.items ?: [];
    test:assertTrue(allItems.length() > 0, "Cannot resolve a requestId - the unfiltered query returned no items");

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

    RequestQueryResponse response = check scheduler->/requests(
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
    SubmitRequestResponse response = check scheduler->/requests.post(payload);
    test:assertTrue(response.id !is (), "Expected the submitted request to return an id");
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testSubmitJobRequest]
}
isolated function testGetJobRequest() returns error? {
    RequestQueryResponse queryResponse = check scheduler->/requests();
    RequestDetails[] items = queryResponse.items ?: [];
    test:assertTrue(items.length() > 0, "Cannot resolve a requestId to fetch - the query returned no items");

    int? resolvedRequestId = items[0].requestId;
    if resolvedRequestId is () {
        // Fail on the missing precondition itself. Falling back to a placeholder ID would fetch
        // the wrong resource and let the assertions below pass against it.
        test:assertFail("The query response did not carry a requestId to fetch");
    }

    RequestDetails response = check scheduler->/requests/[resolvedRequestId]();
    test:assertEquals(response.requestId, resolvedRequestId, "Fetched the wrong job request");
    test:assertTrue(response.state !is (), "Expected the job request to carry an execution state");
}

@test:Config {
    groups: ["mock_tests"]
}
isolated function testSubmitJobRequestWithEmptyJobDefinition() returns error? {
    SubmitRequestBody payload = {jobDefinitionId: ""};
    SubmitRequestResponse|error response = scheduler->/requests.post(payload);
    test:assertTrue(response is error, "Expected an error for an empty jobDefinitionId");
}
