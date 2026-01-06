const admin = require('firebase-admin');

// Initialize Firebase Admin
// If running locally with 'firebase emulators:start', this connects to emulator automatically if FIRESTORE_EMULATOR_HOST is set.
// Otherwise it attempts to connect to the real project configured in environment or default credentials.
if (!admin.apps.length) {
  try {
    admin.initializeApp({
      projectId: 'geges-smartbarber-project'
    });
  } catch (e) {
    console.error('Failed to initialize admin:', e);
    process.exit(1);
  }
}

const db = admin.firestore();

async function clearTenants() {
  console.log('Starting cleanup of "tenants" collection...');
  
  const collectionRef = db.collection('tenants');
  const snapshot = await collectionRef.get();

  if (snapshot.empty) {
    console.log('No tenant documents found. Cleanup complete.');
    return;
  }

  console.log(`Found ${snapshot.size} tenant documents. Deleting...`);

  const batch = db.batch();
  let count = 0;

  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
    count++;
  });

  await batch.commit();
  console.log(`Successfully deleted ${count} tenant documents.`);
}

clearTenants().catch(console.error);
