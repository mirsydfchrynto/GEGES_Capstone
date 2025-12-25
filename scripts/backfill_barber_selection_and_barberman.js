/*
Backfill script for new fields:
- queues: barber_selection_fee (int) default 0
          paid_barber_selection (bool) default false
- barbermen: offDays (array of strings) default []
            onLeave (bool) default false
            annualLeaveDays (int) default 0

Usage:
1) Install firebase-admin: npm i firebase-admin
2) Ensure you have a service account JSON and set GOOGLE_APPLICATION_CREDENTIALS env var to its path
3) Run: node backfill_barber_selection_and_barberman.js

This script runs simple batched updates and logs progress.
*/

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function backfillQueues(batchSize = 500) {
  console.log('Starting backfill for queues...');
  let last = null;
  while (true) {
    let q = db.collection('queues').orderBy('__name__').limit(batchSize);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach(doc => {
      const data = doc.data();
      const needs = {};
      if (data.barber_selection_fee === undefined) needs.barber_selection_fee = 0;
      if (data.paid_barber_selection === undefined) needs.paid_barber_selection = false;
      if (Object.keys(needs).length > 0) {
        batch.update(doc.ref, needs);
      }
    });
    await batch.commit();
    last = snap.docs[snap.docs.length - 1];
    console.log(`Backfilled ${snap.docs.length} queue docs`);
    if (snap.docs.length < batchSize) break;
  }
  console.log('Queues backfill complete');
}

async function backfillBarbermen(batchSize = 500) {
  console.log('Starting backfill for barbermen...');
  let last = null;
  while (true) {
    let q = db.collection('barbermen').orderBy('__name__').limit(batchSize);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach(doc => {
      const data = doc.data();
      const needs = {};
      if (data.offDays === undefined) needs.offDays = [];
      if (data.onLeave === undefined) needs.onLeave = false;
      if (data.annualLeaveDays === undefined) needs.annualLeaveDays = 0;
      if (Object.keys(needs).length > 0) {
        batch.update(doc.ref, needs);
      }
    });
    await batch.commit();
    last = snap.docs[snap.docs.length - 1];
    console.log(`Backfilled ${snap.docs.length} barbermen docs`);
    if (snap.docs.length < batchSize) break;
  }
  console.log('Barbermen backfill complete');
}

async function main() {
  try {
    await backfillQueues();
    await backfillBarbermen();
    console.log('All done');
  } catch (e) {
    console.error('Error during backfill', e);
  }
}

main();
