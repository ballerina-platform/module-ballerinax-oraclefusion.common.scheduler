# Examples

The `ballerinax/oraclefusion.common.scheduler` connector provides practical examples illustrating usage in various scenarios.

| Example | Description |
|---------|-------------|
| [`submit-and-track-job`](./submit-and-track-job) | Submit a scheduled process (ESS job) and poll the resulting request until it reaches a terminal state, then report the final execution outcome. |
| [`monitor-scheduled-processes`](./monitor-scheduled-processes) | Build an operational view over scheduled processes — list running requests, find the ones in the `ERROR` state, and drill into the most recent of those for its parameters and error detail. |

## Prerequisites

1. An Oracle Fusion Cloud instance (release 23B or later, which is when the generic Scheduler
   REST API was introduced) and a user with the privileges required to submit and monitor
   scheduled processes. The base URL is instance-specific and has the form
   `https://{fusionHost}/ess/rest/scheduler/v1`, for example
   `https://acme.fa.us2.oraclecloud.com/ess/rest/scheduler/v1`.

2. For each example, create a `Config.toml` in the example directory:

   ```toml
   serviceUrl = "https://<fusionHost>/ess/rest/scheduler/v1"
   username = "<your-fusion-username>"
   password = "<your-fusion-password>"
   # Only required by submit-and-track-job — the metadata object ID of the job to run
   jobDefinitionId = "oracle/apps/ess/financials/payables/invoices/transactions/ImportPayablesInvoicesJob"
   ```

   `Config.toml` is git-ignored — never commit real credentials.

   The connector also accepts OAuth2 client credentials instead of Basic authentication. To use
   OAuth2, replace the `auth` value in the example's `main.bal` with your IDCS token endpoint and
   client credentials:

   ```ballerina
   scheduler:Client schedulerClient = check new ({
       auth: {
           tokenUrl: "https://<your-idcs-instance>.identity.oraclecloud.com/oauth2/v1/token",
           clientId,
           clientSecret
       }
   }, serviceUrl);
   ```

## Running an example

Execute the following commands to build an example from the source:

* To build an example:

    ```bash
    bal build
    ```

* To run an example:

    ```bash
    bal run
    ```

## Building the examples with the local module

**Warning**: Due to the absence of support for reading local repositories for single Ballerina files, the Bala of the module is manually written to the central repository as a workaround. Consequently, the bash script may modify your local Ballerina repositories.

Execute the following commands to build all the examples against the changes you have made to the module locally:

* To build all the examples:

    ```bash
    ./build.sh build
    ```

* To run all the examples:

    ```bash
    ./build.sh run
    ```
