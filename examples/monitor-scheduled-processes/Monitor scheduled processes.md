# Monitor scheduled processes

This example builds an operational view over the scheduled processes running on an Oracle Fusion instance.

`queryJobRequests` is called twice with different SCIM-style filters — once for `state eq "RUNNING"` ordered by newest submission, and once for `state eq "ERROR"` ordered by most recent completion. Both calls use the `fields` query parameter to return only the attributes the report needs, which keeps the response payload small. The most recent failure is then passed to `getJobRequest` to retrieve its full detail, including the request parameters it was submitted with and its error type.

Use this flow to drive a monitoring dashboard or an alerting job. The `q` filter accepts any queryable request attribute (`requestId`, `jobDefinitionId`, `submitter`, `priority`, `processStartTime`, `elapsedTime`, and more), so the same shape extends to reports such as long-running requests or requests submitted by a particular integration user.

## Prerequisites

### 1. Set up the Oracle Fusion Cloud instance

Refer to the [Setup guide](https://central.ballerina.io/ballerinax/oraclefusion.common.scheduler/latest#setup-guide) to obtain the base URL and the credentials of a user with the privileges required to monitor scheduled processes.

### 2. Configuration

Create a `Config.toml` file in the example's root directory and provide your values:

```toml
serviceUrl = "https://<fusionHost>/ess/rest/scheduler/v1"
username = "<your-fusion-username>"
password = "<your-fusion-password>"
```

## Run the example

Execute the following command to run the example:

```bash
bal run
```
