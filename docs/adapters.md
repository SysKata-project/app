# Typed service adapters

`LearningService` is injected through Riverpod. `HttpLearningService` implements
catalog, journey detail, progress, session reads, answer submission, lab status
and assessment polling against API contract v1. `FixtureLearningService`
implements the same interface from fixed upstream public examples. It is a
preview service, not a simulated backend or evaluator. Its ID parameters do not
select different fixture records; submissions always return a fixed example.

Typed projections cover schema/bundle/policy versions, journey and lesson nodes,
progress, all four question variants, submission answers, criterion feedback,
lab state, assessment state and structured service errors. These are deliberately
small client projections, not a replacement OpenAPI schema validator. Additional
payload fields remain owned by the upstream contract and are added as UI work
needs them. Enrollment, session/attempt creation, assistance, lab mutations,
terminal credentials, account deletion and timezone changes remain adapter
extensions for app #2–#5; no internal worker result endpoint is exposed.

The HTTP adapter uses HTTPS, bearer authentication, timeouts and no redirects.
Mutations require a caller-supplied persisted idempotency key; no automatic retry
can create a new key or claim new progress. Structured API errors preserve code,
retryability, recovery action, revision and correlation ID. Diagnostics exclude
raw bodies and tokens. Unknown schema versions and exercise types fail closed.

The bundled JSON fixtures are byte-for-byte copies from the API revision recorded
in [the provenance manifest](../contracts/fixture-provenance.json). They cover
success, mistake, duplicate submission, stale state, expiry and infrastructure
failure. `scripts/check-fixtures.py` verifies hashes and rejects internal worker
fixtures and answer keys in question payloads. For updates, select a reviewed
API commit, copy the public examples, update hashes and rerun adapter tests.
Never change a fixture merely to make an incorrect parser pass.
