AUTH_SETUP.md

Purpose
-------
This document documents the step-by-step setup required to test and run Google Sign-In in the app and how to prepare devices (including Play App Signing and SHA-1 keys). It also includes troubleshooting tips for common errors (ApiException: 10, reCAPTCHA failures).

Prerequisites
-------------
- A Firebase project (Console) with your Android + iOS apps registered
- Google Cloud OAuth consent screen configured (internal or external depending on testing scenario)
- Access to the Play Console if you use Play App Signing (recommended for release builds)

Android: SHA-1 keys
-------------------
You must add the SHA-1 fingerprint(s) used by the app to Firebase Console (Project settings -> Your apps -> Android app -> Add fingerprint). Typical keys to add:
- Debug key (used while developing locally)
  - Command: keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android
- Release key (used to sign release builds locally)
  - Command: keytool -list -v -keystore /path/to/your/keystore.jks -alias <alias>
- Play App Signing key (if you publish and let Google manage the signing key)
  - In Play Console, go to Release > Setup > App integrity, copy the App Signing certificate SHA-1 and add it to Firebase.

After adding the SHA-1 values to Firebase: re-download `google-services.json` and place it in `android/app/` and re-run/rebuild the app.

Google OAuth client & consent
-----------------------------
- Firebase Console creates OAuth clients automatically for common cases, but sometimes you need to create OAuth client credentials in the Google Cloud Console and add correct redirect URIs.
- Ensure the OAuth consent screen is configured (an internal test user list is fine while in development).

iOS
---
- Add your iOS bundle id in Firebase Console and download `GoogleService-Info.plist` and add it to `ios/Runner`.
- For iOS, make sure you have the correct reverse client ID in Info.plist (Firebase tools usually handle this when you add the file).

reCAPTCHA / SafetyNet considerations
-----------------------------------
- Some Google sign-in / phone auth flows require reCAPTCHA or SafetyNet verification. The most common error in widget/unit tests is Firebase throwing a "recaptcha" or "no-app" error because reCAPTCHA cannot run in the test environment.
- For integration/device tests you should use a real device or an emulator with Google Play services.
- If you encounter errors mentioning reCAPTCHA or token missing, verify:
  - Firebase Auth has Google provider enabled in the console
  - The SHA-1 for the app being tested is added to Firebase
  - The device has a working Play Services/network connection

Common errors & fixes
---------------------
- ApiException: 10 / DEVELOPER_ERROR
  - Meaning: Mismatch between the SHA-1 used to sign the app and the SHA-1 registered in Firebase/Google Cloud OAuth credentials.
  - Fix: Add the correct SHA-1 (debug/release/Play App Signing) to Firebase and re-download `google-services.json`. Rebuild the app.

- [core/no-app] No Firebase App '[DEFAULT]' has been created
  - Meaning: You are running code that uses Firebase before calling `Firebase.initializeApp()`.
  - Fix: Ensure Firebase is initialized in app startup (usually in `main()` via `WidgetsFlutterBinding.ensureInitialized(); await Firebase.initializeApp();`). For widget tests, inject fakes (we use `AuthServiceBase`) or initialize `Firebase.initializeApp()` with a fake config.

Running the integration test (interactive)
------------------------------------------
The integration test is interactive and must be explicitly enabled to avoid running in CI by accident.

Example (manual run):

- On a device or emulator that's configured with the Google account you'll use for testing:
  flutter test integration_test/google_sign_in_integration_test.dart --dart-define=RUN_GOOGLE_INTEGRATION=true

Notes
-----
- Because Google Sign-In prompts external UI for account selection and consent, the test cannot be fully automated in most CI environments. Use this integration test for local manual verification on a device.
- If you need automated Google identity tests in CI, you can investigate using test accounts with programmatic authentication (server-to-server) but that requires a different auth flow and is outside scope of the mobile sign-in user flow.

Troubleshooting checklist
-------------------------
- Are the proper SHA-1 fingerprints added to Firebase?
- Have you re-downloaded & placed `google-services.json` (Android) / `GoogleService-Info.plist` (iOS)?
- Is Google Sign-In enabled in Firebase Auth providers?
- Does the test device have Google Play Services and network connectivity?
- For Play Store builds, did you add the Play App Signing certificate SHA-1 to Firebase?

Firestore composite index recommendation
---------------------------------------
The app performs queries that can benefit from a composite index on the `queues` collection, for example:

- Query: customer_id == <id> AND status == 'waiting' AND payment_deadline < now
- Query: customer_id == <id> AND status == 'awaiting_payment' AND payment_deadline < now

We include a suggested index in `firestore.indexes.json` already. To ensure this index exists in your Firebase project, deploy it with the Firebase CLI:

1) Install & login to Firebase CLI: `npm install -g firebase-tools` and `firebase login`
2) Deploy indexes: `firebase deploy --only firestore:indexes --project <YOUR_PROJECT_ID>`

If the index is missing, the app will fall back to a client-side scan (safe but slower). Adding the index improves performance and prevents the fallback message seen in the test logs.

CI / Automated tests
--------------------
- We created an integration test skeleton for Google Sign-In that is intentionally interactive and disabled by default. To run it locally set `--dart-define=RUN_GOOGLE_INTEGRATION=true` when launching the test.
- It's recommended that CI runs `flutter test --coverage` for unit & widget tests and avoids running interactive Google Sign-In integration tests. See the included GitHub Actions workflow (`.github/workflows/flutter-test.yml`) which runs unit & widget tests and skips interactive integration tests.

If you still have issues, capture logs, the exact error string (ApiException, FirebaseAuthException message), and reach out with the error message and steps you already tried.
