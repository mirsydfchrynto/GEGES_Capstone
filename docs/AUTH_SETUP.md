Authentication & Google Sign-In setup (short)

Common issues observed during development:
- reCAPTCHA / "empty reCAPTCHA token" messages
- Google sign-in ApiException: 10 / DEVELOPER_ERROR
- App Check warnings: "No AppCheckProvider installed"

Recommended steps
1) Google Sign-In (Android)
   - Add SHA-1 debug and release fingerprints to your Firebase project settings (Authentication -> Sign-in method -> Google -> OAuth client or Project settings -> General -> Add fingerprint)
   - Download the updated google-services.json and replace it in android/app/
   - Rebuild the app (flutter clean && flutter build apk)
   - If your app is published to Play Store and using App Signing, also add the Play-Store signing SHA.

2) reCAPTCHA / Auth verify issues
   - Some auth flows may require reCAPTCHA verification (depending on the auth method). If you see "empty reCAPTCHA token" or related errors, verify the browser domains allowed in the Firebase Console (for web flows) and ensure network access.
   - For debugging on physical devices, sign-in with email/password is a reliable fallback.

3) App Check
   - "No AppCheckProvider installed" is a warning when App Check is not configured. This is not fatal for auth, but we recommend configuring App Check for production (or use Debug provider during development).
   - See: https://firebase.google.com/docs/app-check

4) When encountering errors in development
   - Capture full device logs (adb logcat) and look for specific error text (e.g., "DEVELOPER_ERROR", "recaptcha").
   - Common actionable message: "Terjadi kesalahan saat Google sign-in: (ApiException: 10). Ini biasanya disebabkan oleh konfigurasi OAuth/SHA-1 yang belum cocok." — follow the steps above.

If you'd like, I can add a short in-app help dialog linking to these steps or detect these error types and show an actionable snackbar (retry / instructions).