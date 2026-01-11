const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    // databaseURL is not strictly needed for Firestore unless using RTDB
  });
}

const db = admin.firestore();

async function migrateUsersSuspension() {
  console.log('=== START MIGRATION: Initialize isSuspended for Users ===');
  
  try {
    const usersRef = db.collection('users');
    const snapshot = await usersRef.get();

    if (snapshot.empty) {
      console.log('No users found to migrate.');
      return;
    }

    let updatedCount = 0;
    let skippedCount = 0;
    const batchSize = 500;
    let batch = db.batch();
    let operationCounter = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Check if isSuspended field is missing or null
      if (data.isSuspended === undefined || data.isSuspended === null) {
        // Initialize to false (default active)
        batch.update(doc.ref, { 
          isSuspended: false,
          updated_at: admin.firestore.FieldValue.serverTimestamp()
        });
        updatedCount++;
        operationCounter++;
      } else {
        skippedCount++;
      }

      // Commit batch if limit reached
      if (operationCounter >= batchSize) {
        await batch.commit();
        console.log(`   > Committed batch of ${operationCounter} updates...`);
        batch = db.batch(); // Reset batch
        operationCounter = 0;
      }
    }

    // Commit remaining operations
    if (operationCounter > 0) {
      await batch.commit();
      console.log(`   > Committed final batch of ${operationCounter} updates.`);
    }

    console.log('=== MIGRATION COMPLETE ===');
    console.log(`Total Users Scanned: ${snapshot.size}`);
    console.log(`Updated: ${updatedCount}`);
    console.log(`Skipped (Already Set): ${skippedCount}`);

  } catch (error) {
    console.error('Migration Failed:', error);
    process.exit(1);
  }
}

migrateUsersSuspension();
