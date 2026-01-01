import * as admin from 'firebase-admin';

export const cancelExpiredInvoicesWithFirestore = async (db: admin.firestore.Firestore) => {
    const now = admin.firestore.Timestamp.now();
    let updated = 0;

    // Query tenants with status 'awaiting_payment'
    // We assume there is an 'invoice.payment_deadline' field.
    const query = db.collection('tenants')
        .where('status', '==', 'awaiting_payment');
        
    const snapshot = await query.get();
    
    const batch = db.batch();
    
    snapshot.docs.forEach(doc => {
        const data = doc.data();
        const invoice = data.invoice || {};
        const deadline = invoice.payment_deadline;
        
        if (deadline && deadline instanceof admin.firestore.Timestamp && deadline.toMillis() < now.toMillis()) {
            batch.update(doc.ref, {
                status: 'cancelled',
                updated_at: now,
                'invoice.status': 'expired'
            });
            updated++;
        }
    });

    if (updated > 0) {
        await batch.commit();
    }

    return { updated };
};
