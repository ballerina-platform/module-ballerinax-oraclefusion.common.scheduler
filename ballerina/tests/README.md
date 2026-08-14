# Running Tests

## Prerequisites

You need a user with the required privileges on an Oracle Fusion Cloud instance (release 23B or later), and that instance's base URL, to run the live tests.

To run the tests against the mock server, no credentials are required.

## Test environments

There are two test environments for running the connector tests. The default environment is the mock server for the Oracle Fusion Cloud Scheduler REST API. The other environment is a live Fusion instance.

You can run the tests in either of these environments, and each has its own compile-time configuration.

| Test Group   | Environment                                              |
|--------------|----------------------------------------------------------|
| `mock_tests` | Mock server for the Scheduler REST API (default)         |
| `live_tests` | Oracle Fusion Cloud instance                              |

## Test coverage

The suite covers every operation exposed by the connector:

- `queryJobRequests` — lists job requests and asserts the returned collection carries request IDs.
- `queryJobRequests` with a filter — exercises the `q`, `orderBy`, and `fields` query parameters.
- `submitJobRequest` — submits a job request and asserts a request ID is returned.
- `getJobRequest` — fetches a request resolved from the query response and asserts its ID and execution state.
- `submitJobRequest` with a `requestExecutionContext` — asserts the sub-request execution context is transmitted, by checking the mock echoes the supplied parent through a `parentRequest` link. `mock_tests`-only: a valid `requestHandle` can only come from inside a running ESS job, so it cannot be fabricated against a live instance.
- `submitJobRequest` with an empty `jobDefinitionId` — asserts the connector surfaces the service's `400` as an error. This is a `mock_tests`-only case, since a live instance would reject it with an instance-specific message.

The mock server implements the three endpoints on `http://localhost:9090/ess/rest/scheduler/v1` and starts automatically with `bal test`.

## Running tests in the mock server

To execute the tests on the mock server, ensure that the `IS_LIVE_SERVER` environment variable is either set to `false` or unset before running the tests.

This is the default behavior:

```bash
bal test
```

## Running tests against a live Fusion instance

Set the following environment variables:

```bash
export IS_LIVE_SERVER=true
export ORACLE_FUSION_SERVICE_URL="https://<fusionHost>/ess/rest/scheduler/v1"
export ORACLE_FUSION_USERNAME="<your-fusion-username>"
export ORACLE_FUSION_PASSWORD="<your-fusion-password>"
export ORACLE_FUSION_JOB_DEFINITION_ID="oracle/apps/ess/.../YourJob"
```

Then, run the following command to run the tests:

```bash
bal test --groups live_tests
```

> **Note:** The live tests submit a real scheduled process on the target instance. Run them only against a development or test instance, and set `ORACLE_FUSION_JOB_DEFINITION_ID` to a job that is safe to execute repeatedly.
