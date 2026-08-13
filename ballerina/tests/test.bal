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
    test:assertTrue(response.items !is (), "Expected an items collection for the filtered query");
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

    int requestId = items[0].requestId ?: 0;
    RequestDetails response = check scheduler->/requests/[requestId]();
    test:assertEquals(response.requestId, requestId, "Fetched the wrong job request");
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
