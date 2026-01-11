const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

async function fixSpecificUser() {
  const email = 'noblxomen@gmail.com';
  console.log(`=== FIXING USER: ${email} ===`);
  
  try {
    const userQ = await db.collection('users').where('email', '==', email).get();
    
    if (userQ.empty) {
      console.error(`User with email ${email} not found.`);
      return;
    }

    const userDoc = userQ.docs[0];
    await userDoc.ref.update({
      isSuspended: true,
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`SUCCESS: User ${userDoc.id} (${email}) is now SUSPENDED.`);

    // Also ensure the Barbershop linked to this user is deactivated
    const shopId = userDoc.data().barbershop_id;
    if (shopId) {
      await db.collection('barbershops').doc(shopId).update({
        isActive: false,
        isOpen: false
      });
      console.log(`SUCCESS: Barbershop ${shopId} is now INACTIVE and CLOSED.`);
    }

  } catch (error) {
    console.error('Error fixing user:', error);
  }
}

fixSpecificUser();
