Firestore composite indexes required

Why
- Some queries that combine equality filters and range filters (e.g., where('customer_id', isEqualTo: ...), where('status', isEqualTo: ...), where('payment_deadline', isLessThan: ...)) require a composite index in Firestore. If the index is missing, Firestore will return FAILED_PRECONDITION and a URL to create the index.

Recommended index for queues auto-cancel
- Collection: queues
- Fields:
  - customer_id: Ascending
  - status: Ascending
  - payment_deadline: Ascending

How to create
1. Click the index URL printed in your device logs when you see the FAILED_PRECONDITION error. It will open the Firebase Console with the index pre-filled.
2. Or: Go to Firebase Console → Firestore Database → Indexes → Add Index and add the fields above.

Notes and fallback
- This project now implements a safe client-side fallback when the index is missing: the service will fetch queues for a customer and apply the status + deadline filters in memory, so the feature continues to work although with more reads and worse performance.
- Creating the composite index is recommended for production to avoid extra reads and latency.

Example index definition (for reference)
{
  "collectionId": "queues",
  "fields": [
    {"fieldPath": "customer_id","order": "ASCENDING"},
    {"fieldPath": "status","order": "ASCENDING"},
    {"fieldPath": "payment_deadline","order": "ASCENDING"}
  ],
  "queryScope": "COLLECTION"
}
