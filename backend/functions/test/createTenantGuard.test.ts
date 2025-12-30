import { createTenantGuard } from '../src/createTenantGuard';

// Minimal unit test: ensures unauthenticated call fails

test('unauthenticated call throws', async () => {
  // call underlying function with any-typed params to avoid express Request typing in unit test
  await expect((createTenantGuard as any)({}, { auth: undefined })).rejects.toThrow();
});
