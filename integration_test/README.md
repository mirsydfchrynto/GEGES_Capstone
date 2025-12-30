E2E Integration Test Guide

This folder contains a scaffold for an end-to-end test that validates the
resume-payment flow when the app is closed and re-opened. It's designed to run
against the Firebase emulators.

Setup

1. Start Firebase emulators (Firestore + Functions if needed):

```bash
firebase emulators:start --only firestore,functions
```

2. Run the integration test with the Firestore emulator host passed via Dart define:

```bash
# example: emulator on localhost:8080 (default)
flutter test integration_test/e2e_resume_payment_test.dart --dart-define=FIRESTORE_EMULATOR_HOST=localhost:8080
```

Notes
- The test is a scaffold; implement app launch and interactions specific to your
  app (import your `main()` and drive taps, form fills, etc.).
- For payment gateway interactions, prefer test-mode endpoints or mocked
  responses in Functions or the emulator.
