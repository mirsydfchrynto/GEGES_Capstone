import { https } from 'firebase-functions';
import * as admin from 'firebase-admin';

export const createTenantGuard = async (data: any, context: any) => {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
  const db = admin.firestore();

  const IN_PROGRESS_STATUSES = ['draft', 'awaiting_payment', 'awaiting_confirmation', 'payment_submitted', 'waiting_proof'];

  const uid = context.auth?.uid;
  if (!uid) {
    throw new https.HttpsError('unauthenticated', 'Authentication required');
  }

  // validate input
  const businessName = (data.businessName || '').toString();
  const documentBase64 = (data.documentBase64 || '').toString();
  const packageId = (data.packageId || 'basic').toString();

  if (businessName.trim().length === 0 || documentBase64.trim().length === 0) {
    throw new https.HttpsError('invalid-argument', 'Missing required fields');
  }

  // Query for existing in-progress tenant for this owner
  const q = await db.collection('tenants').where('owner_uid', '==', uid).get();
  for (const doc of q.docs) {
    const data = doc.data();
    const status = (data.status || '').toString();
    if (IN_PROGRESS_STATUSES.includes(status)) {
      throw new https.HttpsError('failed-precondition', 'Existing active registration', { tenantId: doc.id, status });
    }
  }

  // Create tenant document atomically in admin context
  const now = admin.firestore.Timestamp.now();
  const docRef = db.collection('tenants').doc();
  const payload = {
    owner_uid: uid,
    business_name: businessName,
    document_base64: documentBase64,
    package_id: packageId,
    status: 'draft',
    created_at: now,
    updated_at: now,
  } as any;

  await docRef.set(payload);

  return { tenantId: docRef.id };
};
