// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Geges Smart Barber';

  @override
  String get welcome => 'Welcome to GEGES';

  @override
  String get login => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get home => 'Home';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get notifications => 'Notifications';

  @override
  String get searchHint => 'Search Barbershop or Services';

  @override
  String get bookNow => 'Book Now';

  @override
  String get waitingForPayment => 'Waiting for Payment';

  @override
  String get verificationPending => 'Verification Pending';

  @override
  String get bookingSuccess => 'Booking Successful';

  @override
  String get cancel => 'Cancel';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get registerErrAllFields => 'All fields are required.';

  @override
  String get registerErrNameMin => 'Name must be at least 3 characters.';

  @override
  String get registerErrEmailFormat => 'Invalid email format.';

  @override
  String get registerErrPasswordMismatch => 'Passwords do not match.';

  @override
  String get registerErrPasswordMin =>
      'Password must be at least 6 characters.';

  @override
  String get registerMsgSuccess => 'Registration Successful!';

  @override
  String get registerMsgGoogleSuccess => 'Google Sign-in Successful!';

  @override
  String get myLocation => 'My Location';

  @override
  String get locating => 'Determining location...';

  @override
  String get locationNotFound => 'Location not found';

  @override
  String get locationError => 'Location error';

  @override
  String get barbershopsNearYou => 'Barbershops\nnear you';

  @override
  String get failedToLoadShops => 'Failed to load barbershops.';

  @override
  String foundResults(int count) {
    return 'Found $count results';
  }

  @override
  String get styleScan => 'StyleScan';

  @override
  String get chatbot => 'Chatbot';

  @override
  String get profileTab => 'Profile';

  @override
  String get signOut => 'Sign Out';

  @override
  String get language => 'Language';

  @override
  String get changeLanguage => 'Change Language';

  @override
  String get paymentTitle => 'Waiting for Payment';

  @override
  String get totalBill => 'Total Bill';

  @override
  String get transferTo => 'Transfer To';

  @override
  String get paymentProof => 'Payment Proof';

  @override
  String get tapToUpload => 'Tap to upload photo';

  @override
  String get uploadLocked => 'Upload Locked';

  @override
  String get sendProof => 'Send Payment Proof';

  @override
  String get sending => 'Sending...';

  @override
  String get verifying => 'Verifying';

  @override
  String get paymentRejected => 'Proof Rejected';

  @override
  String get timeOut => 'Timed Out';

  @override
  String get paymentAccepted => 'Payment Accepted!';

  @override
  String get paymentSuccessDesc =>
      'Thank you, your booking has been confirmed. Please arrive on time.';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get welcomeSubtitle => 'Sign in or create an account to get started.';

  @override
  String get signInTab => 'Log in';

  @override
  String get orSplit => 'or';

  @override
  String get termFooterPre => 'By continuing, you agree to our\n';

  @override
  String get termFooterService => 'Terms of Services';

  @override
  String get termFooterAnd => ' and ';

  @override
  String get termFooterPrivacy => 'Privacy Policy';

  @override
  String get errLoginEmpty => 'Email and password are required.';

  @override
  String get errEmailFormat => 'Invalid email format.';

  @override
  String get errLoginFailed => 'Login failed.';

  @override
  String errGeneric(String error) {
    return 'An error occurred: $error';
  }

  @override
  String errRoleInvalid(String role) {
    return 'Invalid user role: $role';
  }

  @override
  String msgResetSent(String email) {
    return 'Password reset link has been sent to $email.';
  }

  @override
  String get msgResetFail => 'Failed to send password reset link.';

  @override
  String get dialogResetTitle => 'Reset Password';

  @override
  String get dialogResetHint => 'Enter your email';

  @override
  String get dialogResetCancel => 'Cancel';

  @override
  String get btnSend => 'Send';

  @override
  String get btnRetry => 'Retry';

  @override
  String get troubleshootTitle => 'Troubleshoot Sign-in';

  @override
  String get strengthWeak => 'Weak';

  @override
  String get strengthMedium => 'Medium';

  @override
  String get strengthStrong => 'Strong';

  @override
  String get strengthLabel => 'Password Strength: ';

  @override
  String get username => 'Username';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get createAccount => 'Create Account';

  @override
  String get troubleshootContent =>
      'If you see a reCAPTCHA or Developer Error message, check the following steps:\n- Ensure SHA-1 debug/release is added to Firebase Console\n- Replace google-services.json if necessary and rebuild the app\n- For reCAPTCHA issues, try logging in with email/password as fallback\n- App Check can be ignored in development or configured for production';

  @override
  String get btnClose => 'Close';

  @override
  String get shopClosed => 'CLOSED';

  @override
  String noResultsFor(String query) {
    return 'No results found for \"$query\"';
  }

  @override
  String get history => 'History';

  @override
  String get favoriteBarbers => 'Favorite Barbers';

  @override
  String get appRating => 'App Rating';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get promoGrowTitle => 'Grow Your Barbershop with us';

  @override
  String get promoGrowSubtitle => 'Join our network of Professional Barbers';

  @override
  String get registerMyBarbershop => 'Register my Barbershop';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get loading => 'Loading...';

  @override
  String get searchHintHome => 'Search Barbershop or Services';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get fullName => 'Full Name';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get requiredField => 'Required field';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get saveChangesBtn => 'SAVE CHANGES';

  @override
  String errPickImage(String error) {
    return 'Failed to pick image: $error';
  }

  @override
  String get confirmPasswordTitle => 'Confirm Password';

  @override
  String get enterPasswordHint => 'Enter your password';

  @override
  String get continueBtn => 'Continue';

  @override
  String get errReauthFailed => 'Re-authentication failed.';

  @override
  String get errUpdateProfile => 'Failed to update profile.';

  @override
  String get verifyNewEmailTitle => 'Verify New Email';

  @override
  String verifyNewEmailMsg(String email) {
    return 'We have sent a verification link to:\n\n$email\n\nPlease check your email.';
  }

  @override
  String get ok => 'Ok';

  @override
  String get styleScanTitle => 'AI Haircut Scan';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get uploadImage => 'Upload Image';

  @override
  String get scanResultTitle => 'Style Scan Result';

  @override
  String get aiAnalysis => 'AI Analysis:';

  @override
  String get detectedStyle => 'Detected Style:';

  @override
  String get confidence => 'Confidence:';

  @override
  String get faceShape => 'Face Shape:';

  @override
  String get descriptionLabel => 'Description:';

  @override
  String get bookWithThisStyle => 'Book Barbershop with This Style';

  @override
  String get rescan => 'Rescan / Take New Picture';

  @override
  String errScanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get cameraAccessDenied => 'Camera access denied.';

  @override
  String get galleryAccessDenied => 'Gallery access denied.';

  @override
  String get chatTitle => 'GIA - GEGES Intelligent Assistant';

  @override
  String get giaGreeting =>
      'Hello! I am GIA, GEGES virtual assistant. How can I help you?';

  @override
  String get errMustLoginChat => 'Please login first to check your queue.';

  @override
  String get noActiveBookings =>
      'You don\'t have any active bookings. Let\'s make a new one!';

  @override
  String activeBookingDesc(String date, String status, String shopId) {
    return 'Your active booking:\n📅 $date\n🔖 Status: $status\n📍 Barbershop ID: $shopId';
  }

  @override
  String get errCheckQueueFailed =>
      'Sorry, I failed to check your queue. Please try again later.';

  @override
  String get errNoStylesAvailable =>
      'Sorry, hair style data is currently unavailable.';

  @override
  String get popularServicesHeader => 'Here are some of our popular services:';

  @override
  String get errLoadRecommendationFailed => 'Failed to load recommendations.';

  @override
  String get branchInfo =>
      'We have many branches! Use \'My Location\' on the Home page to find the nearest one.';

  @override
  String get giaFallback =>
      'Sorry, I don\'t understand yet. Try keywords: \'my queue\', \'style recommendation\', or \'address\'.';

  @override
  String get giaTyping => 'GIA is typing...';

  @override
  String get chatMinutes => 'mins';

  @override
  String get seeDetail => 'See Detail';

  @override
  String get btnCheckMyQueue => 'Check my queue';

  @override
  String get btnHaircutRecommendation => 'Style recommendation';

  @override
  String get btnAskAddress => 'Ask for address';

  @override
  String get btnCreateNewBooking => 'New Booking';

  @override
  String get chatHint => 'Type a message...';

  @override
  String get stepService => 'Service';

  @override
  String get stepBarber => 'Barber';

  @override
  String get stepSchedule => 'Schedule';

  @override
  String get selectServiceTitle => 'Select Service';

  @override
  String get selectServiceSubtitle => 'You can select more than one service';

  @override
  String get whoCutsTitle => 'Who will cut?';

  @override
  String get barberChoiceSystem => 'System Choice (Fair & Fast)';

  @override
  String get barberChoiceSystemDesc =>
      'The system will find the best available barber for you.';

  @override
  String get barberChoiceFavorite => 'Pick Favorite Barber';

  @override
  String barberChoiceFavoriteDesc(String fee) {
    return 'Choose a specific barber you know (+ Rp $fee)';
  }

  @override
  String get specialistList => 'Specialist List';

  @override
  String get scheduleTitle => 'Set Schedule';

  @override
  String get pickDay => 'Pick Day';

  @override
  String get pickTime => 'Pick Time';

  @override
  String get shopHoliday => 'CLOSED';

  @override
  String get totalEst => 'Total Estimate';

  @override
  String get btnNext => 'NEXT';

  @override
  String get btnBookNow => 'BOOK NOW';

  @override
  String get confirmBookingTitle => 'Confirm Booking';

  @override
  String get labelDate => 'Date';

  @override
  String get labelTime => 'Time';

  @override
  String get labelBarber => 'Barber';

  @override
  String get labelTotalCost => 'Total Cost';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnConfirmBook => 'Book Now';

  @override
  String get errPickService => 'Select at least one service';

  @override
  String get errPickBarber => 'Please select your favorite barber';

  @override
  String get errPickBarberFirst => 'Select a barber first';

  @override
  String get errBarberBusy => 'The barber is already booked at this time';

  @override
  String get errNoFairBarber =>
      'No hairstylist available at this time. Try another slot.';

  @override
  String errShopClosed(String shopName) {
    return '$shopName is Closed';
  }

  @override
  String get errShopClosedDesc =>
      'Sorry, this barbershop is not accepting orders right now.\nPlease check back later.';

  @override
  String barberOffDay(String name) {
    return '$name is off on this date.';
  }

  @override
  String get barberOffDayDesc =>
      'Please choose another date or another barber.';

  @override
  String get randomSystem => 'Random System';

  @override
  String get myOrders => 'My Orders';

  @override
  String get tabUnpaid => 'Unpaid';

  @override
  String get tabScheduled => 'Scheduled';

  @override
  String get tabProcessing => 'Processing';

  @override
  String get tabCompleted => 'Completed';

  @override
  String get tabCancelled => 'Cancelled';

  @override
  String get loginRequired => 'Login required';

  @override
  String get noOrders => 'No orders yet';

  @override
  String get statusUnpaid => 'UNPAID';

  @override
  String get statusCancelled => 'CANCELLED';

  @override
  String get statusCancelRequested => 'CANCEL REQUESTED';

  @override
  String get statusCompleted => 'COMPLETED';

  @override
  String get statusProcessing => 'PROCESSING';

  @override
  String get statusScheduled => 'SCHEDULED';

  @override
  String get statusPendingVerification => 'PENDING VERIFICATION';

  @override
  String get specialOrders => 'Special Orders';

  @override
  String get pleaseLoginFirst => 'Please login first';

  @override
  String errLoadingOrders(String error) {
    return 'Error loading orders: $error';
  }

  @override
  String get noSpecialOrders => 'No Special Orders yet';

  @override
  String get statusAwaitingPayment => 'Waiting for Payment';

  @override
  String get descAwaitingPayment => 'Complete payment to process registration.';

  @override
  String get statusActivePartnership => 'SUCCESS / ACTIVE';

  @override
  String get descActivePartnership =>
      'Congratulations! Your partnership is now active.';

  @override
  String get statusCancelledRejected => 'CANCELLED / REJECTED';

  @override
  String get descCancelledRejected => 'This request cannot be processed.';

  @override
  String get statusWaitingVerification => 'WAITING VERIFICATION';

  @override
  String get descWaitingVerification =>
      'Proof received. Admin is verifying your data.';

  @override
  String get btnResumePayment => 'RESUME PAYMENT';

  @override
  String get registrationIncompleteTitle => 'Registration Incomplete';

  @override
  String get registrationIncompleteMsg =>
      'You haven\'t uploaded payment proof. Your registration is saved as \'Waiting for Payment\' and can be continued later.';

  @override
  String get btnCancelExit => 'Cancel Exit';

  @override
  String get btnExitSaveDraft => 'Exit (Save Draft)';

  @override
  String get btnCancelRegistration => 'Cancel Registration';

  @override
  String get registrationDetail => 'Registration Detail';

  @override
  String get cancelRegistrationTitle => 'Cancel Registration?';

  @override
  String get cancelRegistrationWarning =>
      'If you cancel a registration that is ALREADY PAID, the funds will be returned with a 10% DEDUCTION (admin fee).\n\nAre you sure?';

  @override
  String get btnBack => 'Back';

  @override
  String get btnYesCancel => 'Yes, Cancel';

  @override
  String get msgCancelSent => 'Cancellation request sent.';

  @override
  String errCancelFailed(String error) {
    return 'Failed to cancel: $error';
  }

  @override
  String get errOpenWhatsApp => 'Failed to open WhatsApp support';

  @override
  String get statusActiveCompleted => 'ACTIVE / COMPLETED';

  @override
  String get statusRefundProcessing => 'REFUND PROCESSING';

  @override
  String get businessInfo => 'Business Information';

  @override
  String get barbershopName => 'Barbershop Name';

  @override
  String get subscriptionPlan => 'Subscription Plan';

  @override
  String get registrationFee => 'Registration Fee';

  @override
  String get address => 'Address';

  @override
  String get adminAccountTitle => 'Barbershop Admin Account';

  @override
  String get adminAccountDesc => 'Use this account to log in to the Admin App:';

  @override
  String get btnLogoutLoginAdmin => 'LOGOUT & LOGIN AS ADMIN';

  @override
  String get contactAdmin => 'Contact Admin';

  @override
  String get loginAsAdminTitle => 'Login as Admin?';

  @override
  String get loginAsAdminMsg =>
      'You will be logged out of this Customer account.\n\nPlease use the Email & Password listed above to log back in as a Barbershop Owner.';

  @override
  String get btnYesLogout => 'Yes, Logout';

  @override
  String get cancelDetail => 'Cancellation Detail';

  @override
  String get reason => 'Reason';

  @override
  String get viewRefundProof => 'View Refund Proof';

  @override
  String get btnPayNow => 'PAY NOW';

  @override
  String get contactSupport => 'Contact Help / Complaint';
}
