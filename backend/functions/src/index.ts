import { https, pubsub, logger } from 'firebase-functions';
import * as admin from 'firebase-admin';
import { cancelExpiredInvoicesWithFirestore } from './lib';
import { createTenantGuard } from './createTenantGuard';

admin.initializeApp();

export const scheduledCancelExpiredInvoices = pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const res = await cancelExpiredInvoicesWithFirestore(admin.firestore());
    logger.info('Cancelled expired tenant invoices', { count: res.updated });
    return { cancelled: res.updated };
  });

export const createTenantGuardFn = https.onCall(createTenantGuard);

