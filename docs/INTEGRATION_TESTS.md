Integration E2E Tests

Overview
- The repository includes an end-to-end integration test that exercises the booking flow and payment verification flow using a fake Firestore and a TestImagePicker.
- Test file: `integration_test/payment_full_ui_e2e_test.dart`.

Running locally (recommended: Android emulator)

Prerequisites (local):
- Flutter SDK installed and on PATH
- Android SDK + emulator (Android Studio or SDK tools)
- An Android AVD (API 29/30 recommended)

To run locally:
1. Start an Android emulator (or create one via AVD Manager).
2. Ensure it appears in `flutter devices`.
3. Run the integration test:

```bash
flutter test integration_test/payment_full_ui_e2e_test.dart -d emulator-5554
```

Troubleshooting (Linux desktop build error)
- If you try to run integration tests using the Linux desktop target, you may see an error about missing `libsecret-1` when Flutter attempts to build the Linux app (example: "The following required packages were not found: libsecret-1>=0.18.4").
- To avoid this, run the test on an Android emulator (recommended) or install the system package:

```bash
sudo apt update && sudo apt install -y libsecret-1-dev
```

Running in CI (GitHub Actions)
- A GitHub Actions workflow has been added: `.github/workflows/integration-e2e.yml`.
- The workflow spins up an Android emulator and runs the integration test on push/PR to `main`/`master`.

Notes
- The E2E test uses `FakeFirebaseFirestore` and an injected `TestImagePicker` to avoid network/permission flakiness and to keep runs deterministic.
- If CI fails on emulator startup or test flakiness, check the runner logs for device readiness or timeout issues.

If you want, I can add an additional job to the workflow to run the entire `integration_test` directory or to parallelize multiple devices.
