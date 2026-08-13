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

listener http:Listener ep0 = new (9090);

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
        return {
            count: 2,
            pageIndex: 0,
            items: [
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
                }
            ],
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
