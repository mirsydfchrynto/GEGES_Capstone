# Penting: Data Model Compatibility - OLD vs NEW

## Situasi Saat Ini

Proyek menggunakan **2 data model berbeda**:

### OLD Model (Current - Queue Based)
```dart
// lib/screens/customer/payment_screen.dart
class PaymentScreen extends StatefulWidget {
  final String orderId;          // Queue ID
  final int totalPrice;
  final String? barbershopId;    // Barbershop reference
  final String? barbermanId;     // Barber reference
  final DateTime? bookingTime;
  final List<String>? serviceIds;
  final DateTime? paymentDeadline;
}
```

**Collections:**
- `queues` — Legacy queue system
- `payment_proofs` — Upload bukti pembayaran

### NEW Model (New Implementation - Booking Based)
```dart
// lib/screens/customer/payment_screen_improved.dart
class PaymentScreenImproved extends StatefulWidget {
  final String bookingId;        // Booking ID
  final int totalPrice;
  // Lebih simple, reliant on Firestore doc
}
```

**Collections:**
- `bookings` — New centralized booking system
- Uses nested `payment` field dalam dokumen booking

---

## Decision: Support BOTH Models (Parallel)

### Why Two Models?
1. **Old model** (`queues`) — Already in use, working, has existing data
2. **New model** (`bookings`) — Cleaner design, prevents duplication, supports verified payments

### Implementation Strategy

#### Option A: Gradual Migration (Recommended)
1. **Phase 1** (now): Keep old payment_screen.dart working, add new screens alongside
2. **Phase 2** (next sprint): Migrate historical queue data to bookings collection
3. **Phase 3** (later): Sunset old queue system

#### Option B: Immediate Full Migration (Risky)
- Converts all queue records to bookings — high risk of data loss

#### Option C: Dual System (Complex)
- Run both models simultaneously — too complex

**→ We recommend Option A: Gradual Migration**

---

## For Now: New Screens Standalone

The 4 new files are **standalone implementations** for the booking system:

| File | Uses | Collection | Compatible With |
|------|------|-----------|-----------------|
| `booking_anti_duplicate_service.dart` | Firestore transactions | `bookings` | NEW model only |
| `payment_screen_improved.dart` | Anti-duplicate logic | `bookings` | NEW model only |
| `my_bookings_screen_improved.dart` | Tab-based UI | `bookings` | NEW model only |
| `payment_verification_screen_improved.dart` | Admin verification | `bookings` | NEW model only |

**DO NOT try to use new screens with old queue system** — will cause crashes.

---

## Path Forward

### Immediate Actions (This Sprint)
✅ Deliver new screens as **optional/parallel** implementation
✅ Document both models
✅ Create migration playbook
✅ Test new model with small user group

### Next Sprint
🔄 Migrate test data from queues → bookings
🔄 Run parallel testing (old + new systems)
🔄 Get stakeholder approval for cutover

### Cutover Sprint
🚀 Migrate production queues → bookings
🚀 Monitor for 48 hours
🚀 Rollback if critical issues
🚀 Sunset old payment_screen.dart

---

## Code Organization (Current State)

```
lib/
├── services/
│   ├── queue_service.dart          (OLD - for queues collection)
│   ├── booking_anti_duplicate_service.dart  (NEW - for bookings collection)
│
├── screens/customer/
│   ├── payment_screen.dart         (OLD - uses orderId)
│   ├── payment_screen_improved.dart  (NEW - uses bookingId)
│   ├── tabs/my_bookings_screen.dart  (OLD - legacy)
│   ├── my_bookings_screen_improved.dart  (NEW - 5 tabs)
│
├── screens/admin/
│   ├── payment_verification_screen.dart  (OLD - uses queues)
│   ├── payment_verification_screen_improved.dart  (NEW - uses bookings)
```

---

## Testing Approach

### For Immediate QA
**Use NEW screens only for NEW bookings workflow:**

1. Create test booking via new flow
2. Use new payment screen
3. Admin uses new verification screen
4. Check my_bookings with new tabs

**Old workflow remains unchanged:**

1. Existing queues → old payment screen
2. Old admin verification
3. Works as-is (backward compatible)

---

## Migration Checklist (For Future)

When ready to migrate from queues → bookings:

- [ ] Backup queues collection
- [ ] Create migration script (queue → booking)
- [ ] Test migration on staging DB
- [ ] Validate all bookings created correctly
- [ ] Update payment_screen default to use new model
- [ ] Update admin dashboard to use new verification screen
- [ ] Run full regression testing
- [ ] Deploy with feature flag (kill switch)
- [ ] Monitor Firestore writes for 48h
- [ ] Archive old queues collection

---

## Deployment for NEW Screens (Today)

### Add to App Without Breaking Changes

1. Deploy 4 new files as-is
2. Add new route in navigation (separate from old payment flow)
3. Tag with feature flag: `BOOKING_ANTI_DUPLICATE_ENABLED = false` (default)
4. When ready: `BOOKING_ANTI_DUPLICATE_ENABLED = true`

### Example Implementation

```dart
// In main.dart or route handler
if (BuildFeatureFlags.bookingAntiDuplicateEnabled) {
  // Use new booking flow
  return PaymentScreenImproved(
    bookingId: bookingId,
    totalPrice: totalPrice,
  );
} else {
  // Use old queue flow
  return PaymentScreen(
    orderId: orderId,
    totalPrice: totalPrice,
    // ... other params
  );
}
```

---

## Summary

| Aspect | OLD (Queues) | NEW (Bookings) |
|--------|------|--------|
| Collections | `queues`, `payment_proofs` | `bookings` (nested payment) |
| Used By | `payment_screen.dart` | `payment_screen_improved.dart` |
| Status | In Production | Development (parallel) |
| Risk Level | Low (no changes) | Medium (new implementation) |
| Timeline | Keep as-is | Gradual migration in future |

**Next Step:** Deploy new screens as optional feature. Begin planning migration for next sprint.
