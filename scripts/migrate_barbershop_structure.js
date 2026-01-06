const admin = require('firebase-admin');

// Inisialisasi Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'geges-smartbarber-project'
  });
}

const db = admin.firestore();

async function migrateBarbershopStructure() {
  console.log('🚀 Starting Barbershop Structure Migration...');
  
  const snapshot = await db.collection('barbershops').get();
  
  if (snapshot.empty) {
    console.log('No barbershops found.');
    return;
  }

  const batch = db.batch();
  let count = 0;

  snapshot.docs.forEach((doc) => {
    const data = doc.data();
    const updateData = {};
    let needsUpdate = false;

    // 1. Add isActive if missing
    if (data.isActive === undefined) {
      updateData.isActive = true;
      needsUpdate = true;
    }

    // 2. Remove rating if exists
    if (data.rating !== undefined) {
      updateData.rating = admin.firestore.FieldValue.delete();
      needsUpdate = true;
    }

    // 3. Rename 'addres' to 'address' if typo exists
    if (data.addres !== undefined && data.address === undefined) {
        updateData.address = data.addres;
        updateData.addres = admin.firestore.FieldValue.delete();
        needsUpdate = true;
    }

    if (needsUpdate) {
      updateData.updated_at = admin.firestore.FieldValue.serverTimestamp();
      batch.update(doc.ref, updateData);
      count++;
    }
  });

  if (count > 0) {
    await batch.commit();
    console.log(`✅ Success! Updated ${count} barbershops (Added isActive, Removed rating).`);
  } else {
    console.log('ℹ️ No barbershops needed migration.');
  }
}

migrateBarbershopStructure().catch(console.error);
