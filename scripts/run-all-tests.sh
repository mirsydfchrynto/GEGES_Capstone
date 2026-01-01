#!/usr/bin/env bash
set -euo pipefail

echo "==> Running Flutter analyzer"
flutter analyze || echo "Analyzer warnings/errors present — continuing to run tests"

echo "==> Running Flutter unit & widget tests (fast)"
# Exclude integration tests by pattern
files=$(git ls-files 'test/**' | grep '_test.dart$' | grep -Ev 'integration|e2e' || true)
if [ -n "$files" ]; then
  flutter test $files --coverage
else
  echo "No unit/widget tests found"
fi

echo "==> Running backend functions unit tests (Jest)"
if [ -d backend/functions ]; then
  pushd backend/functions >/dev/null
  npm ci
  npm test
  popd >/dev/null
else
  echo "No backend functions directory found; skipping"
fi

echo "All tests completed. Note: analyzer is run but test execution continues even if analyzer reports errors."