# Ballerina Oracle Fusion Cloud Scheduler connector

[![Build](https://github.com/ballerina-platform/module-ballerinax-oraclefusion.common.scheduler/actions/workflows/ci.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-oraclefusion.common.scheduler/actions/workflows/ci.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerinax-oraclefusion.common.scheduler.svg)](https://github.com/ballerina-platform/module-ballerinax-oraclefusion.common.scheduler/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-library/module/oraclefusion.common.scheduler.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-library/labels/module%2Foraclefusion.common.scheduler)

## Overview

[Oracle Fusion Cloud Applications](https://www.oracle.com/applications/) run their long-running background work — data imports, reports, period-close processes — as *scheduled processes* on the Enterprise Scheduler Service (ESS).

The generic Scheduler REST API (introduced in Oracle Fusion release 23B) is the entry point for that work. It submits job requests against a job definition, queries requests with a SCIM-style filter, and reports the execution state of an individual request.

The `ballerinax/oraclefusion.common.scheduler` package provides APIs to connect and interact with the Scheduler REST API endpoints of Oracle Fusion Cloud (`/ess/rest/scheduler/v1`). It supports the `submitJobRequest`, `queryJobRequests`, and `getJobRequest` operations.

Because the API is asynchronous, the typical flow is submit-then-poll: `submitJobRequest` returns as soon as the request is queued, and `getJobRequest` is polled until the request reaches a terminal state.

## Setup guide

### Step 1: Identify your Fusion instance base URL

The Scheduler base URL is instance-specific and takes the form:

```text
https://{fusionHost}/ess/rest/scheduler/v1
```

For example: `https://acme.fa.us2.oraclecloud.com/ess/rest/scheduler/v1`

> **Note:** The generic Scheduler REST API is available from Oracle Fusion release 23B onwards. On earlier releases, use the product-specific ESS endpoints instead.

### Step 2: Provision a user with the required privileges

1. Sign in to your Oracle Fusion Cloud instance as a user with security administration rights.
2. Create (or identify) the integration user that will submit and monitor the processes.
3. Grant the roles required for the scheduled processes you intend to run. Submitting a process requires the privileges of that specific job definition; monitoring requires the privileges to view scheduled processes. Consult your Fusion security administrator for the exact roles for your module.

### Step 3: Identify the job definition to submit

Submitting a request takes a `jobDefinitionId` — the metadata object ID of the process, not its display name. It has the form:

```text
oracle/apps/ess/financials/payables/invoices/transactions/ImportPayablesInvoicesJob
```

Find it in the Fusion UI under **Tools > Scheduled Processes**, or ask your functional administrator. The job-specific `requestParameters` are defined by the job definition, so confirm their names, order, and types for the process you intend to run.

### Step 4: Choose an authentication scheme

The connector supports both of the schemes the service accepts. `ConnectionConfig.auth` is a union, so the choice is a configuration change rather than a code change.

**HTTP Basic** over HTTPS, using a Fusion integration user's credentials:

```ballerina
final scheduler:Client schedulerClient = check new ({auth: {username, password}}, serviceUrl);
```

**OAuth2 client credentials**, for instances that reject Basic auth. Register a confidential application in Oracle Identity Cloud Service (IDCS), grant it access to the Scheduler resource, and use its client id and secret:

```ballerina
final scheduler:Client schedulerClient = check new ({
    auth: {
        clientId,
        clientSecret,
        tokenUrl: "https://<your-idcs-host>.identity.oraclecloud.com/oauth2/v1/token"
    }
}, serviceUrl);
```

Ask your Fusion administrator which scheme the instance is configured for — some pods disable Basic auth for integration users.

## Quickstart

To use the `oraclefusion.common.scheduler` connector in your Ballerina application, modify the `.bal` file as follows:

### Step 1: Import the module

```ballerina
import ballerina/io;
import ballerinax/oraclefusion.common.scheduler;
```

### Step 2: Instantiate a new connector

1. Create a `Config.toml` file and configure the obtained credentials in the above steps as follows:

    ```toml
    serviceUrl = "https://<fusionHost>/ess/rest/scheduler/v1"
    username = "<your-fusion-username>"
    password = "<your-fusion-password>"
    ```

2. Create a `scheduler:Client` with the configuration.

    ```ballerina
    configurable string serviceUrl = ?;
    configurable string username = ?;
    configurable string password = ?;

    final scheduler:Client schedulerClient = check new ({auth: {username, password}}, serviceUrl);
    ```

### Step 3: Invoke the connector operation

Now, utilize the available connector operations. The following snippet lists the scheduled processes that are currently running:

```ballerina
public function main() returns error? {
    scheduler:RequestQueryResponse response = check schedulerClient->/requests(
        queries = {q: "state eq \"RUNNING\"", orderBy: "submissionTime:desc"}
    );
    io:println(response);
}
```

### Step 4: Run the Ballerina application

```bash
bal run
```

## Examples

The `Oraclefusion.common.scheduler` connector provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerinax-oraclefusion.common.scheduler/tree/main/examples/), covering the following use cases:

1. [Submit and track job](https://github.com/ballerina-platform/module-ballerinax-oraclefusion.common.scheduler/tree/main/examples/submit-and-track-job) - Submit a scheduled process and poll the resulting request until it reaches a terminal state, then report the final execution outcome.
2. [Monitor scheduled processes](https://github.com/ballerina-platform/module-ballerinax-oraclefusion.common.scheduler/tree/main/examples/monitor-scheduled-processes) - Build an operational view over scheduled processes: list running requests, find the ones in the `ERROR` state, and drill into the most recent of those for its parameters and error detail.

## Build from the source

### Setting up the prerequisites

1. Download and install Java SE Development Kit (JDK) version 21. You can download it from either of the following sources:

    * [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
    * [OpenJDK](https://adoptium.net/)

   > **Note:** After installation, remember to set the `JAVA_HOME` environment variable to the directory where JDK was installed.

2. Download and install [Ballerina Swan Lake](https://ballerina.io/).

3. Download and install [Docker](https://www.docker.com/get-started).

   > **Note**: Ensure that the Docker daemon is running before executing any tests.

4. Export Github Personal access token with read package permissions as follows,

    ```bash
    export packageUser=<Username>
    export packagePAT=<Personal access token>
    ```

### Build options

Execute the commands below to build from the source.

1. To build the package:

   ```bash
   ./gradlew clean build
   ```

2. To run the tests:

   ```bash
   ./gradlew clean test
   ```

3. To build the without the tests:

   ```bash
   ./gradlew clean build -x test
   ```

4. To run tests against different environments:

   ```bash
   ./gradlew clean test -Pgroups=<Comma separated groups/test cases>
   ```

5. To debug the package with a remote debugger:

   ```bash
   ./gradlew clean build -Pdebug=<port>
   ```

6. To debug with the Ballerina language:

   ```bash
   ./gradlew clean build -PbalJavaDebug=<port>
   ```

7. Publish the generated artifacts to the local Ballerina Central repository:

    ```bash
    ./gradlew clean build -PpublishToLocalCentral=true
    ```

8. Publish the generated artifacts to the Ballerina Central repository:

   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For more information go to the [`oraclefusion.common.scheduler` package](https://central.ballerina.io/ballerinax/oraclefusion.common.scheduler/latest).
* For example demonstrations of the usage, go to [Ballerina By Examples](https://ballerina.io/learn/by-example/).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
