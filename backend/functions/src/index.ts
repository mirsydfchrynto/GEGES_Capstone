import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { cancelExpiredInvoicesWithFirestore } from './lib';
import { createTenantGuard } from './createTenantGuard';

admin.initializeApp();

export const scheduledCancelExpiredInvoices = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const res = await cancelExpiredInvoicesWithFirestore(admin.firestore());
    functions.logger.info('Cancelled expired tenant invoices', { count: res.updated });
    return { cancelled: res.updated };
  });

export const createTenantGuardFn = functions.https.onCall(createTenantGuard);

