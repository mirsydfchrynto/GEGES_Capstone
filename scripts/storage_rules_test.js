// Run with: npm install --prefix scripts && npm run test:storage --prefix scripts

const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const fs = require('fs');

async function main() {
  const projectId = 'geges-storage-test';

  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
    storage: { rules: fs.readFileSync('storage.rules', 'utf8') },
  });

  try {
    // Create an admin context and tenant document
    const adminCtx = testEnv.authenticatedContext('admin1', { uid: 'admin1' });
    await adminCtx.firestore().doc('users/admin1').set({ role: 'admin' });
    await adminCtx.firestore().doc('tenants/tenant1').set({ owner_uid: 'user1', owner_email: 'u1@example.com' });

    // Owner and other user contexts
    const ownerCtx = testEnv.authenticatedContext('user1', { uid: 'user1' });
    const otherCtx = testEnv.authenticatedContext('user2', { uid: 'user2' });

    const ownerBucket = ownerCtx.storage().bucket();
    const otherBucket = otherCtx.storage().bucket();
    const adminBucket = adminCtx.storage().bucket();

    const ownerFile = ownerBucket.file('tenants/tenant1/docs/owner_doc.txt');
    const otherFile = otherBucket.file('tenants/tenant1/docs/other_doc.txt');
    const adminFile = adminBucket.file('tenants/tenant1/docs/admin_doc.txt');

    // Owner should succeed writing their tenant doc
    await assertSucceeds(ownerFile.save('owner content'));

    // Other user should fail writing
    await assertFails(otherFile.save('malicious content'));

    // Admin should succeed
    await assertSucceeds(adminFile.save('admin content'));

    // Owner should be able to read their file
    await assertSucceeds(ownerFile.download());

    // Other user should fail to read owner's file
    await assertFails(otherFile.download());

    console.log('Storage rules tests completed (check assert results).');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((e) => {
  console.error('Storage rules test failed', e);
  process.exit(1);
});
