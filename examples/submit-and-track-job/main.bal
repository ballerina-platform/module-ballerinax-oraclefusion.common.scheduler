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

// Give up after this many polls. At the interval below that is roughly five minutes - raise it
// for job definitions that routinely run longer.
const int maxPollAttempts = 20;
const decimal pollIntervalSeconds = 15;

// Terminal ESS request states - polling stops when one of these is reached. `ERROR_AUTO_RETRY` is
// deliberately absent: it means the request failed and the scheduler will retry it, so a further
// attempt is still to come. Polling continues until that attempt settles on a state below - or
// `ERROR`, once the `retries` budget is exhausted.
final readonly & string[] terminalStates = [
    "SUCCEEDED",
    "ERROR",
    "WARNING",
    "CANCELLED",
    "EXPIRED",
    "VALIDATION_FAILED",
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

    scheduler:SubmitRequestResponse submission = check schedulerClient->submitJobRequest(payload);
    int? submittedId = submission.id;
    if submittedId is () {
        return error("The scheduler did not return a request ID for the submitted job.");
    }
    io:println("Submitted job request. Request ID: ", submittedId);

    // Step 2: Poll the request until it reaches a terminal state.
    string state = "";
    scheduler:RequestDetails details = {};
    boolean reachedTerminalState = false;
    foreach int attempt in 1 ... maxPollAttempts {
        details = check schedulerClient->getJobRequest(submittedId);
        state = details.state ?: "UNKNOWN";
        io:println(string `Attempt ${attempt}: state = ${state}`);

        if terminalStates.indexOf(state) !is () {
            reachedTerminalState = true;
            break;
        }
        if attempt < maxPollAttempts {
            // Wait before the next poll - ESS requests are rarely instantaneous. Skipped after the
            // last attempt, which would otherwise wait only to give up.
            runtime:sleep(pollIntervalSeconds);
        }
    }

    if !reachedTerminalState {
        // Polling gave up - the request is still queued or running in Fusion. It was NOT
        // cancelled, so either keep polling it by ID or cancel it through its `cancel` link.
        return error(string `Job request ${submittedId} did not reach a terminal state within ` +
                string `${maxPollAttempts} polls. Last observed state: ${state}.`);
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
