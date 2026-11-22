# Sign-in and durable recovery

Tracking: [app #3](https://github.com/SysKata-project/app/issues/3).

## Configure an installation

Live builds (`USE_FAKE_SERVICES=false`) open a setup screen before sign-in.
Enter the HTTPS API origin and full Keycloak realm URL supplied by the operator,
for example `https://identity.cluster.example/realms/syskata`. Public server
addresses are stored on the device; secrets are never Dart defines. Sign out to
change servers. Development preview remains explicitly fixture-backed and does
not open authentication or persistent learner storage.

The owner approved this runtime configuration and the exact native return
`org.syskata.app:/oauth2redirect` on 2026-11-22. Register it in each environment's
public `syskata-mobile` Keycloak client. This is an OS handoff, separate from the
HTTPS identity endpoint. See the [API's reusable Keycloak HTTPS setup](https://github.com/SysKata-project/api/blob/codex/mobile-identity-https/docs/mobile-identity.md).

## Authentication

Pinned `flutter_appauth` 13.0.0 delegates browser-based Code/PKCE S256, state and
OIDC nonce processing to native AppAuth. No embedded password form or client
secret is used. The app fetches the authenticated subject from Keycloak userinfo
with the access token over HTTPS; it does not trust a locally decoded JWT as an
identity assertion. Userinfo and revocation requests do not follow redirects.

Access/refresh tokens and expiration are written together to platform secure
storage. Refresh is single-flight, occurs before token expiry, and persists the
rotated refresh token before exposing it. Refresh failure returns to sign-in,
retaining pending work for the same account. HTTP 401 also returns to sign-in;
mutations are never automatically recreated with a fresh idempotency key.

Accounts are scoped by API origin, exact issuer and subject. A different account
clears previous account recovery data. Explicit sign-out removes credentials and
account data, then attempts refresh-token revocation by HTTPS POST. A failure is
reported; sign-out does not claim to remove browser-wide SSO cookies. Subsequent
sign-in requests a fresh login. Disabled/deleted accounts clear local recovery
state when the API rejects access. API enforcement remains authoritative.

## Request journal

SQLite schema version 2 adds an account-bound journal. Before any enrollment,
session creation, hint or answer request, it atomically writes the operation,
exact request keys and payload, session/content snapshot and current instance.
An answer intent is saved before starting its attempt. The attempt-creation key
survives a lost response; returned attempt ID and revision are saved before
submission. No mutation is sent if the initial write fails.

On reopen, replay the saved operation with its original keys and payload, then
read server state before advancing. Background-to-foreground transitions also
reconcile. Stale state requires an explicit server refresh; definitive expired,
missing or unsupported sessions offer a return to the lesson start. A new device
uses the API's start/resume contract to discover the existing active session.
There is no offline grading or local reward calculation.

Pending confirmation is visible separately from confirmed feedback and progress.
Late controllers from a closed screen or signed-out authentication generation
cannot repopulate cleared local state. Android backups remain disabled. iOS
stores the journal in an Application Support directory explicitly excluded from
backup; credentials use device-bound keychain accessibility. The original
foundation table remains for schema compatibility and synthetic storage checks.

## Validation

`sh scripts/verify.sh` runs unit/widget checks. `integration_test/app_test.dart`
adds real SQLite close/reopen with a lost response and exact-key replay; it must
be executed on both platforms. Native browser login and TLS checks additionally
need an operator-supplied reachable HTTPS environment and trusted certificate.
Do not infer those results from fixture-backed tests or successful native builds.
