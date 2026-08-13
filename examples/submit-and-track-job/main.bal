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

// Submits an Oracle Fusion scheduled process (ESS job) and then polls the request
// until it reaches a terminal state, printing the final execution outcome.

import ballerina/io;
import ballerina/lang.runtime;
import ballerinax/oraclefusion.common.scheduler;

// Configuration - create a Config.toml with these values before running
configurable string serviceUrl = ?;
configurable string username = ?;
configurable string password = ?;
configurable string jobDefinitionId = ?;

// Terminal ESS request states - polling stops when one of these is reached.
final readonly & string[] terminalStates = [
    "SUCCEEDED",
    "ERROR",
    "WARNING",
    "CANCELLED",
    "EXPIRED",
    "VALIDATION_FAILED",
    "ERROR_AUTO_RETRY",
    "FINISHED"
];

public function main() returns error? {
    scheduler:Client schedulerClient = check new ({auth: {username, password}}, serviceUrl);

    // Step 1: Submit the scheduled process with its job-specific parameters.
    scheduler:SubmitRequestBody payload = {
        jobDefinitionId,
        application: "FinancialsEss",
        description: "Import Payables Invoices - submitted from Ballerina",
        priority: 4,
        requestParameters: [
            {name: "BusinessUnit", paramType: "STRING", value: "US1 Business Unit"},
            {name: "ImportSource", paramType: "STRING", value: "Spreadsheet"}
        ]
    };

    scheduler:SubmitRequestResponse submission = check schedulerClient->/requests.post(payload);
    int? submittedId = submission.id;
    if submittedId is () {
        return error("The scheduler did not return a request ID for the submitted job.");
    }
    io:println("Submitted job request. Request ID: ", submittedId);

    // Step 2: Poll the request until it reaches a terminal state.
    string state = "";
    scheduler:RequestDetails details = {};
    foreach int attempt in 1 ... 20 {
        details = check schedulerClient->/requests/[submittedId]();
        state = details.state ?: "UNKNOWN";
        io:println(string `Attempt ${attempt}: state = ${state}`);

        if terminalStates.indexOf(state) !is () {
            break;
        }
        // Wait before the next poll - ESS requests are rarely instantaneous.
        runtime:sleep(15);
    }

    // Step 3: Report the final outcome.
    io:println("--- Final outcome ---");
    io:println("Request ID:   ", details.requestId ?: submittedId);
    io:println("State:        ", state);
    io:println("Description:  ", details.stateDescription ?: "N/A");
    io:println("Elapsed (ms): ", details.elapsedTime ?: 0);

    if state == "ERROR" || state == "VALIDATION_FAILED" {
        io:println("Error type:   ", details.errorType ?: "N/A");
    }
}
