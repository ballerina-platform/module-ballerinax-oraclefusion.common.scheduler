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

// Builds an operational dashboard over Oracle Fusion scheduled processes: lists the
// currently running requests, finds the ones that failed, and drills into the first
// failure to retrieve its full parameter set and error detail.

import ballerina/io;
import ballerinax/oraclefusion.common.scheduler;

// Configuration - create a Config.toml with these values before running
configurable string serviceUrl = ?;
configurable string username = ?;
configurable string password = ?;

public function main() returns error? {
    scheduler:Client schedulerClient = check new ({auth: {username, password}}, serviceUrl);

    // Step 1: List the requests that are currently executing, newest first.
    scheduler:RequestQueryResponse running = check schedulerClient->queryJobRequests(
        queries = {
            q: "state eq \"RUNNING\"",
            orderBy: "submissionTime:desc",
            fields: "requestId,description,state,submitter,elapsedTime"
        }
    );

    scheduler:RequestDetails[] runningItems = running.items ?: [];
    io:println(string `--- Running processes (${runningItems.length()}) ---`);
    foreach scheduler:RequestDetails request in runningItems {
        io:println(string `[${request.requestId ?: 0}] ${request.description ?: "N/A"}`);
        io:println(string `    submitter: ${request.submitter ?: "N/A"}, elapsed: ${request.elapsedTime ?: 0} ms`);
    }

    // Step 2: Find the requests that ended in error.
    scheduler:RequestQueryResponse failed = check schedulerClient->queryJobRequests(
        queries = {
            q: "state eq \"ERROR\"",
            orderBy: "completedTime:desc",
            fields: "requestId,description,state,errorType,completedTime"
        }
    );

    scheduler:RequestDetails[] failedItems = failed.items ?: [];
    io:println(string `--- Failed processes (${failedItems.length()}) ---`);
    foreach scheduler:RequestDetails request in failedItems {
        io:println(string `[${request.requestId ?: 0}] ${request.description ?: "N/A"}`);
        io:println(string `    errorType: ${request.errorType ?: "N/A"}, completed: ${request.completedTime ?: "N/A"}`);
    }

    // Step 3: Drill into the most recent failure for its full detail.
    if failedItems.length() == 0 {
        io:println("No failed requests to investigate.");
        return;
    }

    int requestId = failedItems[0].requestId ?: 0;
    scheduler:RequestDetails details = check schedulerClient->getJobRequest(requestId);

    io:println(string `--- Detail for request ${requestId} ---`);
    io:println("Job definition:    ", details.jobDefinitionId ?: "N/A");
    io:println("State:             ", details.state ?: "N/A");
    io:println("State description: ", details.stateDescription ?: "N/A");
    io:println("Error type:        ", details.errorType ?: "N/A");
    io:println("Submitted at:      ", details.submissionTime ?: "N/A");

    scheduler:RequestParameter[] parameters = details.requestParameters ?: [];
    io:println(string `Request parameters (${parameters.length()}):`);
    foreach scheduler:RequestParameter param in parameters {
        io:println(string `    ${param.name} (${param.paramType}) = ${param.value ?: ""}`);
    }
}
