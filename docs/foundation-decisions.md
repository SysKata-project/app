# Mobile foundation decisions

Tracking issue: https://github.com/SysKata-project/app/issues/1

## Accepted

- On 2026-11-09, the project owner selected `org.syskata.app` as the permanent
  iOS bundle identifier and Android application ID.
- Flutter/Dart and iOS/Android remain the existing platform baseline.
- On 2026-11-09, the project owner selected minimum targets of iOS 17 and
  Android 12 (API 31).
- On 2026-11-09, the project owner selected Riverpod for state management
  and service dependency injection.
- On 2026-11-09, the project owner selected `go_router` for navigation.
- On 2026-11-09, the project owner selected Dart's `http` package for
  networking, behind typed service adapters.
- On 2026-11-09, the project owner selected SQLite (`sqflite`) for durable
  recovery data and `flutter_secure_storage` for credentials. Pending attempts
  and their idempotency keys must be persisted atomically. Full authenticated
  recovery behavior remains in app #3.
- On 2026-11-09, the project owner selected the Flutter 3.47 stable series.
  Implementation pins Flutter 3.47.9 with bundled Dart 3.13.7.
- On 2026-11-09, the project owner selected one application identity with
  explicit development/staging/production configuration files. Development
  defaults to fake services; separate installable flavors are not required.

## Validated implementation pins

Flutter 3.47.9 and bundled Dart 3.13.7; exact packages are recorded in
`pubspec.yaml` and `pubspec.lock`. See [development](development.md) for platform
toolchain pins and [validation](validation.md) for actual check results.

Accepted identifiers do not imply store registration or signing setup.
Device compatibility claims are limited to the recorded validation evidence.

## Installation configuration — app #3

Accepted by the project owner on 2026-11-22:

- Clusters and their endpoints may change; no stable hosted cluster or public
  release is assumed. The installed application must offer initial endpoint
  configuration instead of requiring a rebuild for each cluster.
- Reuse the existing Keycloak service and `syskata` realm from the API
  repository (`dev/compose.yaml` and `dev/syskata-realm.json`). Configure an
  HTTPS identity endpoint for the selected environment.

Implementation must distinguish the configurable Keycloak issuer from the
mobile callback that returns the browser to the application. The existing
Keycloak Compose service exposes loopback HTTP for development only; it is
not evidence of a configured or validated HTTPS endpoint.

Accepted by the project owner on 2026-11-22: use the fixed native callback
`org.syskata.app:/oauth2redirect`. Keycloak and API traffic remain HTTPS.
Register this exact callback in each cluster's `syskata-mobile` client, with
Code/PKCE S256, state and nonce validation. This supersedes the API contract's
blanket callback TLS requirement for this native app return only.

The owner confirmed **local only** validation on 2026-11-22. Deployment to a
temporary or stable cluster remains deferred; first-install endpoint settings
are retained for future environments. This does not waive native/runtime checks.
