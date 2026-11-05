# Development and delivery

## Current status

Documentation only. There is no pubspec.yaml, generated platform project, executable app, CI pipeline, or release artifact yet. The steps below describe the implementation plan, not commands that already work in this repository.

## Environment preparation

Select and pin a stable Flutter SDK and its bundled Dart version. Follow Flutter's official [Android setup](https://docs.flutter.dev/platform-integration/android/setup) and [iOS setup](https://docs.flutter.dev/platform-integration/ios/setup) guides. iOS development requires the appropriate macOS/Xcode environment; Android requires the Android toolchain and a device or emulator. Use `flutter doctor -v` to identify missing tooling.

Before generating the app, agree on the package identifier, bundle IDs, minimum OS versions, dependency choices, and development/staging/production configuration. Keep signing credentials and service secrets outside source control. The existing README and LICENSE must be preserved during scaffolding.

Once scaffolded, document the exact dependency installation, run, test, and build commands verified against the pinned SDK. Provide non-secret configuration examples and fake service adapters so interface development does not require production access.

## Verification plan

- Unit tests: lesson state transitions, retry/reconciliation behavior, and transformation of service results into presentation state.
- Widget tests: primary learning flows, feedback states, screen-reader semantics, large text, and navigation.
- Integration tests: sign-in, complete a lesson, recover after interruption, submit a lab assessment, and view confirmed progress.
- Device checks: iOS and Android, keyboard behavior, terminal usability, connectivity loss, background/resume, and accessibility tools.

The future CI pipeline should format-check Dart, run static analysis and relevant tests, and validate both platform builds. Use a suitable macOS runner for iOS build checks. Pull requests should not need production credentials or release-signing secrets.

## Pilot release gate

A pilot requires a documented device/OS test matrix, reproducible builds, verified progress persistence, a working lab lifecycle, accessibility review, and appropriate privacy/account controls. App signing, store metadata, screenshots, review requirements, and distribution accounts must be configured before release. Do not describe the app as available in stores until publication is confirmed.

Consult the official [Android release guide](https://docs.flutter.dev/deployment/android) and [iOS release guide](https://docs.flutter.dev/deployment/ios) when preparing release builds.
