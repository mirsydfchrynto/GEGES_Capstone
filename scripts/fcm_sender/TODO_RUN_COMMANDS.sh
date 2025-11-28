# Quick test commands for fcm_sender
cd scripts/fcm_sender
npm install
# To process pending push_requests:
node send_push.js --processPending
# To send personal push:
node send_push.js --type=personal --uid=<USER_UID> --title='Test' --body='Hello'
# To send broadcast:
node send_push.js --type=broadcast --title='Promo' --body='Diskon'
