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
import ballerina/lang.regexp;

listener http:Listener ep0 = new (9090);

// The job requests the mock serves from `GET /requests`.
final readonly & RequestDetails[] mockJobRequests = [
    {
        requestId: 300000012345678,
        description: "Import Payables Invoices",
        jobDefinitionId: "oracle/apps/ess/financials/payables/invoices/transactions/ImportPayablesInvoicesJob",
        application: "FinancialsEss",
        state: "SUCCEEDED",
        stateDescription: "Request completed successfully",
        priority: 4,
        requestType: "SINGLETON",
        submitter: "INTEGRATION_USER",
        submissionTime: "2026-08-13T09:15:22.000Z",
        processStartTime: "2026-08-13T09:15:30.000Z",
        processEndTime: "2026-08-13T09:17:48.000Z",
        completedTime: "2026-08-13T09:17:48.000Z",
        elapsedTime: 138000,
        isCancellable: false,
        isHoldable: false,
        isForceCancelAllowed: false,
        requestParameters: [
            {name: "BusinessUnit", paramType: "STRING", value: "US1 Business Unit"},
            {name: "ImportSource", paramType: "STRING", value: "Spreadsheet"}
        ],
        links: [
            {
                rel: "self",
                href: "https://your-fusion-instance.fa.us2.oraclecloud.com/ess/rest/scheduler/v1/requests/300000012345678"
            }
        ]
    },
    {
        requestId: 300000012345679,
        description: "Load Interface File for Import",
        jobDefinitionId: "oracle/apps/ess/financials/commonModules/shared/common/interfaceLoader/InterfaceLoaderController",
        application: "FinancialsEss",
        state: "RUNNING",
        stateDescription: "Request is running",
        priority: 4,
        requestType: "SINGLETON",
        submitter: "INTEGRATION_USER",
        submissionTime: "2026-08-13T10:02:11.000Z",
        processStartTime: "2026-08-13T10:02:19.000Z",
        elapsedTime: 42000,
        isCancellable: true,
        isHoldable: true,
        isForceCancelAllowed: true,
        requestParameters: [
            {name: "JobName", paramType: "STRING", value: "InterfaceLoaderController"}
        ],
        links: [
            {
                rel: "self",
                href: "https://your-fusion-instance.fa.us2.oraclecloud.com/ess/rest/scheduler/v1/requests/300000012345679"
            },
            {
                rel: "cancel",
                href: "https://your-fusion-instance.fa.us2.oraclecloud.com/ess/rest/scheduler/v1/requests/300000012345679/cancel"
            }
        ]
    },
    {
        requestId: 300000012345677,
        description: "Create Accounting",
        jobDefinitionId: "oracle/apps/ess/financials/subledgerAccounting/accountingProgram/AccountingProgramJob",
        application: "FinancialsEss",
        state: "SUCCEEDED",
        stateDescription: "Request completed successfully",
        priority: 4,
        requestType: "SINGLETON",
        submitter: "INTEGRATION_USER",
        submissionTime: "2026-08-13T08:04:03.000Z",
        processStartTime: "2026-08-13T08:04:10.000Z",
        processEndTime: "2026-08-13T08:06:55.000Z",
        completedTime: "2026-08-13T08:06:55.000Z",
        elapsedTime: 165000,
        isCancellable: false,
        isHoldable: false,
        isForceCancelAllowed: false,
        links: [
            {
                rel: "self",
                href: "https://your-fusion-instance.fa.us2.oraclecloud.com/ess/rest/scheduler/v1/requests/300000012345677"
            }
        ]
    }
];

// The mock honours only the subset of the ESS query grammar that the test suite exercises:
// a `q` of the form `state eq "VALUE"`, a comma-separated `id` list, `fields`/`excludeFields`
// projection, and an `orderBy` of the form `<stringField>:asc|desc`. It is a stand-in that lets
// the tests prove the connector *transmitted* each parameter - not a reimplementation of the
// Oracle Enterprise Scheduler query engine. Anything outside that subset is ignored.

// Applies a `state eq "VALUE"` filter. Any other `q` expression is ignored.
isolated function filterByState(RequestDetails[] items, string? q) returns RequestDetails[] {
    if q is () {
        return items;
    }
    int? matchIndex = q.indexOf("state eq ");
    if matchIndex is () {
        return items;
    }
    string value = q.substring(matchIndex + "state eq ".length()).trim();
    if value.length() >= 2 && value.startsWith("\"") && value.endsWith("\"") {
        value = value.substring(1, value.length() - 1);
    }
    return from RequestDetails item in items
        where item.state == value
        select item;
}

// Restricts the result to a comma-separated list of request IDs.
isolated function filterById(RequestDetails[] items, string? id) returns RequestDetails[] {
    if id is () {
        return items;
    }
    string[] wanted = splitCsv(id);
    return from RequestDetails item in items
        where wanted.indexOf((item.requestId ?: 0).toString()) !is ()
        select item;
}

// Sorts by a string-valued field, e.g. `submissionTime:desc`.
isolated function applyOrderBy(RequestDetails[] items, string? orderBy) returns RequestDetails[] {
    if orderBy is () {
        return items;
    }
    string sortField = orderBy;
    string direction = "asc";
    int? separator = orderBy.indexOf(":");
    if separator is int {
        sortField = orderBy.substring(0, separator).trim();
        direction = orderBy.substring(separator + 1).trim();
    }
    RequestDetails[] sorted = from RequestDetails item in items
        order by sortKey(item, sortField) ascending
        select item;
    return direction == "desc" ? sorted.reverse() : sorted;
}

// Reads a string-valued sort key off a request. Unknown fields sort equally.
isolated function sortKey(RequestDetails item, string sortField) returns string {
    match sortField {
        "submissionTime" => {
            return item.submissionTime ?: "";
        }
        "completedTime" => {
            return item.completedTime ?: "";
        }
        "processStartTime" => {
            return item.processStartTime ?: "";
        }
        "requestId" => {
            return (item.requestId ?: 0).toString();
        }
    }
    return "";
}

// Applies `fields`/`excludeFields` projection. `fields` wins where the two overlap.
isolated function project(RequestDetails[] items, string? fields, string? excludeFields) returns RequestDetails[] {
    if fields is () && excludeFields is () {
        return items;
    }
    string[] include = fields is string ? splitCsv(fields) : [];
    string[] exclude = excludeFields is string ? splitCsv(excludeFields) : [];

    RequestDetails[] projected = [];
    foreach RequestDetails item in items {
        map<json> attributes = <map<json>>item.toJson();
        map<json> retained = {};
        foreach [string, json] [name, value] in attributes.entries() {
            if include.length() > 0 && include.indexOf(name) is () {
                continue;
            }
            if include.length() == 0 && exclude.indexOf(name) !is () {
                continue;
            }
            retained[name] = value;
        }
        // Every `RequestDetails` field is optional, so dropping fields cannot make this conversion
        // fail. If it ever does, serve the unprojected record - the field-absence assertions in the
        // test suite then fail loudly rather than the mock quietly serving something else.
        RequestDetails|error converted = retained.cloneWithType();
        projected.push(converted is RequestDetails ? converted : item);
    }
    return projected;
}

// Splits a comma-separated parameter value, trimming each entry.
isolated function splitCsv(string value) returns string[] {
    return from string entry in regexp:split(re `,`, value)
        let string trimmed = entry.trim()
        where trimmed.length() > 0
        select trimmed;
}

service /ess/rest/scheduler/v1 on ep0 {
    # Query scheduled process (ESS) job requests
    #
    # + q - SCIM-style filter, e.g. state eq "RUNNING". Queryable fields include requestId, absParentRequestId, description, application, product, requestCategory, runAsUser, executionType, jobDefinitionId, state, priority, processStartTime, processEndTime, requestedStartTime, requestedEndTime, submissionTime, parentRequestId, elapsedTime, submitter, requestType, errorType, completedTime, and more.
    # + fields - Comma-separated list of fields to include in the response.
    # + excludeFields - Comma-separated list of fields to exclude from the response.
    # + id - Comma-separated list of request IDs to return.
    # + orderBy - fieldName[:asc|desc], e.g. name:asc
    # + return - Matching job requests
    resource function get requests(string? q, string? fields, string? excludeFields, string? id, string? orderBy) returns RequestQueryResponse {
        RequestDetails[] matched = filterByState(mockJobRequests, q);
        matched = filterById(matched, id);
        matched = applyOrderBy(matched, orderBy);
        matched = project(matched, fields, excludeFields);
        return {
            count: matched.length(),
            pageIndex: 0,
            items: matched,
            links: [
                {
                    rel: "self",
                    href: "https://your-fusion-instance.fa.us2.oraclecloud.com/ess/rest/scheduler/v1/requests"
                }
            ]
        };
    }

    # Get a specific job request by ID
    #
    # + return - Job request detail
    resource function get requests/[int requestId]() returns RequestDetails {
        return {
            requestId: requestId,
            description: "Import Payables Invoices",
            jobDefinitionId: "oracle/apps/ess/financials/payables/invoices/transactions/ImportPayablesInvoicesJob",
            application: "FinancialsEss",
            state: "SUCCEEDED",
            stateDescription: "Request completed successfully",
            priority: 4,
            requestType: "SINGLETON",
            submitter: "INTEGRATION_USER",
            submissionTime: "2026-08-13T09:15:22.000Z",
            requestedStartTime: "2026-08-13T09:15:25.000Z",
            processStartTime: "2026-08-13T09:15:30.000Z",
            processEndTime: "2026-08-13T09:17:48.000Z",
            completedTime: "2026-08-13T09:17:48.000Z",
            elapsedTime: 138000,
            isCancellable: false,
            isHoldable: false,
            isForceCancelAllowed: false,
            requestParameters: [
                {name: "BusinessUnit", paramType: "STRING", value: "US1 Business Unit"},
                {name: "ImportSource", paramType: "STRING", value: "Spreadsheet"},
                {name: "AccountingDate", paramType: "DATETIME", value: "2026-08-13T00:00:00.000Z"}
            ],
            links: [
                {
                    rel: "self",
                    href: string `https://your-fusion-instance.fa.us2.oraclecloud.com/ess/rest/scheduler/v1/requests/${requestId}`
                },
                {
                    rel: "executionStatus",
                    href: string `https://your-fusion-instance.fa.us2.oraclecloud.com/ess/rest/scheduler/v1/requests/${requestId}/executionStatus`
                }
            ]
        };
    }

    # Submit a new scheduled process (ESS) job request
    #
    # + return - returns can be any of following types
    # http:Created (Job request created)
    # http:BadRequest (Invalid input)
    # http:Forbidden (Not allowed for this operation)
    # http:NotFound (Not found)
    # http:Conflict (Conflict)
    # http:InternalServerError (Scheduling sub-system error)
    resource function post requests(@http:Payload SubmitRequestBody payload) returns SubmitRequestResponse|http:BadRequest|http:Forbidden|http:NotFound|http:Conflict|http:InternalServerError {
        if payload.jobDefinitionId.trim().length() == 0 {
            return <http:BadRequest>{
                body: {
                    'type: "https://docs.oracle.com/error/invalid-request",
                    title: "Invalid input",
                    status: 400,
                    detail: "jobDefinitionId must be a non-empty metadata object ID.",
                    errorCode: "ESS-10001"
                }
            };
        }
        return {
            id: 300000012345680,
            links: [
                {
                    rel: "self",
                    href: "https://your-fusion-instance.fa.us2.oraclecloud.com/ess/rest/scheduler/v1/requests/300000012345680"
                },
                {
                    rel: "cancel",
                    href: "https://your-fusion-instance.fa.us2.oraclecloud.com/ess/rest/scheduler/v1/requests/300000012345680/cancel"
                }
            ]
        };
    }
}
