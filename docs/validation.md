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
- iOS simulator debug build passed with Xcode 27.2 (27B52).
- Secret history scan passed before publication; staged changes are also scanned
  by the required commit hook.
- Full quality-command, Android build and both native integration results are
  pending; this document will be updated before review readiness is claimed.

## Limits

This is the mobile foundation. No production sign-in, lesson submission flow,
real terminal, store signing or release is claimed. Fixture responses are
examples, not validated learner progress. Supported minimums are iOS 17 and
Android 12; minimum-version device validation is not implied by tests on newer
simulators. VoiceOver/TalkBack user testing, real-device checks and complete
pilot flows remain release-gate work.
