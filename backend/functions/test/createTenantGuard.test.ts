import * as admin from 'firebase-admin';
import { createTenantGuard } from '../src/createTenantGuard';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Minimal unit test: ensures unauthenticated call fails

test('unauthenticated call throws', async () => {
  const data = {};
  const context = { auth: undefined };
  // cast function to unknown then to any to avoid syntax issues in some babel parsers if needed, 
  // or just use bracket notation if it's exported.
  // Actually, let's just use it directly and see if typing allows it or use a simpler cast.
  
  // @ts-ignore
  await expect(createTenantGuard(data, context)).rejects.toThrow();
});
