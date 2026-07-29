// lib/screens/client_home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'sign_in_screen.dart';
import 'client_edit_profile_screen.dart';
import 'post_job_screen.dart';
import 'notifications_screen.dart';
import 'messages_screen.dart';
import 'my_jobs_screen.dart';
import 'hired_freelancers_screen.dart';
import 'client_profile_screen.dart';
import 'invoices_payments_screen.dart';
import '../services/payment_service.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    final screens = [
      _buildHomeScreen(context, user),
      const MyJobsScreen(),
      const HiredFreelancersScreen(),
      const MessagesScreen(),
      const ClientProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Skill Ghor',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('jobs')
                .where('clientId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData) {
                for (final job in snapshot.data!.docs) {
                  unreadCount += (job['proposalsCount'] ?? 0) as int;
                }
              }
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 11,
                      top: 11,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          CircleAvatar(
            backgroundImage: user.photoURL != null
                ? NetworkImage(user.photoURL!)
                : null,
            child: user.photoURL == null ? const Icon(Icons.person) : null,
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  await Provider.of<AuthService>(
                    context,
                    listen: false,
                  ).signOut();
                } catch (_) {}
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green.shade600,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'My Jobs'),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Freelancers',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (idx) => setState(() => _currentIndex = idx),
      ),
    );
  }

  Widget _buildHomeScreen(BuildContext context, User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = data['name'] ?? user.displayName ?? 'Client';
        final company = data['companyName'] ?? 'Your Company';
        final isVerified = data['isVerified'] == true;
        final walletBalance = (data['walletBalance'] ?? data['wallet'] ?? 0);

        // Dynamic Profile Completion for Client
        int completed = 0;
        if ((data['name'] as String?)?.isNotEmpty ?? false) completed++;
        if ((data['username'] as String?)?.isNotEmpty ?? false) completed++;
        if (data['country'] != null) completed++;
        if ((data['companyName'] as String?)?.isNotEmpty ?? false) {
          completed++;
        }
        if (((data['bio'] as String?)?.length ?? 0) >= 100) completed++;

        final profileCompletion = (completed / 5 * 100).round();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // WELCOME CARD
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: user.photoURL != null
                                ? NetworkImage(user.photoURL!)
                                : null,
                            child: user.photoURL == null
                                ? const Icon(Icons.business, size: 40)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isVerified
                                          ? Icons.verified
                                          : Icons.verified_user_outlined,
                                      color: isVerified
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                  ],
                                ),
                                Text(
                                  company,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Wallet: ৳${(walletBalance is num ? walletBalance.toDouble() : double.tryParse(walletBalance.toString()) ?? 0).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: profileCompletion / 100,
                                        backgroundColor: Colors.grey[300],
                                        valueColor: AlwaysStoppedAnimation(
                                          profileCompletion >= 90
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$profileCompletion% Complete',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ClientEditProfileScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Profile'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Enhanced Top-up / Buy Connects button -> show modal bottom sheet
                          OutlinedButton.icon(
                            onPressed: () {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                builder: (ctx) {
                                  return StatefulBuilder(
                                    builder: (ctx, setState) {
                                      final amountController =
                                          TextEditingController();
                                      String mode =
                                          'topup'; // 'topup' or 'connects'
                                      double quickAmount = 500;
                                      String paymentMethod =
                                          'wallet'; // wallet/card/bank
                                      double exchangeRate =
                                          110; // BDT per USD (example)
                                      int connects = 10;
                                      const double pricePerConnectUSD = 0.5;

                                      double parsedAmount() {
                                        final c = amountController.text.trim();
                                        final v = double.tryParse(c);
                                        return v ?? quickAmount;
                                      }

                                      final usdForConnects =
                                          connects * pricePerConnectUSD;
                                      final localForConnects =
                                          usdForConnects * exchangeRate;

                                      Future<void> doTopUp(double amt) async {
                                        Navigator.of(ctx).pop();
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (_) => const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                        try {
                                          await PaymentService().topUpBalance(
                                            amount: amt,
                                          );
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Wallet topped up'),
                                            ),
                                          );
                                        } catch (e) {
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Top-up failed: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }

                                      Future<void> buyConnectsTx(
                                        int connectsToBuy,
                                        double totalLocal,
                                      ) async {
                                        // Run a transaction: verify user's walletBalance and deduct then increment totalConnects
                                        final uid = FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.uid;
                                        if (uid == null) return;
                                        Navigator.of(ctx).pop();
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (_) => const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                        final userRef = FirebaseFirestore
                                            .instance
                                            .collection('users')
                                            .doc(uid);
                                        final walletRef = FirebaseFirestore
                                            .instance
                                            .collection('wallets')
                                            .doc(uid);
                                        final paymentRef = FirebaseFirestore
                                            .instance
                                            .collection('payments')
                                            .doc();
                                        try {
                                          await FirebaseFirestore.instance.runTransaction((
                                            tx,
                                          ) async {
                                            final snap = await tx.get(userRef);
                                            final currentBalance =
                                                (snap.data()?['walletBalance'] ??
                                                        snap.data()?['wallet'] ??
                                                        0)
                                                    as num;
                                            final balance = currentBalance
                                                .toDouble();
                                            if (balance < totalLocal) {
                                              throw Exception(
                                                'Insufficient wallet balance.',
                                              );
                                            }

                                            // deduct wallet convenience field
                                            tx.update(userRef, {
                                              'walletBalance':
                                                  FieldValue.increment(
                                                    -totalLocal,
                                                  ),
                                              'totalConnects':
                                                  FieldValue.increment(
                                                    connectsToBuy,
                                                  ),
                                            });

                                            // update wallet doc too
                                            tx.set(walletRef, {
                                              'balance': FieldValue.increment(
                                                -totalLocal,
                                              ),
                                              'lastUpdated':
                                                  FieldValue.serverTimestamp(),
                                            }, SetOptions(merge: true));

                                            // create a payment record for connects purchase
                                            tx.set(paymentRef, {
                                              'userId': uid,
                                              'amount': totalLocal,
                                              'method': paymentMethod,
                                              'status': 'completed',
                                              'type': 'connectsPurchase',
                                              'connects': connectsToBuy,
                                              'createdAt':
                                                  FieldValue.serverTimestamp(),
                                            });
                                          });

                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Connects purchased successfully',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          Navigator.of(context).pop();
                                          final err = e is Exception
                                              ? e.toString()
                                              : 'Purchase failed';
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text(err)),
                                          );
                                        }
                                      }

                                      return Padding(
                                        padding: EdgeInsets.only(
                                          bottom: MediaQuery.of(
                                            ctx,
                                          ).viewInsets.bottom,
                                        ),
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Text(
                                                    'Wallet / Connects',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.close,
                                                    ),
                                                    onPressed: () =>
                                                        Navigator.of(ctx).pop(),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),

                                              // Mode toggle
                                              Row(
                                                children: [
                                                  ChoiceChip(
                                                    label: const Text(
                                                      'Top-up Wallet',
                                                    ),
                                                    selected: mode == 'topup',
                                                    onSelected: (v) => setState(
                                                      () => mode = 'topup',
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ChoiceChip(
                                                    label: const Text(
                                                      'Buy Connects',
                                                    ),
                                                    selected:
                                                        mode == 'connects',
                                                    onSelected: (v) => setState(
                                                      () => mode = 'connects',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),

                                              if (mode == 'topup') ...[
                                                const Text('Quick amounts'),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    for (final a in [
                                                      500.0,
                                                      1000.0,
                                                      2000.0,
                                                    ])
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 8.0,
                                                            ),
                                                        child: ElevatedButton(
                                                          onPressed: () {
                                                            amountController
                                                                .text = a
                                                                .toStringAsFixed(
                                                                  0,
                                                                );
                                                            setState(() {});
                                                          },
                                                          style:
                                                              ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    Colors
                                                                        .green
                                                                        .shade600,
                                                              ),
                                                          child: Text(
                                                            '৳${a.toStringAsFixed(0)}',
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                TextField(
                                                  controller: amountController,
                                                  keyboardType:
                                                      const TextInputType.numberWithOptions(
                                                        decimal: true,
                                                      ),
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText:
                                                            'Custom amount (BDT)',
                                                      ),
                                                ),
                                                const SizedBox(height: 12),
                                                const Text('Payment method'),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    ChoiceChip(
                                                      label: const Text(
                                                        'Wallet',
                                                      ),
                                                      selected:
                                                          paymentMethod ==
                                                          'wallet',
                                                      onSelected: (_) =>
                                                          setState(
                                                            () =>
                                                                paymentMethod =
                                                                    'wallet',
                                                          ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ChoiceChip(
                                                      label: const Text('Card'),
                                                      selected:
                                                          paymentMethod ==
                                                          'card',
                                                      onSelected: (_) =>
                                                          setState(
                                                            () =>
                                                                paymentMethod =
                                                                    'card',
                                                          ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ChoiceChip(
                                                      label: const Text('Bank'),
                                                      selected:
                                                          paymentMethod ==
                                                          'bank',
                                                      onSelected: (_) =>
                                                          setState(
                                                            () =>
                                                                paymentMethod =
                                                                    'bank',
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: () {
                                                          final amt =
                                                              parsedAmount();
                                                          if (amt <= 0) {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                  'Enter a valid amount',
                                                                ),
                                                              ),
                                                            );
                                                            return;
                                                          }
                                                          doTopUp(amt);
                                                        },
                                                        child: const Text(
                                                          'Proceed to Top-up',
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],

                                              if (mode == 'connects') ...[
                                                const Text(
                                                  'Buy Connects (realistic pricing)',
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    const Text('Connects:'),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Slider(
                                                        value: connects
                                                            .toDouble(),
                                                        min: 5,
                                                        max: 200,
                                                        divisions: 39,
                                                        label: connects
                                                            .toString(),
                                                        onChanged: (v) =>
                                                            setState(
                                                              () => connects = v
                                                                  .round(),
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(connects.toString()),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Price per connect: \$${pricePerConnectUSD.toStringAsFixed(2)}',
                                                    ),
                                                    Text(
                                                      'Rate: ৳${exchangeRate.toStringAsFixed(0)}/\$1',
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Total (USD): \$${usdForConnects.toStringAsFixed(2)}',
                                                    ),
                                                    Text(
                                                      'Total (BDT): ৳${localForConnects.toStringAsFixed(0)}',
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                const Text('Payment method'),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    ChoiceChip(
                                                      label: const Text(
                                                        'Wallet',
                                                      ),
                                                      selected:
                                                          paymentMethod ==
                                                          'wallet',
                                                      onSelected: (_) =>
                                                          setState(
                                                            () =>
                                                                paymentMethod =
                                                                    'wallet',
                                                          ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ChoiceChip(
                                                      label: const Text('Card'),
                                                      selected:
                                                          paymentMethod ==
                                                          'card',
                                                      onSelected: (_) =>
                                                          setState(
                                                            () =>
                                                                paymentMethod =
                                                                    'card',
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: () async {
                                                          // If paying by wallet, perform a transaction that deducts and increments connects
                                                          if (paymentMethod ==
                                                              'wallet') {
                                                            await buyConnectsTx(
                                                              connects,
                                                              localForConnects,
                                                            );
                                                            return;
                                                          }
                                                          // For card/bank: simulate by creating a pending payment (not implemented fully here)
                                                          Navigator.of(
                                                            ctx,
                                                          ).pop();
                                                          showDialog(
                                                            context: context,
                                                            barrierDismissible:
                                                                false,
                                                            builder: (_) =>
                                                                const Center(
                                                                  child:
                                                                      CircularProgressIndicator(),
                                                                ),
                                                          );
                                                          try {
                                                            // Create a payment record as completed for demo purposes
                                                            final uid =
                                                                FirebaseAuth
                                                                    .instance
                                                                    .currentUser
                                                                    ?.uid;
                                                            if (uid == null) {
                                                              throw Exception(
                                                                'Not signed in',
                                                              );
                                                            }
                                                            final paymentRef =
                                                                FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                      'payments',
                                                                    )
                                                                    .doc();
                                                            await paymentRef.set({
                                                              'userId': uid,
                                                              'amount':
                                                                  localForConnects,
                                                              'method':
                                                                  paymentMethod,
                                                              'status':
                                                                  'completed',
                                                              'type':
                                                                  'connectsPurchase',
                                                              'connects':
                                                                  connects,
                                                              'createdAt':
                                                                  FieldValue.serverTimestamp(),
                                                            });
                                                            // increment user's connects convenience field
                                                            await FirebaseFirestore
                                                                .instance
                                                                .collection(
                                                                  'users',
                                                                )
                                                                .doc(
                                                                  FirebaseAuth
                                                                      .instance
                                                                      .currentUser!
                                                                      .uid,
                                                                )
                                                                .update({
                                                                  'totalConnects':
                                                                      FieldValue.increment(
                                                                        connects,
                                                                      ),
                                                                });
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                  'Connects purchased (simulated)',
                                                                ),
                                                              ),
                                                            );
                                                          } catch (e) {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  'Purchase failed: $e',
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        },
                                                        child: const Text(
                                                          'Buy Connects',
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              const SizedBox(height: 12),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            icon: const Icon(
                              Icons.account_balance_wallet,
                              color: Colors.green,
                            ),
                            label: const Text('Top-up'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // POST A JOB BIG BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PostJobScreen()),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 32),
                  label: const Text(
                    'Post a New Job',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // STATS ROW
              Row(
                children: [
                  _buildStatCard(
                    'Total Spent',
                    '৳${(data['totalSpent'] ?? 0).toStringAsFixed(0)}',
                    Icons.paid,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Active Jobs',
                    (data['activeJobs'] ?? 0).toString(),
                    Icons.work,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Hired',
                    (data['hiredFreelancers'] ?? 0).toString(),
                    Icons.people,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // QUICK ACTIONS
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildActionTile(
                context,
                'My Jobs',
                Icons.folder_open,
                Colors.blue,
                () => setState(() => _currentIndex = 1),
              ),
              _buildActionTile(
                context,
                'Hired Freelancers',
                Icons.person_search,
                Colors.purple,
                () => setState(() => _currentIndex = 2),
              ),
              _buildActionTile(
                context,
                'Invoices & Payments',
                Icons.receipt_long,
                Colors.orange,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InvoicesPaymentsScreen(),
                  ),
                ),
              ),
              _buildActionTile(
                context,
                'Messages',
                Icons.message,
                Colors.green,
                () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: Colors.green.shade600, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
