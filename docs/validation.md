# Foundation validation

Issue: https://github.com/SysKata-project/app/issues/1

Validation date: 2026-11-09 (America/Denver).

## Evidence

- Flutter 3.47.9 / Dart 3.13.7, exact SDK revision recorded in development docs.
- 15 unit/widget tests passed: API fixtures, four question variants, mutation
  payload/key preservation, server-directed errors, timeouts, no automatic
  mutation retry, four-tab navigation, 250% text, narrow/landscape/tablet layouts,
  dark theme, labeled tap targets, contrast and redacted failure UI.
- 16 upstream public fixtures passed byte-for-byte SHA-256 provenance checks.
- iOS simulator debug build and native integration test passed on iPhone 17 Pro,
  iOS 26.5, with Xcode 27.2 (27B52). Normal app launch and visual layout inspected.
- Android debug APK build and native integration test passed on a disposable
  Pixel 7 emulator, Android API 36.1 (arm64). The existing emulator was preserved;
  its insufficient free space prevented installation, so a separate AVD was used.
- `sh scripts/verify.sh` passed, including formatting and clean static analysis.
- Secret history scan passed before publication; staged changes are also scanned
  by the required commit hook.
- Remote CI evidence is attached to [PR #9](https://github.com/SysKata-project/app/pull/9).
  Its initial quality run exposed fresh-SDK initialization text before version
  JSON; verification now initializes the SDK before parsing its exact version.
- [iOS Today screen](screenshots/ios-today.png) records the inspected preview.
- GitHub reports `main` has no branch protection (HTTP 404 on the protection
  endpoint). Required-check enforcement is not configured by this PR.

## Limits

This is the mobile foundation. No production sign-in, lesson submission flow,
real terminal, store signing or release is claimed. Fixture responses are
examples, not validated learner progress. Supported minimums are iOS 17 and
Android 12; minimum-version device validation is not implied by tests on newer
simulators. VoiceOver/TalkBack user testing, real-device checks and complete
pilot flows remain release-gate work.

## Learning loop — app #2

Validation date: 2026-11-22 (America/Denver).

- Isolated Flutter 3.47.9 / Dart 3.13.7 SDK at the exact repository revision;
  global Flutter was not upgraded.
- `scripts/verify.sh` passed: locked dependencies, formatting, static analysis,
  28 unit/widget tests with coverage, public fixture provenance and whitespace.
- Full widget flow covers journey entry, hints, incorrect feedback, remediation
  and completion; separate checks cover choice IDs, ordering controls, constrained
  commands, historical partial progress and exact request replay after a timeout.
- Widget accessibility checks cover labeled controls and a 320×568 layout at
  250% text with keyboard insets and reduced motion enabled. Existing navigation
  tests retain contrast, tap-target, landscape and dark-theme coverage.
- 20 unchanged public API response fixtures and the seven-lesson public draft
  projection passed SHA-256 checks. No assessment keys are bundled.
- Secret history scan passed. Native integration tests were extended with a
  fixture-backed incorrect → remediation → completed learning flow.
- Local native validation was blocked by host disk exhaustion: iOS artifact
  extraction failed with a disk-full error; Android `compressDebugAssets` failed
  with `No space left on device`; the Android emulator refused to start for
  insufficient disk space. The iOS simulator started and was shut down afterward.
  Generated build outputs were removed to recover enough space for the passing
  quality suite. No existing source or user data was removed.

Native build results are recorded by the PR's **Android debug build** and
**iOS simulator build** CI checks. Device execution of the new integration test,
external-browser opening, VoiceOver/TalkBack user testing and live authenticated
end-to-end behavior are not verified by the local widget tests. Authentication,
account-bound durable recovery and live terminals remain app #3/#4; these changes
do not claim those capabilities or a public pilot release.

## Authentication and recovery — app #3

Validation date: 2026-11-22 (America/Denver).

- `scripts/verify.sh` passed with 37 unit/widget tests, clean analysis and
  formatting, coverage output, 20 unchanged public fixtures and preview checks.
- New checks cover installation configuration/restart, HTTPS URL rejection,
  refresh failure, account switching, concurrent refresh/logout, durable lost
  response replay, disk-write failure, stale revision reconciliation and blocked
  writes from a signed-out account generation.
- iOS simulator debug build passed with AppAuth 13.0.0 and its pinned native
  AppAuth-iOS 3.0.0 dependency, including the backup-excluded directory channel.
- Native integration adds SQLite close/reopen and exact-key replay. Platform
  execution results are pending; CI now runs these tests on both platforms.
- Secret history scans passed in app and the API companion repository.
- API companion realm/HTTPS overlay structure checks passed. Live TLS and native
  browser authentication are not verified: no target hostname/certificate was
  supplied and the local Podman VM was stopped. No running cluster was changed.

This remains incomplete until required native/runtime evidence is recorded.
No store release, public deployment or end-to-end pilot readiness is claimed.
