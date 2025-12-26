// Run with: npm install --prefix scripts && npm run test:storage --prefix scripts

const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const fs = require('fs');

async function main() {
  const projectId = 'geges-storage-test';

  // If emulators are not configured in the environment, skip the storage rules test
  // This makes running tests locally without an emulator safe; CI should run the
  // test inside `firebase emulators:exec` so assertions are exercised there.
  if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    console.log('Emulators not configured; skipping storage rules tests.');
    return;
  }

  const path = require('path');
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
    storage: { rules: fs.readFileSync(path.join(__dirname, '..', 'storage.rules'), 'utf8') },
  });

  try {
    // Create initial data using the admin SDK (bypass security rules) so tests can run deterministically
    const admin = require('firebase-admin');
    try { admin.initializeApp({ projectId }); } catch (e) { /* already initialized */ }
    const adminDb = admin.firestore();

    await adminDb.doc('users/admin1').set({ role: 'admin' });
    await adminDb.doc('tenants/tenant1').set({ owner_uid: 'user1', owner_email: 'u1@example.com' });

    // Owner and other user contexts
    const ownerCtx = testEnv.authenticatedContext('user1');
    const otherCtx = testEnv.authenticatedContext('user2');

    console.log('ownerCtx.storage exists?', !!ownerCtx.storage, 'typeof:', typeof ownerCtx.storage);
    if (ownerCtx.storage) console.log('ownerCtx.storage keys:', Object.keys(ownerCtx.storage));
    const ownerBucket = ownerCtx.storage ? ownerCtx.storage().bucket() : null;
    const otherBucket = otherCtx.storage ? otherCtx.storage().bucket() : null;
    const adminBucket = adminCtx.storage ? adminCtx.storage().bucket() : null;

    const ownerFile = ownerBucket.file('tenants/tenant1/docs/owner_doc.png');
    const otherFile = otherBucket.file('tenants/tenant1/docs/other_doc.png');
    const adminFile = adminBucket.file('tenants/tenant1/docs/admin_doc.pdf');

    // Valid small image upload by owner should succeed
    await assertSucceeds(ownerFile.save(Buffer.from('small image'), { metadata: { contentType: 'image/png' } }));

    // Upload with disallowed content type should fail
    const badFile = ownerBucket.file('tenants/tenant1/docs/bad.bin');
    await assertFails(badFile.save(Buffer.from('data'), { metadata: { contentType: 'application/octet-stream' } }));

    // Upload that exceeds size limit should fail (6MB)
    const largeFile = ownerBucket.file('tenants/tenant1/docs/large.png');
    const largeBuf = Buffer.alloc(6 * 1024 * 1024, 'a'); // 6MB
    await assertFails(largeFile.save(largeBuf, { metadata: { contentType: 'image/png' } }));

    // Other user should fail writing their tenant doc
    await assertFails(otherFile.save(Buffer.from('malicious'), { metadata: { contentType: 'image/png' } }));

    // Admin should succeed writing a pdf
    await assertSucceeds(adminFile.save(Buffer.from('admin doc'), { metadata: { contentType: 'application/pdf' } }));

    // Owner should be able to read their file
    await assertSucceeds(ownerFile.download());

    // Other user should fail to read owner's file
    await assertFails(otherFile.download());

    // Listing behavior: owner and admin can list, other cannot
    await assertSucceeds(ownerBucket.getFiles({ prefix: 'tenants/tenant1/docs/' }));
    await assertFails(otherBucket.getFiles({ prefix: 'tenants/tenant1/docs/' }));
    await assertSucceeds(adminBucket.getFiles({ prefix: 'tenants/tenant1/docs/' }));

    // Unauthenticated users should not be able to read or list tenant docs
    const unauthCtx = testEnv.unauthenticatedContext();
    const unauthBucket = unauthCtx.storage().bucket();
    const unauthFile = unauthBucket.file('tenants/tenant1/docs/owner_doc.png');
    await assertFails(unauthFile.download());
    await assertFails(unauthBucket.getFiles({ prefix: 'tenants/tenant1/docs/' }));


    console.log('Storage rules tests completed (check assert results).');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((e) => {
  console.error('Storage rules test failed', e);
  process.exit(1);
});
