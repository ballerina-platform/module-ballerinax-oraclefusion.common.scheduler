# Submit and track job

This example submits an Oracle Fusion scheduled process (ESS job) and then tracks it to completion.

`submitJobRequest` posts the job definition together with its job-specific request parameters and returns the ID of the newly created request. That ID is passed to `getJobRequest`, which is polled until the request reaches a terminal state (`SUCCEEDED`, `ERROR`, `WARNING`, `CANCELLED`, `EXPIRED`, `VALIDATION_FAILED` or `FINISHED`). `ERROR_AUTO_RETRY` is not treated as terminal — it means the scheduler will retry the request, so polling continues until that retry settles. The final state, state description and elapsed time are then printed, along with the error type when the request failed.

Polling is bounded by `maxPollAttempts` (20 polls, 15 seconds apart — roughly five minutes). If the request has not reached a terminal state by then, the example fails with an error rather than reporting an outcome it never observed. The request itself keeps running in Fusion — it is not cancelled — so raise `maxPollAttempts` for job definitions that routinely run longer.

This is the standard submit-then-poll flow for any scheduled process. Oracle's Scheduler API is asynchronous — the submit call returns as soon as the request is queued, so the request state must be polled to learn the outcome.

## Prerequisites

### 1. Set up the Oracle Fusion Cloud instance

Refer to the [Setup guide](https://central.ballerina.io/ballerinax/oraclefusion.common.scheduler/latest#setup-guide) to obtain the base URL and the credentials of a user with the privileges required to submit and monitor scheduled processes.

### 2. Configuration

Create a `Config.toml` file in the example's root directory and provide your values:

```toml
serviceUrl = "https://<fusionHost>/ess/rest/scheduler/v1"
username = "<your-fusion-username>"
password = "<your-fusion-password>"
# Metadata object ID of the job to submit - must exist in your instance
jobDefinitionId = "oracle/apps/ess/financials/payables/invoices/transactions/ImportPayablesInvoicesJob"
```

The `requestParameters` in `main.bal` (`BusinessUnit`, `ImportSource`) are specific to the Import Payables Invoices job and to your instance's setup. Adjust them to match the job definition you configure above — a job submitted with the wrong parameters is accepted and then fails during execution.

## Run the example

Execute the following command to run the example:

```bash
bal run
```
