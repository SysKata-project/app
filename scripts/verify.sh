#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Initialize a fresh SDK before reading machine-readable version output.
flutter --version
flutter --version --machine | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["frameworkVersion"]=="3.47.9" and d["dartSdkVersion"]=="3.13.7", "Use the pinned Flutter/Dart SDK"'
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --coverage
python3 scripts/check-fixtures.py
git diff --check
