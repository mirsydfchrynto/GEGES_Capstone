const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

async function fixSuspendedUser() {
  console.log('=== FIXING SUSPENDED USER (noblxomen) ===');
  
  // 1. Find Tenant
  const tenantQ = await db.collection('tenants')
    .where('business_name', '>=', 'noblx') // Rough match
    .where('business_name', '<=', 'noblx\uf8ff')
    .get();

  if (tenantQ.empty) {
    console.log('Tenant "noblxomen" not found via query.');
    return;
  }

  const tenantDoc = tenantQ.docs[0];
  const tenant = tenantDoc.data();
  console.log(`Found Tenant: ${tenant.business_name} (Status: ${tenant.status})`);

  let targetUid = null;

  // 2. Try via Shop
  if (tenant.shop_id) {
    const shopDoc = await db.collection('barbershops').doc(tenant.shop_id).get();
    if (shopDoc.exists) {
      console.log('Found Shop:', shopDoc.data().name);
      targetUid = shopDoc.data().admin_uid;
    }
  }

  // 3. Try via Email
  if (!targetUid) {
    const email = tenant.admin_email || tenant.owner_email;
    if (email) {
      const userQ = await db.collection('users').where('email', '==', email).get();
      if (!userQ.empty) {
        targetUid = userQ.docs[0].id;
        console.log('Found User via Email:', email);
      }
    }
  }

  // 4. Update
  if (targetUid) {
    await db.collection('users').doc(targetUid).update({
      isSuspended: true,
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`SUCCESS: User ${targetUid} has been set to isSuspended: true.`);
  } else {
    console.error('FAILED: Could not find user to suspend.');
  }
}

fixSuspendedUser();
