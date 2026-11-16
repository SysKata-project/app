# Development and validation

## Pinned baseline

- Flutter 3.47.9, revision `c197ca5199e9ee5661e865596c9c07294dfab51c`;
  bundled Dart 3.13.7. `.flutter-version` and `.fvmrc` record the same SDK.
- iOS bundle identifier and Android application ID: `org.syskata.app`.
- Minimum iOS 17; minimum Android 12 (API 31). Android compile/target API 36
  and NDK 28.2.13676358 come from the pinned Flutter SDK.
- Android Gradle Plugin 9.1.0, Gradle wrapper 9.3.1, Kotlin 2.4.0;
  Java source/target 17. Use a JDK 17 or compatible newer Gradle runtime.
- Direct Dart dependency versions are exact in `pubspec.yaml`; commit
  `pubspec.lock` and use `--enforce-lockfile` in CI.
- Xcode is supplied by the macOS host/runner. Record its actual version in
  validation evidence; OS minimums are configuration, not a tested-device claim.

## Setup

Install the exact SDK through FVM or an isolated checkout (no global upgrade
required):

```sh
git clone --depth 1 --branch 3.47.9 https://github.com/flutter/flutter.git /tmp/syskata-flutter-3.47.9
export PATH="/tmp/syskata-flutter-3.47.9/bin:$PATH"
flutter --version
flutter doctor -v
flutter pub get --enforce-lockfile
sh scripts/install-hooks.sh
```

Also install the pinned Gitleaks version described in
[secret protection](../SECRET-PROTECTION.md). Android requires Android Studio,
SDK API 36, its build tools/NDK, accepted SDK licenses and an emulator. iOS
requires macOS, Xcode and an installed simulator runtime. The generated iOS
project uses Swift Package Manager. No signing team or credentials are committed.

```sh
flutter devices
flutter run -d DEVICE_ID --dart-define-from-file=config/development.json
```

Development uses bundled, original API fixtures and prominently labels preview
mode. It does not grade answers, award progress or connect to a backend. The four
primary tabs are usable without an account. UI features beyond the shell remain
in their linked implementation issues.

## Environments and secrets

`config/development.json`, `config/staging.json` and `config/production.json`
use the same application identity. Installing one replaces the other. Endpoint
examples deliberately use the reserved `example.invalid` domain. Replace an
endpoint in a local copy to use a real HTTPS service; `API_BASE_URL` is an origin
without a path, query or credentials. Staging/production reject fake services.
Dart defines are compiled into the app: never put tokens or secrets in them.

The real HTTP adapter obtains an access token through `CredentialStore` and
refuses unauthenticated requests. Sign-in/refresh/account switching are app #3,
so live environments currently show that sign-in is required. Do not inject a
real token through build flags or source code to bypass that milestone.

SQLite stores account/session/version/instance-bound recovery payloads with the
idempotency key in one transaction. It is an adapter foundation, not a completed
replay queue. Credentials use platform secure storage separately. Android
backups are disabled; iOS keychain values are device-bound. Complete recovery,
logout cleanup, retention and backup exclusion validation in app #3 before
storing real learner data. No learner data belongs in Git.

## Checks

```sh
sh scripts/verify.sh
flutter build apk --debug --dart-define-from-file=config/development.json
flutter build ios --simulator --debug --no-codesign --dart-define-from-file=config/development.json
flutter test integration_test/app_test.dart -d DEVICE_ID --dart-define-from-file=config/development.json
sh scripts/scan-secrets.sh history
```

`verify.sh` checks SDK pins, locked dependencies, Dart formatting, static
analysis, unit/widget tests with coverage, fixture provenance and whitespace.
To apply formatting, run `dart format lib test integration_test`. Coverage is
reported in `coverage/lcov.info`; this issue sets no coverage percentage gate.
Native integration tests verify all tabs, reopening SQLite data, account isolation,
cleanup and secure-storage write/read/delete on the selected device. They use
synthetic local values only. Run them separately on iOS and Android.

CI check names: **Flutter quality**, **Android debug build**, **iOS simulator
build**, plus existing **gitleaks**. CI builds do not require signing secrets or
production credentials. CI build checks are not device launch verification;
record the latter in [validation evidence](validation.md). Distribution signing,
store submission and complete authentication/learning integration are outside
this foundation issue.

Review SDK/dependency updates in a dedicated PR, regenerate the lockfile and run
all checks plus both native launch tests. Never weaken a gate to hide a failure.
See [foundation decisions](foundation-decisions.md) for accepted choices.
