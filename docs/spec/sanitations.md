_Author_:  DimuthuMadushan \
_Created_: 2026-08-13 \
_Updated_: 2026-08-13 \
_Edition_: Swan Lake

# Sanitation for OpenAPI specification

This document records the sanitation done on top of the official OpenAPI specification from Oracle Fusion Cloud Scheduler.
The OpenAPI specification is hand-authored (Oracle does not publish a machine-readable spec for the Enterprise Scheduler (ESS) resource, introduced in release 23B); it was reconstructed from Oracle's public REST API reference documentation — [Scheduler REST API](https://docs.oracle.com/en/cloud/saas/financials/25c/farca/api-scheduler.html), [Query job requests](https://docs.oracle.com/en/cloud/saas/financials/25c/farca/op-ess-rest-scheduler-v1-requests-get.html) and [Submit a job request](https://docs.oracle.com/en/cloud/saas/financials/25c/farca/op-ess-rest-scheduler-v1-requests-post.html).
These changes are done in order to improve the overall usability, and as workarounds for some known language limitations.

<!-- auto-generated -->
1. **Add the `oauth2` security scheme**: The specification originally declared only `basicAuth`.
    - Original: `securitySchemes: { basicAuth }`, `security: [{ basicAuth: [] }]`
    - Updated: added an `oauth2` scheme with a `clientCredentials` flow, and added `- oauth2: []`
      to the root `security` list
    - Reason: Many Oracle Fusion instances are configured to reject Basic authentication in favour
      of OAuth2 client credentials against the instance's Oracle Identity Cloud Service (IDCS)
      token endpoint. Declaring both schemes makes the generated `ConnectionConfig` accept either
      credential type, matching the `oraclefusion.erp.integrations` connector.

<!-- auto-generated -->
2. **Use a placeholder `tokenUrl` for the client credentials flow**: OpenAPI requires `tokenUrl`
   to be present on a `clientCredentials` flow, but the real value is instance-specific.
    - Original: n/a (scheme did not exist)
    - Updated: `tokenUrl: https://your-idcs-instance.identity.oraclecloud.com/oauth2/v1/token`
    - Reason: The IDCS token endpoint differs per Fusion instance, so no correct default exists.
      A named placeholder documents the expected shape of the value; callers must override it with
      their own instance's token endpoint.

<!-- auto-generated -->
3. **Add a description to the `basicAuth` scheme**: The scheme carried no description.
    - Original: `basicAuth: { type: http, scheme: basic }`
    - Updated: same, with a description noting it is Basic authentication over HTTPS using a
      Fusion integration user's credentials, and that some instances reject it in favour of OAuth2
    - Reason: Surfaces the instance-dependent availability of Basic auth in the generated API
      documentation, so users know to fall back to OAuth2.

<!-- auto-generated -->
4. **Add query parameter serialization defaults** (applied by `bal openapi flatten`): The `q`,
   `fields`, `excludeFields`, `id` and `orderBy` query parameters had no serialization metadata.
    - Original: parameters with `name`, `in`, `schema` only
    - Updated: `style: form`, `explode: true` and an explicit `required: false` added to each
    - Reason: Makes the OpenAPI-default serialization behaviour explicit so the generated client's
      query encoding is unambiguous rather than implied.

<!-- auto-generated -->
5. **Inline the shared `BadRequest` response component** (applied by `bal openapi align`): The
   `400` response on `POST /requests` referenced a reusable response component.
    - Original: `400: { $ref: '#/components/responses/BadRequest' }`
    - Updated: the error schema (`type`, `title`, `status`, `detail`, `errorCode`) inlined into the
      operation's `400` response
    - Reason: Applied automatically by `bal openapi align`. Harmless here — the Ballerina client
      surfaces non-2xx responses as `error`, so no record type is generated from this schema.

<!-- auto-generated -->
6. **Add descriptions to all three operations**: `queryJobRequests`, `submitJobRequest` and
   `getJobRequest` each had a `summary` but an empty `description`.
    - Original: no `description` field
    - Updated: a two-to-three sentence description on each, covering the filter/shaping query
      parameters, the submit payload contents, and polling a submitted request respectively
    - Reason: `bal openapi` maps the operation `description` to the doc comment of the generated
      resource method. Without it the generated client methods carry only a one-line summary.

Note: `bal openapi align` added no `x-ballerina-name` extensions to this specification — unlike
the ERP Integrations spec, the Scheduler payload fields are already camelCase on the wire
(`jobDefinitionId`, `requestParameters`, `requestId`, ...), so the default lowering produces
idiomatic Ballerina record fields with no overrides needed.

## OpenAPI cli command

The following commands were used to produce the aligned specification and generate the Ballerina client from it. They should be executed from the repository root directory. Sanitations 1, 2, 3 and 6 above are applied by hand — 1, 2 and 3 to `openapi.yaml` before the `flatten` step, and 6 to `aligned_ballerina_openapi.yaml` after the `align` step and before the `client` step.

```bash
# 1. Flatten and align (intermediate flattened_openapi.yaml is not committed)
cd ballerina
bal openapi flatten -i ../docs/spec/openapi.yaml -o ../docs/spec
bal openapi align -i ../docs/spec/flattened_openapi.yaml -o ../docs/spec

# 2. Generate the client from the sanitized, aligned specification
bal openapi -i ../docs/spec/aligned_ballerina_openapi.yaml --mode client \
    --license ../docs/license.txt -o .
```

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
bodies are filled in with mock data by hand.

Note: The license year is hardcoded to 2026 in `docs/license.txt`, change if necessary.
