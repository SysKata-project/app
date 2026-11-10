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
