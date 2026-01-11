const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

async function migrateWebFields() {
  console.log('=== START MIGRATION: Initialize isDeleted for Web Admin ===');
  
  const collections = ['users', 'barbershops', 'tenants'];
  const batchSize = 500;

  for (const colName of collections) {
    console.log(`Processing collection: ${colName}...`);
    const snapshot = await db.collection(colName).get();
    
    if (snapshot.empty) {
      console.log(`   > No documents in ${colName}.`);
      continue;
    }

    let batch = db.batch();
    let counter = 0;
    let updatedCount = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      let needsUpdate = false;
      const updates = {};

      // 1. Initialize isDeleted = false if missing
      if (data.isDeleted === undefined || data.isDeleted === null) {
        updates.isDeleted = false;
        needsUpdate = true;
      }

      // 2. Initialize isSuspended = false for Users (if missing)
      if (colName === 'users' && (data.isSuspended === undefined || data.isSuspended === null)) {
        updates.isSuspended = false;
        needsUpdate = true;
      }

      // 3. Initialize isActive = true for Barbershops (if missing)
      if (colName === 'barbershops' && (data.isActive === undefined || data.isActive === null)) {
        updates.isActive = true;
        needsUpdate = true;
      }

      if (needsUpdate) {
        batch.update(doc.ref, updates);
        counter++;
        updatedCount++;
      }

      if (counter >= batchSize) {
        await batch.commit();
        console.log(`   > Committed batch of ${counter} in ${colName}.`);
        batch = db.batch();
        counter = 0;
      }
    }

    if (counter > 0) {
      await batch.commit();
      console.log(`   > Committed final batch of ${counter} in ${colName}.`);
    }
    console.log(`   > Total updated in ${colName}: ${updatedCount}`);
  }

  console.log('=== MIGRATION COMPLETE ===');
}

migrateWebFields();
