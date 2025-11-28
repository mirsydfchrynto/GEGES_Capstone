## 🧪 Phase 2: Testing & QA Execution Guide

### Status: Starting Testing Phase ▶️

---

## Quick Start: 3 Steps to Test Everything

### Step 1️⃣: Run Dry-Run Analysis (SAFE - No Data Change)

**Via Admin Panel**:
1. Navigate to admin dashboard → "Migration & QA Tools" (new menu item)
2. Click "1. Dry-Run Analysis" button
3. Wait for analysis to complete
4. Review output

**Expected Output**:
```
🔍 === DRY RUN MODE (No changes made) ===
📊 Hasil: X grup duplikat ditemukan
  - doc1, doc2, doc3 (3 docs)
  - doc4, doc5 (2 docs)
...
✅ Dry run completed. To apply changes, call runFullCleanup()
```

**What to Check**:
- ✅ If 0 duplicates found → Skip cleanup, go to Step 2
- ✅ If duplicates found → Review which docs are authoritative
- ⚠️ If error → Check Firestore permissions

**Time**: ~30 seconds

---

### Step 2️⃣: Run QA Tests (Auto-Verify Fix Works)

**Via Admin Panel**:
1. Click "2. Run QA Tests" button
2. Tests automatically run:
   - TEST 1: Create booking → verify 1 doc
   - TEST 2: Admin confirm → verify status update
   - TEST 3: Upload proof → verify proofLocked=true
   - TEST 7: Tab exclusivity → verify no overlaps

**Expected Output**:
```
✅ PASS | TEST 1: Create Booking
   Details: Exactly 1 document created, payment field initialized

✅ PASS | TEST 2: Admin Confirm
   Details: Status updated in-place, document ID unchanged

✅ PASS | TEST 3: Upload Proof
   Details: Proof uploaded, proofLocked=true, no new documents

✅ PASS | TEST 7: Tab Exclusivity
   Details: All tabs have exclusive queries, no overlaps

📈 Total: 4 | Passed: 4 | Failed: 0
✅ All tests PASSED! Duplikasi fix is working correctly.
```

**Pass Criteria**:
- ✅ All tests show ✅ PASS
- ✅ No failed tests (Failed: 0)
- ✅ Total count correct

**If tests fail**:
- Check appointment_screen.dart imports
- Verify PaymentScreenImproved is deployed
- Check Firestore permissions for `bookings` collection
- Verify service layer (BarbermanService, BookingAntiDuplicateService)

**Time**: ~20 seconds

---

### Step 3️⃣: Full Cleanup (CAUTION - Modifies Data)

**Only after Steps 1 & 2 succeed!**

**Via Admin Panel**:
1. Click "3. Full Cleanup" button
2. Read confirmation dialog carefully
3. Click "Proceed" to confirm
4. Monitor progress

**What it does**:
- Takes duplicates identified in dry-run
- Marks each as `status: 'duplicate_removed'`
- Adds `reason` field explaining why
- Adds `removedAt` timestamp for audit trail
- Data is NOT deleted (can be recovered)

**Expected Output**:
```
⚠️ === FULL CLEANUP MODE (Making changes) ===
🔍 Mulai identifikasi duplikat...
📊 Hasil: 3 grup duplikat ditemukan
🎯 Tentukan booking authoritative...
🗑️ Menghapus 3 grup duplikat...
  ✓ Marked doc2 as duplicate_removed (keeping doc1)
  ✓ Marked doc3 as duplicate_removed (keeping doc1)
  ✓ Marked doc5 as duplicate_removed (keeping doc4)
✅ === CLEANUP COMPLETED SUCCESSFULLY ===
Total marked as duplicate_removed: 3
```

**After Cleanup**:
- ✅ Verify My Bookings doesn't show marked duplicates
- ✅ Check Firestore: duplicates have status='duplicate_removed'
- ✅ Old queries need to exclude status='duplicate_removed'

**Time**: ~1-2 minutes (depends on count)

---

## 📋 Complete QA Checklist

### Pre-Testing Setup
- [ ] All code deployed to staging
- [ ] Flutter analyzer passes (0 errors)
- [ ] PaymentScreenImproved working
- [ ] BookingAntiDuplicateService available
- [ ] Test user account ready

### Step 1: Dry-Run Analysis
- [ ] Run dry-run via admin panel
- [ ] Review output for unexpected duplicates
- [ ] Note number of groups found
- [ ] Get approval before cleanup

### Step 2: QA Tests
- [ ] All 4 automated tests pass ✅
- [ ] Test 1: Single document created
- [ ] Test 2: Status updated in-place
- [ ] Test 3: Proof locked correctly
- [ ] Test 7: Tab queries exclusive

### Step 3: Manual Testing (if needed)
- [ ] Create booking manually in app
- [ ] Confirm booking as admin
- [ ] Upload payment proof
- [ ] Verify admin can verify/reject
- [ ] Check My Bookings shows in correct tabs
- [ ] Check real-time updates (< 3 sec)

### Step 4: Full Cleanup
- [ ] Dry-run results reviewed
- [ ] QA tests all passed
- [ ] Stakeholder approval obtained
- [ ] Maintenance window scheduled
- [ ] Rollback plan prepared
- [ ] Run full cleanup
- [ ] Verify duplicates marked
- [ ] Monitor for errors (24h)

### Post-Testing
- [ ] Results documented
- [ ] Issues logged (if any)
- [ ] Sign-off from QA
- [ ] Ready for production?

---

## 🔧 Troubleshooting

### Issue: Dry-run shows "No duplicates found"
**Reason**: No actual duplicates in database (good sign!)  
**Action**: Skip cleanup, proceed to Step 2  
**Next**: Deploy to production with confidence

### Issue: QA test fails - "Exactly 1 document expected, found X"
**Reason**: Multiple docs being created (old bug still present)  
**Action**: Check appointment_screen._processBooking() implementation  
**Debug**: Verify using createBookingInBookings(), not createQueue()  
**Fix**: Review code changes, ensure deployment successful

### Issue: QA test fails - "Tab exclusivity: duplicates in multiple tabs"
**Reason**: Query filters not mutually exclusive  
**Action**: Check streamCustomerBookingsFiltered() in BookingAntiDuplicateService  
**Debug**: Verify WHERE clauses for each tab  
**Fix**: Review tab filter logic, add/modify query conditions

### Issue: Full cleanup hangs or times out
**Reason**: Large number of duplicates (thousands)  
**Action**: Cancel & try smaller batch  
**Optimize**: Consider splitting into smaller cleanup batches  
**Alternative**: Contact team for assistance

### Issue: "Firestore permission denied"
**Reason**: Missing read/write on `bookings` collection  
**Action**: Check Firestore security rules  
**Fix**: Ensure rules allow admin read/write to all booking fields  
**Example rule**:
```
match /bookings/{bookingId} {
  allow read: if request.auth != null;
  allow write: if request.auth.token.admin == true;
}
```

---

## 📊 Success Criteria

### Dry-Run Analysis
✅ Completes without error  
✅ Reports number of duplicate groups  
✅ Identifies authoritative booking for each group  
✅ Shows which docs would be marked

### QA Tests
✅ TEST 1 passes: 1 document created  
✅ TEST 2 passes: Status updated in-place  
✅ TEST 3 passes: Proof locked correctly  
✅ TEST 7 passes: Tab queries exclusive  
✅ All 4/4 tests show ✅ PASS

### Full Cleanup
✅ Completes without error  
✅ All duplicates marked as `duplicate_removed`  
✅ My Bookings no longer shows marked docs  
✅ No data is hard-deleted (recoverable)

### Production Readiness
✅ All QA checks passed  
✅ No duplicate documents in new bookings  
✅ My Bookings UI shows correct tabs  
✅ Payment flow works end-to-end  
✅ Real-time updates responsive  

---

## 🎯 Testing Timeline

```
Estimated Time Breakdown:

Setup                     | 5 minutes
  - Deploy to staging
  - Prepare test user

Dry-Run Analysis         | 2 minutes
  - Run analysis
  - Review results

QA Tests                 | 5 minutes
  - Run automated tests
  - Review results

Manual Testing (optional)| 15 minutes
  - Create booking
  - Confirm, upload, verify
  - Check UI

Full Cleanup            | 2 minutes
  - Confirmation
  - Mark duplicates
  - Monitor result

Documentation           | 5 minutes
  - Document results
  - Get sign-offs
  - Prepare for prod

TOTAL: 30-45 minutes
```

---

## 📝 Test Results Template

Copy & fill this for documentation:

```
QA Execution Report
==================
Date: _______________
Tester: _______________
Environment: Staging / Production

PHASE 1: DRY-RUN ANALYSIS
Status: PASS / FAIL
Duplicate Groups Found: ___
Details: ________________________

PHASE 2: QA TESTS
Test 1 (Create Booking): PASS / FAIL
Test 2 (Admin Confirm): PASS / FAIL
Test 3 (Upload Proof): PASS / FAIL
Test 7 (Tab Exclusivity): PASS / FAIL
Overall: ✅ PASS / ❌ FAIL

PHASE 3: FULL CLEANUP
Status: COMPLETED / SKIPPED
Duplicates Marked: ___
Issues: ________________________

SIGN-OFF
QA: _______________ Date: ___________
Dev: _______________ Date: ___________
```

---

## 🚀 Next: Production Deployment

After all tests pass:

```
1. ✅ All QA checks PASS
   ↓
2. Schedule maintenance window
   ↓
3. Deploy to production
   ↓
4. Monitor for 48 hours
   - New bookings: check for duplicates
   - UI: verify correct tabs
   - Payment: verify flow works
   ↓
5. Optional: Run cleanup on production
   - If many old duplicates exist
   - During low-traffic window
```

---

**Files for testing**:
- Admin panel: `lib/screens/admin/admin_migration_screen.dart`
- QA executor: `lib/test_qa_execution.dart`
- Dry-run script: `lib/test_dry_run_migration.dart`
- QA checklist: `QA_CHECKLIST_DUPLIKAT_FIX.md`

**Ready to test?** Start with Step 1: Dry-Run Analysis ▶️
