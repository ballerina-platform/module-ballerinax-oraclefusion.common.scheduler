_Author_:  DimuthuMadushan \
_Created_: 2026-08-13 \
_Updated_: 2026-08-14 \
_Edition_: Swan Lake

# Sanitation for OpenAPI specification

This document records the sanitation done on top of the official OpenAPI specification from Oracle Fusion Cloud Scheduler.
The OpenAPI specification is hand-authored (Oracle does not publish a machine-readable spec for the Enterprise Scheduler (ESS) resource, introduced in release 23B); it was reconstructed from Oracle's public REST API reference documentation — [Scheduler REST API](https://docs.oracle.com/en/cloud/saas/financials/25c/farca/api-scheduler.html), [Query job requests](https://docs.oracle.com/en/cloud/saas/financials/25c/farca/op-ess-rest-scheduler-v1-requests-get.html) and [Submit a job request](https://docs.oracle.com/en/cloud/saas/financials/25c/farca/op-ess-rest-scheduler-v1-requests-post.html).
These changes are done in order to improve the overall usability, and as workarounds for some known language limitations.

<!-- auto-generated -->
1. **Inject a placeholder `servers` entry** (applied by `bal openapi flatten`): the source
   specification deliberately has no `servers` block, and `flatten` adds one.
    - Original: no `servers` block
    - Updated: `servers: [{ url: "/" }]`
    - Reason: Retained deliberately — do **not** replace it with a real URL. The Oracle Fusion base
      URL is instance-specific (`https://{fusionHost}/ess/rest/scheduler/v1`, e.g.
      `https://acme.fa.us2.oraclecloud.com/ess/rest/scheduler/v1`), so no correct default exists.
      With the `/` placeholder, `bal openapi` generates
      `init(ConnectionConfig config, string serviceUrl)` — `serviceUrl` is a required argument. Give
      the specification a concrete server URL instead and the generator emits it as a default
      (`string serviceUrl = "https://your-fusion-instance..."`), so a caller who omits the argument
      compiles cleanly and then sends every request to a host that does not exist.

<!-- auto-generated -->
2. **Add query parameter serialization defaults** (applied by `bal openapi flatten`): The `q`,
   `fields`, `excludeFields`, `id` and `orderBy` query parameters had no serialization metadata.
    - Original: parameters with `name`, `in`, `schema` only
    - Updated: `style: form`, `explode: true` and an explicit `required: false` added to each
    - Reason: Makes the OpenAPI-default serialization behaviour explicit so the generated client's
      query encoding is unambiguous rather than implied.

<!-- auto-generated -->
3. **Inline the shared `BadRequest` response component** (applied by `bal openapi align`): The
   `400` response on `POST /requests` referenced a reusable response component.
    - Original: `400: { $ref: '#/components/responses/BadRequest' }`
    - Updated: the error schema (`type`, `title`, `status`, `detail`, `errorCode`) inlined into the
      operation's `400` response
    - Reason: Applied automatically by `bal openapi align`. Harmless here — the Ballerina client
      surfaces non-2xx responses as `error`, so no record type is generated from this schema.

## OpenAPI cli command

The following commands were used to produce the aligned specification and generate the Ballerina client from it. They should be executed from the repository root directory.

All three sanitations above are applied by the tooling itself — nothing is hand-edited after `align`. `aligned_ballerina_openapi.yaml` is therefore fully reproducible: re-running the two commands below regenerates it byte-for-byte, and the committed file is exactly what the tooling emits, so any diff against it signals a real change to `openapi.yaml`. The post-generation patches listed at the end of this document are the only hand edits that survive into the repository, and those apply to generated **code**, not to either specification.

```bash
# 1. Flatten and align (intermediate flattened_openapi.yaml is not committed)
cd ballerina
bal openapi flatten -i ../docs/spec/openapi.yaml -o ../docs/spec
bal openapi align -i ../docs/spec/flattened_openapi.yaml -o ../docs/spec

# 2. Generate the client from the sanitized, aligned specification
bal openapi -i ../docs/spec/aligned_ballerina_openapi.yaml --mode client \
    --license ../docs/license.txt -o . --client-methods remote
```

`--client-methods remote` generates remote methods named after each `operationId`
(`queryJobRequests`, `getJobRequest`, `submitJobRequest`) instead of the default resource methods
(`->/requests`, `->/requests/[id]`, `->/requests.post`). Dropping the flag regenerates a
resource-method client and breaks every call site in `tests/`, `examples/` and the READMEs.

The mock service used by the tests is generated from the same aligned specification:

```bash
cd ballerina
bal openapi -i ../docs/spec/aligned_ballerina_openapi.yaml --mode service \
    --license ../docs/license.txt -o ./tests
```

Note: The generated stub is then renamed to `tests/mock_service.bal`, its `tests/types.bal` and
`tests/client.bal` are deleted (the root package types are already in scope), the listener is
changed from the specification's host and port `443` to `9090`, the `400` response type is changed
from the service-mode `InlineResponse400BadRequest` to `http:BadRequest`, and the resource function
bodies are filled in with mock data by hand. `GET /requests` additionally honours the `q`, `id`,
`fields`, `excludeFields` and `orderBy` parameters over its fixture data, so that the test suite can
assert the connector actually transmitted them; it implements only the subset of the query grammar
the tests exercise, which is documented in a comment in the file.

Note: The license year is hardcoded to 2026 in `docs/license.txt`, change if necessary.

## Post-generation patches

Unlike the sanitations above, these are edits to **generated code**. They are not expressed in the
specification and the generator does not produce them, so **they must be re-applied by hand after
every regeneration**.

1. **`client.bal` — propagate `laxDataBinding` into the `http:ClientConfiguration`.**
    - Generated:
      ```ballerina
      http:ClientConfiguration httpClientConfig = {..., retryConfig: config.retryConfig, validation: config.validation};
      ```
    - Patched: appended `laxDataBinding: config.laxDataBinding` to the same record literal.
    - Reason: `init` copied every other `ConnectionConfig` field into the `http:ClientConfiguration`
      but dropped this one, so the setting was inert — `ConnectionConfig.laxDataBinding` defaults to
      `true` and is documented "Enabled by default", while `http:CommonClientConfiguration.laxDataBinding`
      defaults to `false`. Relaxed binding was therefore always **off**, regardless of what the caller
      configured, and setting it to `false` explicitly was equally a no-op.
    - Impact: Oracle Fusion returns explicit `null` for absent attributes on the Scheduler resource.
      With relaxed binding off, such a payload fails data binding instead of treating the field as
      absent, so a `getJobRequest` on a request that omits (for example) `processEndTime` can error
      rather than returning a `RequestDetails` with that field unset.
    - Note: `validation` sits immediately beside `laxDataBinding` in `http:CommonClientConfiguration`
      and *is* copied by the generator, which is what makes the omission identifiable as a generator
      bug rather than an intentional choice.

2. **`types.bal` — drop the generated `OAuth2ClientCredentialsGrantConfig` and use
   `http:OAuth2ClientCredentialsGrantConfig` in its place.**
    - Generated:
      ```ballerina
      # OAuth2 Client Credentials Grant Configs
      public type OAuth2ClientCredentialsGrantConfig record {|
          *http:OAuth2ClientCredentialsGrantConfig;
          # Token URL
          string tokenUrl = "";
      |};
      ```
    - Patched: the record is removed entirely, and any reference to it — in practice only
      `ConnectionConfig.auth` — is replaced with `http:OAuth2ClientCredentialsGrantConfig`:
      ```ballerina
      http:OAuth2ClientCredentialsGrantConfig|http:CredentialsConfig auth;
      ```
    - Reason: the generated record adds nothing. It includes
      `*http:OAuth2ClientCredentialsGrantConfig`, so the two carry the same field set; the only
      difference is that it re-declares `tokenUrl` with a default, which turns a required field into
      an optional one. That is a downgrade, not a feature — the IDCS token endpoint is
      instance-specific, so a caller who omits it should get a compile error rather than a client
      that silently builds and then fails at runtime. Using the `http` type directly also keeps a
      redundant type out of the module's public API and its generated documentation.
    - Note: the `tokenUrl` in `openapi.yaml` decides which half of this patch is needed. It is empty
      there, because the IDCS token endpoint is instance-specific and any value would be a
      non-working placeholder — and with an empty `tokenUrl` `bal openapi` already generates
      `ConnectionConfig.auth` in terms of the `http` type, so only the dead record needs deleting.
      Give it a non-empty value and the generator wires the local record into `ConnectionConfig`
      instead, and the reference must be repointed as well. Verify which case you
      are in with `grep -rn OAuth2ClientCredentialsGrantConfig ballerina --include=*.bal` — after the
      patch, every match should be `http:`-qualified.
