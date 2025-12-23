// This test was disabled because mocking Firestore.runTransaction reliably
// across Firebase SDK versions and Mockito generated mocks introduced
// brittle type errors in CI. We replaced scoped unit tests with
// emulator-based integration tests for transaction coverage. If you
// need to re-enable these unit tests, consider using generated typed
// mocks via `build_runner` or convert to an emulator-backed test.

void main() {
  // intentionally empty - transactional unit test disabled
}
