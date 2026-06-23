# SkillGhor Freelancer Mode - Implementation Guide

## Overview
This guide outlines the freelancer-side screens that mirror the client functionality, enabling freelancers to manage proposals, active contracts, and messaging.

---

## Freelancer Features to Implement

### 1. **Freelancer Home Screen** (Mirror: `client_home_screen.dart`)
**File**: `lib/screens/freelancer_home_screen.dart`

**Features:**
- Welcome card with profile info & verification badge
- Profile completion percentage
- Quick stats:
  - Total Connects: (from user doc)
  - Earnings: (totalEarnings)
  - Hired Count: (active contracts)
- Quick Actions:
  - Browse Jobs
  - My Proposals
  - Active Contracts
  - Messages
- Bottom Navigation (5 tabs): Home, Browse, Proposals, Contracts, Messages, Profile

**Structure:**
```dart
class FreelancerHomeScreen extends StatefulWidget {
  // Identical structure to ClientHomeScreen
  // _currentIndex for tab navigation
  // final screens = [homeScreen, browseScreen, proposalsScreen, contractsScreen, messagesScreen, profileScreen]
}
```

---

### 2. **Browse Jobs Screen** (New)
**File**: `lib/screens/browse_jobs_screen.dart`

**Features:**
- Stream all jobs with `status: 'open'`
- Search by title & skills
- Filter chips: ALL, BY SKILLS, RECENT, HIGH BUDGET
- Job cards showing:
  - Title, budget, required skills
  - Posted date
  - Client name & rating
  - Applied status indicator
- Tap job → JobDetailScreen

**Queries:**
```dart
// All open jobs
FirebaseFirestore.instance
  .collection('jobs')
  .where('status', isEqualTo: 'open')
  .orderBy('createdAt', descending: true)
  .snapshots()

// Filter by freelancer skills (requires skills array in jobs)
// Advanced: Cloud function to populate job.matchedSkills
```

---

### 3. **My Proposals Screen** (Mirror: `my_jobs_screen.dart`)
**File**: `lib/screens/my_proposals_screen.dart`

**Features:**
- Stream proposals by `freelancerId`
- Filter chips: ALL, PENDING, APPROVED, REJECTED
- Proposal cards showing:
  - Job title (fetch from jobs)
  - Budget & boost connects spent
  - Status badge (pending/approved/rejected)
  - Submitted date
- PopupMenu for actions:
  - View Job Details
  - View Full Proposal
  - Withdraw Proposal (if pending)
- Approved proposals show "Contract Active" indicator

**Query:**
```dart
// Get all proposals by freelancer across all jobs
// This requires cross-collection query (complex)
// Solution: Index proposals by freelancerId in separate sub-collection

// OR: Use batch read to get jobs first, then proposals
final jobs = await FirebaseFirestore.instance
  .collection('jobs')
  .snapshots();
  
for (final job in jobs.docs) {
  final proposals = await job.reference
    .collection('proposals')
    .where(FieldPath.documentId, isEqualTo: freelancerId)
    .get();
}
```

---

### 4. **Active Contracts Screen** (Mirror: `hired_freelancers_screen.dart`)
**File**: `lib/screens/freelancer_active_contracts_screen.dart`

**Features:**
- Stream contracts where `freelancerId == uid && status: 'active'`
- Contract cards showing:
  - Client name & avatar
  - Job title
  - Contract creation date
  - Completion date (if set)
- Action buttons:
  - **Message**: 1v1 chat with client
  - **Submit Work**: Upload deliverables (future)
  - **Mark Complete**: Sets contract status to "completed"

**Query:**
```dart
FirebaseFirestore.instance
  .collection('contracts')
  .where('freelancerId', isEqualTo: uid)
  .where('status', isEqualTo: 'active')
  .snapshots()
```

---

### 5. **Job Detail Screen** (New)
**File**: `lib/screens/job_detail_screen.dart`

**Features:**
- Full job information:
  - Title, description, budget, deadline
  - Required skills
  - Client name & profile link
  - Posted date & proposal count
- Apply button → ApplyJobScreen (already exists)
- Message client button → ChatRoomScreen
- View proposals button (if already applied)

**Passed Data:**
```dart
JobDetailScreen(jobId: 'job123')
```

---

### 6. **Freelancer Profile Screen** (Mirror: `client_profile_screen.dart`)
**File**: `lib/screens/freelancer_profile_screen.dart`

**Features:**
- Display freelancer profile:
  - Name, email, username
  - Bio (up to 500 chars)
  - Skills list (tags)
  - Location & hourly rate
  - Portfolio URLs
  - Verification badge
  - Rating (if reviews implemented)
- Edit Profile button → FreelancerEditProfileScreen
- View Reviews button (future)

---

### 7. **Edit Profile Screen** (Mirror: `client_edit_profile_screen.dart`)
**File**: `lib/screens/freelancer_edit_profile_screen.dart`

**Features:**
- Edit all profile fields:
  - Name, username, bio
  - Skills (multi-select or tag input)
  - Location, hourly rate
  - Portfolio URLs (list)
  - Profile image upload
- Save button updates `users/{uid}`

---

### 8. **Messages Screen** (Already implemented)
**File**: `lib/screens/messages_screen.dart`
- Reusable for both client & freelancer
- Lists conversations with clients/freelancers
- Tap to open ChatRoomScreen

---

## Firestore Queries & Indexes

### Composite Indexes Needed

1. **Browse Jobs by Skills**
   ```
   Collection: jobs
   Fields: status (Asc), requiredSkills (Asc), createdAt (Desc)
   ```

2. **Proposals by Freelancer** (requires restructuring)
   ```
   Collection: proposals (top-level, not nested)
   Fields: freelancerId (Asc), status (Asc), submittedAt (Desc)
   ```

3. **Active Contracts**
   ```
   Collection: contracts
   Fields: freelancerId (Asc), status (Asc), createdAt (Desc)
   ```

---

## Updated Firestore Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users - read own, write own
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
      allow read: if request.auth != null; // for viewing profiles
    }

    // Jobs - anyone reads, client creates
    match /jobs/{jobId} {
      allow create: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'client';
      allow read: if request.auth != null;
      allow update: if resource.data.clientId == request.auth.uid;
      allow delete: if resource.data.clientId == request.auth.uid;

      // Proposals - freelancer creates
      match /proposals/{freelancerId} {
        allow create: if request.auth.uid == freelancerId;
        allow read: if request.auth != null;
        allow update: if get(/databases/$(database)/documents/jobs/$(jobId)).data.clientId == request.auth.uid ||
                         request.auth.uid == freelancerId;
      }
    }

    // Contracts - client/freelancer access
    match /contracts/{contractId} {
      allow create: if request.auth.uid == request.resource.data.clientId;
      allow read: if request.auth.uid == resource.data.clientId || request.auth.uid == resource.data.freelancerId;
      allow update: if request.auth.uid == resource.data.clientId || request.auth.uid == resource.data.freelancerId;
    }

    // Chat Rooms - participants only
    match /chat_rooms/{roomId} {
      allow read, write: if request.auth.uid in resource.data.participants;

      match /messages/{msgId} {
        allow read, write: if request.auth.uid in get(/databases/$(database)/documents/chat_rooms/$(roomId)).data.participants;
      }
    }

    // User Chats - user's own rooms
    match /user_chats/{uid}/rooms/{roomId} {
      allow read, write: if request.auth.uid == uid;
    }
  }
}
```

---

## Implementation Roadmap

### Phase 1: Basic Freelancer Screens (Core)
1. [ ] Freelancer Home Screen (bottom nav hub)
2. [ ] Browse Jobs Screen (search & filter)
3. [ ] Job Detail Screen (full info)
4. [ ] My Proposals Screen (pending/approved/rejected)
5. [ ] Freelancer Profile Screen (display)
6. [ ] Freelancer Edit Profile Screen (edit)
7. [ ] Active Contracts Screen (hired jobs)

### Phase 2: Enhanced Features (Advanced)
8. [ ] Work Submission (upload deliverables)
9. [ ] Reviews & Ratings (view/add reviews)
10. [ ] Connect Management (purchase connects for job search)
11. [ ] Proposals Statistics (charts, analytics)
12. [ ] Portfolio Management (manage portfolio links)

### Phase 3: Integration & Polish
13. [ ] Firestore rules refinement
14. [ ] Error handling & offline support
15. [ ] Performance optimization (pagination)
16. [ ] Analytics integration

---

## Data Flow Diagram

```
┌────────────────────────────────────────────┐
│  FREELANCER HOME SCREEN                    │
│  - Welcome Card                            │
│  - Quick Stats (Connects, Earnings)        │
│  - Quick Actions                           │
└────┬──────────────┬──────────────┬─────────┘
     │              │              │
     ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ BROWSE JOBS  │ │ MY PROPOSALS │ │  CONTRACTS   │
│ - List Jobs  │ │ - List Props │ │ - List Hired │
│ - Filter     │ │ - Filters    │ │ - Message    │
│ - View Detal │ │ - Withdraw   │ │ - Complete   │
└──────┬───────┘ └──────────────┘ └──────────────┘
       │
       ▼
┌──────────────────┐
│ JOB DETAIL       │
│ - Full Info      │
│ - Apply          │
│ - Message Client │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ APPLY JOB        │
│ - Proposal Form  │
│ - Boost Connects │
│ - Submit         │
└──────────────────┘
         │
         ▼
┌──────────────────┐
│ CHAT ROOM        │
│ - 1v1 Messages   │
│ - With Client    │
└──────────────────┘

         ┌──────────────────┐
         │  MESSAGES        │
         │ - Conversations  │
         │ - Open Chat      │
         └──────────────────┘

         ┌──────────────────┐
         │  PROFILE         │
         │ - Display Info   │
         │ - Edit Profile   │
         └──────────────────┘
```

---

## Code Examples

### Browse Jobs Screen Template

```dart
// lib/screens/browse_jobs_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'job_detail_screen.dart';

class BrowseJobsScreen extends StatefulWidget {
  const BrowseJobsScreen({super.key});

  @override
  State<BrowseJobsScreen> createState() => _BrowseJobsScreenState();
}

class _BrowseJobsScreenState extends State<BrowseJobsScreen> {
  String _filterStatus = 'all'; // all, recent, highBudget, bySkills
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Jobs'),
        backgroundColor: Colors.green.shade600,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search jobs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: ['all', 'recent', 'highBudget', 'bySkills']
                  .map((f) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(f.toUpperCase()),
                      selected: _filterStatus == f,
                      onSelected: (v) => setState(() => _filterStatus = f),
                    ),
                  ))
                  .toList(),
            ),
          ),
          // Jobs List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('jobs')
                  .where('status', isEqualTo: 'open')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final jobs = snapshot.data!.docs
                    .where((j) => (j['title'] as String)
                        .toLowerCase()
                        .contains(_searchController.text.toLowerCase()))
                    .toList();

                if (jobs.isEmpty) {
                  return const Center(child: Text('No jobs found'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final job = jobs[i];
                    final data = job.data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(data['title'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('৳${data['budget']}'),
                            Text(
                              (data['requiredSkills'] as List?)?.join(', ') ?? 'Any skills',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobDetailScreen(jobId: job.id),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

### Job Detail Screen Template

```dart
// lib/screens/job_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'apply_job_screen.dart';
import 'chat_room_screen.dart';

class JobDetailScreen extends StatelessWidget {
  final String jobId;
  const JobDetailScreen({required this.jobId, super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('jobs').doc(jobId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final job = snapshot.data!.data() as Map<String, dynamic>;
        final clientId = job['clientId'] as String;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Job Details'),
            backgroundColor: Colors.green.shade600,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job['title'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Budget: ৳${job['budget']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Text(job['description'] ?? '', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                const Text('Required Skills:', style: TextStyle(fontWeight: FontWeight.w600)),
                Wrap(
                  children: (job['requiredSkills'] as List? ?? [])
                      .map((s) => Chip(label: Text(s)))
                      .toList(),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ApplyJobScreen(jobId: jobId),
                          ),
                        ),
                        icon: const Icon(Icons.send),
                        label: const Text('Apply Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('users').doc(clientId).get(),
                              builder: (_, snap) {
                                final clientName = (snap.data?.data() as Map?)?.['name'] ?? 'Client';
                                return ChatRoomScreen(
                                  otherUserId: clientId,
                                  otherUserName: clientName,
                                  jobId: jobId,
                                );
                              },
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.message),
                        label: const Text('Message'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

---

## Testing Checklist

### ✅ Freelancer Browsing
- [ ] Browse Jobs screen shows all open jobs
- [ ] Search filters jobs by title
- [ ] Filter chips work (all/recent/highBudget/bySkills)
- [ ] Job Detail screen shows complete info
- [ ] Apply button works

### ✅ Freelancer Proposals
- [ ] My Proposals screen lists freelancer's proposals
- [ ] Filter chips show pending/approved/rejected
- [ ] Withdraw proposal option works
- [ ] Approved proposals show contract indicator

### ✅ Freelancer Contracts
- [ ] Active Contracts screen lists hired jobs
- [ ] Message button opens correct chat with client
- [ ] Mark Complete button updates contract status
- [ ] Completed contracts no longer appear in active list

### ✅ Freelancer Profile
- [ ] Profile screen displays all info
- [ ] Edit profile button navigates correctly
- [ ] Profile updates save to Firestore

---

## Next Steps

1. **Create** `freelancer_home_screen.dart` using bottom navigation pattern from `client_home_screen.dart`
2. **Create** `browse_jobs_screen.dart` with search and filters
3. **Create** `job_detail_screen.dart` with full job information
4. **Create** `my_proposals_screen.dart` to list freelancer's proposals
5. **Create** `freelancer_profile_screen.dart` (mirror of `client_profile_screen.dart`)
6. **Create** `freelancer_edit_profile_screen.dart` (mirror of `client_edit_profile_screen.dart`)
7. **Create** `freelancer_active_contracts_screen.dart` (mirror of `hired_freelancers_screen.dart`)
8. **Update** `main.dart` to navigate to `FreelancerHomeScreen` when role == 'freelancer'
9. **Implement** Firestore composite indexes
10. **Test** complete freelancer workflow end-to-end

---

**Status**: ✅ Design Complete | ⏳ Implementation Pending
