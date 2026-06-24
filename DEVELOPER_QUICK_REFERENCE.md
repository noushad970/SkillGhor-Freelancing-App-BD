# SkillGhor - Developer Quick Reference

**Purpose**: Quick lookup guide for implementing features, fixing bugs, and understanding the codebase.

---

## 1. QUICK NAVIGATION

### Find a Screen
```
User wants to: _________ 
→ Look in: lib/screens/FEATURE_screen.dart

Job management        → my_jobs_screen.dart, post_job_screen.dart
Proposals             → my_proposals_screen.dart, apply_job_screen.dart
Chat                  → messages_screen.dart, advanced_chat_screen.dart
Payments              → invoices_payments_screen.dart, wallet_screen.dart
Notifications         → notifications_screen.dart
Reviews               → review_screen.dart
Profile               → *_profile_screen.dart, *_edit_profile_screen.dart
Auth                  → sign_in_screen.dart, onboarding_screen.dart
```

### Find a Service
```
Need to: _________
→ Look in: lib/services/SERVICE_service.dart

Manage users           → auth_service.dart
Handle payments        → payment_service.dart
Send notifications     → notification_service.dart
Manage jobs            → job_service.dart
Handle proposals       → proposal_service.dart
```

---

## 2. COMMON TASKS

### Task: Add a New Screen
1. Create file: `lib/screens/my_new_screen.dart`
2. Import required packages:
   ```dart
   import 'package:flutter/material.dart';
   import 'package:cloud_firestore/cloud_firestore.dart';
   import 'package:firebase_auth/firebase_auth.dart';
   ```
3. Create StatelessWidget or StatefulWidget
4. Implement build() method
5. Add to navigation in home_screen.dart or bottom nav

### Task: Connect to Firestore
```dart
// Read a document
final doc = await FirebaseFirestore.instance
    .collection('COLLECTION_NAME')
    .doc(docId)
    .get();
final data = doc.data() ?? <String, dynamic>{};

// Write a document
await FirebaseFirestore.instance
    .collection('COLLECTION_NAME')
    .doc(docId)
    .set(data);

// Stream real-time updates
FirebaseFirestore.instance
    .collection('COLLECTION_NAME')
    .where('field', isEqualTo: value)
    .snapshots()
    .listen((snapshot) {
      // Handle updates
    });
```

### Task: Add Error Handling
```dart
try {
  // Risky operation
  await paymentService.processPayment(...);
  
  // Success feedback
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Success!')),
  );
} catch (e) {
  // Error feedback
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

### Task: Add Loading State
```dart
// Show loading dialog
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (_) => const Center(
    child: CircularProgressIndicator(),
  ),
);

// Hide loading dialog
Navigator.of(context).pop();
```

### Task: Stream Data in UI
```dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('items')
      .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return const Center(child: Text('No data'));
    }
    
    final items = snapshot.data!.docs;
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final data = items[index].data() as Map<String, dynamic>;
        return ListTile(title: Text(data['name'] ?? ''));
      },
    );
  },
)
```

---

## 3. COMMON ISSUES & FIXES

### Issue: Permission Denied
```dart
// Check Firestore security rules
// Solution: Ensure userId matches request.auth.uid in rules
// Or: Grant broader read/write permissions for development

// Example fix in rules:
match /items/{itemId} {
  allow read, write: if request.auth.uid == request.resource.data.userId;
}
```

### Issue: Null Safety Error
```dart
// ❌ Wrong: Can be null
final name = data['name'];
Text(name)  // Error!

// ✅ Correct: Provide default
final name = data['name'] ?? 'Unknown';
Text(name)  // OK
```

### Issue: Context After Dispose
```dart
// ❌ Wrong: Context might be disposed
await someAsyncOp();
ScaffoldMessenger.of(context).showSnackBar(...);  // Error if disposed

// ✅ Correct: Check mounted
await someAsyncOp();
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(...);  // Safe
```

### Issue: Memory Leak from Streams
```dart
// ❌ Wrong: Stream never cancelled
StreamSubscription sub = stream.listen(...);
// No cleanup

// ✅ Correct: Cancel in dispose
StreamSubscription? sub;
@override
void initState() {
  sub = stream.listen(...);
}
@override
void dispose() {
  sub?.cancel();
  super.dispose();
}
```

### Issue: Firestore Index Required
```
Error: "FAILED_PRECONDITION: The query requires an index"

Solution:
1. Go to Firebase Console → Firestore → Indexes
2. Click link in error to create index
3. Wait for index to build (1-2 minutes)
4. Retry query
```

---

## 4. FIELD PARSING PATTERNS

### Parse Status (Can be Int or String)
```dart
final status = data['status'];
int statusIdx;

if (status is int) {
  statusIdx = status;
} else if (status is String) {
  statusIdx = int.tryParse(status) ?? 0;
} else {
  statusIdx = 0;  // Default
}

// Use statusIdx with enum
final myStatus = JobStatus.values[statusIdx.clamp(0, 3)];
```

### Parse Amount (Can be Double, Int, or String)
```dart
final rawAmount = data['amount'];
final amount = (rawAmount is num)
    ? rawAmount.toDouble()
    : double.tryParse(rawAmount.toString()) ?? 0.0;
```

### Parse List (Safe)
```dart
// Safe list parsing
final skills = (data['skills'] as List<dynamic>? ?? [])
    .cast<String>();

// Safe map list parsing
final education = (data['education'] as List<dynamic>? ?? [])
    .cast<Map<String, dynamic>>();
```

---

## 5. DATABASE OPERATIONS REFERENCE

### Create/Update User
```dart
await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .set({
  'name': 'John Doe',
  'email': 'john@example.com',
  'role': 'freelancer',
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));  // merge: true = update fields only
```

### Update Nested Field
```dart
await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .update({
  'profile.name': 'John',  // Nested field
  'skills': FieldValue.arrayUnion(['React', 'Node.js']),  // Add to array
});
```

### Delete Document
```dart
await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .delete();
```

### Query with Conditions
```dart
final snapshot = await FirebaseFirestore.instance
    .collection('jobs')
    .where('clientId', isEqualTo: clientId)
    .where('status', isEqualTo: 0)  // 0 = open
    .orderBy('createdAt', descending: true)
    .limit(10)
    .get();
```

### Batch Write (Atomic)
```dart
final batch = FirebaseFirestore.instance.batch();

// Add multiple operations
batch.set(FirebaseFirestore.instance.collection('jobs').doc(jobId), jobData);
batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {'activeJobs': FieldValue.increment(1)});
batch.delete(FirebaseFirestore.instance.collection('temp').doc(tempId));

// Commit all at once
await batch.commit();
```

### Transaction (Atomic with Read)
```dart
final result = await FirebaseFirestore.instance.runTransaction((transaction) async {
  final docRef = FirebaseFirestore.instance.collection('wallets').doc(uid);
  final snapshot = await transaction.get(docRef);
  final balance = snapshot.data()?['balance'] ?? 0;
  
  if (balance >= amount) {
    transaction.update(docRef, {'balance': balance - amount});
    return true;
  }
  return false;
});
```

---

## 6. AUTHENTICATION PATTERNS

### Get Current User
```dart
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  // Not authenticated
  return SignInScreen();
}
final uid = user.uid;
```

### Check Role from AuthService
```dart
final authService = Provider.of<AuthService>(context, listen: false);
final role = authService.currentUser?.role;

if (role == 'client') {
  // Show client UI
} else if (role == 'freelancer') {
  // Show freelancer UI
}
```

### Guard Async Operations
```dart
Future<void> deleteJob(String jobId) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    throw Exception('User not authenticated');
  }
  
  // Verify ownership before deleting
  final job = await FirebaseFirestore.instance
      .collection('jobs')
      .doc(jobId)
      .get();
  
  if (job.data()?['clientId'] != uid) {
    throw Exception('Not authorized');
  }
  
  await job.reference.delete();
}
```

---

## 7. NAVIGATION PATTERNS

### Push New Screen
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => JobDetailsScreen(jobId: jobId),
  ),
);
```

### Replace Current Screen (No back button)
```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => HomeScreen(),
  ),
);
```

### Pop Back
```dart
Navigator.pop(context);
```

### Nested Navigator (Keep bottom nav visible)
```dart
// In main.dart
home: const AuthGate(),
routes: {
  '/home': (_) => const HomeScreen(),
  '/job': (context) {
    final jobId = ModalRoute.of(context)!.settings.arguments as String;
    return JobDetailsScreen(jobId: jobId);
  },
},
```

---

## 8. PROVIDER STATE MANAGEMENT

### Create Provider
```dart
class AuthService extends ChangeNotifier {
  String? _role;
  
  String? get role => _role;
  
  Future<void> setRole(String role) async {
    _role = role;
    notifyListeners();  // Notify all listeners
  }
}
```

### Use Provider in Screen
```dart
final authService = Provider.of<AuthService>(context);
final role = authService.role;

// Or with listen: false (one-time read)
final authService = Provider.of<AuthService>(context, listen: false);
```

### Consumer Widget (Auto-rebuild)
```dart
Consumer<AuthService>(
  builder: (context, authService, child) {
    return Text('Role: ${authService.role}');
    // Rebuilds whenever authService notifyListeners() called
  },
)
```

---

## 9. WIDGET BEST PRACTICES

### Always use const
```dart
// ✅ Good: Const widgets (no rebuild)
const SizedBox(height: 16)
const Text('Hello')

// ❌ Bad: Non-const (rebuilds)
SizedBox(height: 16)
Text('Hello')
```

### Use ListView.builder for Long Lists
```dart
// ❌ Bad: Builds all items (memory issue)
ListView(
  children: List.generate(1000, (i) => ItemWidget(i)),
)

// ✅ Good: Builds visible items only
ListView.builder(
  itemCount: 1000,
  itemBuilder: (context, index) => ItemWidget(index),
)
```

### Proper Disposal
```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late TextEditingController controller;
  StreamSubscription? sub;
  
  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    sub = someStream.listen(...);
  }
  
  @override
  void dispose() {
    controller.dispose();
    sub?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) => ...;
}
```

---

## 10. TESTING CHECKLIST

Before committing code:
- [ ] All screens compile without errors
- [ ] App launches without crashes
- [ ] Navigation works (all buttons lead to correct screens)
- [ ] Database reads work (data loads)
- [ ] Database writes work (changes saved to Firestore)
- [ ] Error handling works (shows user-friendly messages)
- [ ] Loading states show (spinners appear)
- [ ] No unused imports
- [ ] No null safety errors
- [ ] No console warnings

---

## 11. FILE LOCATIONS QUICK REF

```
Project Root/
├── lib/
│   ├── main.dart                    ← App entry point
│   ├── firebase_options.dart        ← Firebase config
│   ├── services/
│   │   ├── auth_service.dart       ← Authentication
│   │   ├── payment_service.dart    ← Payments
│   │   ├── notification_service.dart ← Notifications
│   │   ├── job_service.dart        ← Jobs
│   │   ├── proposal_service.dart   ← Proposals
│   │   └── models/
│   │       └── user_model.dart     ← Data classes
│   ├── screens/
│   │   ├── home_screen.dart        ← Main navigator
│   │   ├── sign_in_screen.dart     ← Login
│   │   ├── role_selection_screen.dart ← Role picker
│   │   ├── onboarding_screen.dart  ← Profile setup
│   │   ├── client_home_screen.dart ← Client dashboard
│   │   ├── freelancer_home_screen.dart ← Freelancer dashboard
│   │   ├── post_job_screen.dart    ← Create job
│   │   ├── my_jobs_screen.dart     ← List jobs
│   │   ├── applicant_list_screen.dart ← Review proposals
│   │   ├── hired_freelancers_screen.dart ← Active contracts
│   │   ├── messages_screen.dart    ← Chat list
│   │   ├── advanced_chat_screen.dart ← 1v1 chat
│   │   ├── notifications_screen.dart ← Notifications
│   │   ├── invoices_payments_screen.dart ← Payments
│   │   ├── review_screen.dart      ← Submit review
│   │   ├── wallet_screen.dart      ← Wallet
│   │   ├── *_profile_screen.dart   ← Profile
│   │   └── ... (30+ more screens)
│   └── models/
│       └── user_model.dart         ← AppUser class
├── android/                         ← Android native code
├── ios/                             ← iOS native code
├── web/                             ← Web files
├── pubspec.yaml                     ← Dependencies
└── README.md                        ← Project docs
```

---

## 12. USEFUL COMMANDS

```bash
# Run app
flutter run

# Run on specific device
flutter run -d chrome          # Web
flutter run -d android         # Android emulator
flutter run -d iphone          # iOS simulator

# Build app
flutter build apk              # Android
flutter build ios              # iOS
flutter build web              # Web

# Check code issues
flutter analyze                # Check for errors
flutter pub get                # Install dependencies
flutter clean                  # Clean build

# Format code
flutter format lib             # Format Dart files
```

---

## 13. DEBUGGING TIPS

### Print Debugging
```dart
print('Value: $value');
debugPrint('Debug message');  // Better for long messages
```

### Check Firestore Data
1. Go to Firebase Console
2. Select project
3. Go to Firestore Database
4. Browse collections and documents

### Check Auth Status
```dart
final user = FirebaseAuth.instance.currentUser;
print('Logged in: ${user?.uid}');
```

### Monitor Network Requests
```dart
// In Chrome DevTools (web)
F12 → Network tab → Look for Firestore calls
```

### Hot Reload vs Hot Restart
```bash
r       # Hot reload (faster, preserves state)
R       # Hot restart (slower, clears state)
q       # Quit app
```

---

**Last Updated**: June 24, 2026
**For**: SkillGhor Freelancing Platform
