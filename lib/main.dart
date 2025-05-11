import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Constants
class AppConstants {
  static const String appTitle = 'Fire Extinguisher Manager';
  static const String usersCollection = 'users';
  static const String emailField = 'email';
  static const String userIdField = 'userId';
  static const String createdAtField = 'createdAt';
  static const String lastLoginField = 'lastLogin';
  static const String roleField = 'role';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }
  // Always log out on app start
  await FirebaseAuth.instance.signOut();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _error;
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();
      final String username = _usernameController.text.trim();

      if (email.isEmpty || password.isEmpty || (_isSignUp && username.isEmpty)) {
        setState(() {
          _error = 'Please fill in all fields';
          _isLoading = false;
        });
        return;
      }

      if (_isSignUp) {
        await _signUp(email, password, username);
      } else {
        await _login(email, password);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _login(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Update last login timestamp
        await _firestore
            .collection(AppConstants.usersCollection)
            .where(AppConstants.userIdField, isEqualTo: userCredential.user!.uid)
            .get()
            .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            snapshot.docs.first.reference.update({
              AppConstants.lastLoginField: FieldValue.serverTimestamp(),
            });
          }
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ExtinguisherListScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found for that email.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
      }
      throw errorMessage;
    }
  }

  Future<void> _signUp(String email, String password, String username) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        try {
          await _firestore.collection(AppConstants.usersCollection).add({
            AppConstants.emailField: email,
            'username': username,
            AppConstants.userIdField: userCredential.user!.uid,
            AppConstants.createdAtField: FieldValue.serverTimestamp(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account created successfully!')),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ExtinguisherListScreen()),
            );
          }
        } catch (firestoreError) {
          setState(() {
            _error = 'Sign up succeeded, but failed to save user data: '
                '\n${firestoreError.toString()}';
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
      }
      throw errorMessage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade300, Colors.deepPurple.shade700],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fire_extinguisher, size: 80, color: Colors.deepPurple),
                      const SizedBox(height: 16),
                      Text(
                        _isSignUp ? 'Create Account' : AppConstants.appTitle,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                      const SizedBox(height: 32),
                      if (_isSignUp) ...[
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'admin@example.com',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        obscureText: true,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: _handleAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(_isSignUp ? 'Sign Up' : 'Login', style: const TextStyle(fontSize: 16)),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isSignUp = !_isSignUp;
                                  _error = null;
                                });
                              },
                              child: Text(_isSignUp ? 'Already have an account? Login' : 'Create Account'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FireExtinguisher {
  String name;
  DateTime expiry;
  FireExtinguisher({required this.name, required this.expiry});
}

class ExtinguisherListScreen extends StatefulWidget {
  const ExtinguisherListScreen({super.key});

  @override
  State<ExtinguisherListScreen> createState() => _ExtinguisherListScreenState();
}

class _ExtinguisherListScreenState extends State<ExtinguisherListScreen> {
  int _selectedIndex = 0;
  bool _expiryDialogDismissed = false;

  @override
  void dispose() {
    _expiryDialogDismissed = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fire Extinguishers'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? _buildExtinguisherList()
          : _selectedIndex == 1
              ? _buildStatsPage()
              : _buildProfile(),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _addExtinguisher,
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Add Extinguisher',
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fire_extinguisher),
            label: 'Extinguishers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildExtinguisherList() {
    final user = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('fire').where('userId', isEqualTo: user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \n'+snapshot.error.toString()));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No extinguishers found.'));
          }

          final now = DateTime.now();
          final soonToExpire = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final expiryTimestamp = data['expiry'] as Timestamp?;
            final expiry = expiryTimestamp?.toDate() ?? now;
            return expiry.isBefore(now.add(const Duration(minutes: 5)));
          }).toList();

          // Show a more attractive MaterialBanner if any extinguisher is expiring within 5 minutes or already expired
          if (soonToExpire.isNotEmpty) {
            final names = soonToExpire
                .map((doc) => (doc.data() as Map<String, dynamic>)['name'] ?? 'Unnamed')
                .join(', ');
            Future.microtask(() {
              ScaffoldMessenger.of(context).clearMaterialBanners();
              ScaffoldMessenger.of(context).showMaterialBanner(
                MaterialBanner(
                  content: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Attention! Expiring soon or expired: $names',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange.shade100,
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  actions: [
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).clearMaterialBanners();
                      },
                      child: const Text('DISMISS', style: TextStyle(color: Colors.deepOrange)),
                    ),
                  ],
                ),
              );
            });
            // Show a dialog in the middle of the screen on app open/refresh, only if not dismissed
            if (!_expiryDialogDismissed) {
              Future.microtask(() {
                if (ModalRoute.of(context)?.isCurrent ?? true) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Expiry Alert'),
                        ],
                      ),
                      content: Text(
                        'The following extinguishers have expired or will expire soon:\n\n$names',
                        style: const TextStyle(fontSize: 16),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _expiryDialogDismissed = true;
                            });
                            Navigator.of(context).pop();
                          },
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                    barrierDismissible: true,
                  );
                }
              });
            }
          } else {
            Future.microtask(() {
              ScaffoldMessenger.of(context).clearMaterialBanners();
            });
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unnamed';
                    final expiryTimestamp = data['expiry'] as Timestamp?;
                    final expiry = expiryTimestamp?.toDate() ?? DateTime.now();
                    final expired = expiry.isBefore(DateTime.now());
                    final expiresSoon = expiry.difference(DateTime.now()).inMinutes < 5 && !expired;
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: _getExpiryColor(expiry),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: expired
                              ? Colors.red
                              : (expiresSoon ? Colors.orange : Colors.green),
                          child: Icon(
                            expired
                                ? Icons.warning
                                : (expiresSoon ? Icons.schedule : Icons.check_circle),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Text(
                          'Expiry: ' + DateFormat('yyyy-MM-dd HH:mm').format(expiry),
                          style: TextStyle(
                            color: expired
                                ? Colors.red.shade700
                                : (expiresSoon ? Colors.orange.shade800 : Colors.black87),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.deepPurple),
                              tooltip: 'Edit Expiry',
                              onPressed: () async {
                                final DateTime minDate = DateTime.now().add(const Duration(days: 10));
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: expiry.isAfter(minDate) ? expiry : minDate,
                                  firstDate: minDate,
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                                );
                                if (pickedDate != null) {
                                  TimeOfDay? pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(expiry.isAfter(minDate) ? expiry : minDate),
                                  );
                                  if (pickedTime != null) {
                                    final newExpiry = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );
                                    if (newExpiry.isBefore(minDate)) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Expiry must be at least 10 days from now.')),
                                        );
                                      }
                                      return;
                                    }
                                    try {
                                      await docs[index].reference.update({
                                        'expiry': Timestamp.fromDate(newExpiry),
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Expiry updated!')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to update expiry: \n$e')),
                                        );
                                      }
                                    }
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Extinguisher'),
                                    content: Text('Are you sure you want to delete $name?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await docs[index].reference.delete();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Extinguisher deleted!')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to delete: \n$e')),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfile() {
    final user = FirebaseAuth.instance.currentUser;
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .where(AppConstants.userIdField, isEqualTo: user?.uid)
          .get(),
      builder: (context, snapshot) {
        String username = '';
        String email = user?.email ?? '';
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          debugPrint('Firestore user data: ' + data.toString());
          username = data['username'] ?? '';
          email = data[AppConstants.emailField] ?? email;
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 60,
                backgroundColor: Colors.deepPurple,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                username.isNotEmpty ? username : 'User',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              const SizedBox(height: 8),
              Text(
                email,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              _buildProfileSection('Settings', Icons.settings, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings coming soon!')),
                );
              }),
              _buildProfileSection('Notifications', Icons.notifications, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications coming soon!')),
                );
              }),
              _buildProfileSection('Logout', Icons.logout, () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileSection(String title, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _addExtinguisher() async {
    final TextEditingController nameController = TextEditingController();
    DateTime? pickedDate;
    TimeOfDay? pickedTime;
    final DateTime minDate = DateTime.now().add(const Duration(days: 10));
    bool testingMode = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Extinguisher'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Extinguisher Name'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Switch(
                    value: testingMode,
                    onChanged: (val) => setState(() => testingMode = val),
                  ),
                  const Text('Testing Mode'),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  pickedDate = await showDatePicker(
                    context: context,
                    initialDate: testingMode ? DateTime.now() : minDate,
                    firstDate: testingMode ? DateTime.now().subtract(const Duration(days: 365)) : minDate,
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (pickedDate != null) {
                    pickedTime = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 12, minute: 0),
                    );
                  }
                },
                child: const Text('Pick Expiry Date & Time'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && pickedDate != null && pickedTime != null) {
                  final newExpiry = DateTime(
                    pickedDate!.year,
                    pickedDate!.month,
                    pickedDate!.day,
                    pickedTime!.hour,
                    pickedTime!.minute,
                  );
                  if (!testingMode && newExpiry.isBefore(minDate)) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Expiry must be at least 10 days from now.')),
                      );
                    }
                    return;
                  }
                  // Save to Firestore
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    await FirebaseFirestore.instance.collection('fire').add({
                      'name': nameController.text,
                      'expiry': Timestamp.fromDate(newExpiry),
                      'userId': user?.uid,
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Extinguisher added to Firestore!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add to Firestore: \n$e')),
                      );
                    }
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('fire').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: \n${snapshot.error.toString()}'));
        }
        final docs = snapshot.data?.docs ?? [];
        final now = DateTime.now();
        int expired = 0;
        int expiringSoon = 0;
        int notExpired = 0;
        List<Map<String, dynamic>> expiredList = [];
        List<Map<String, dynamic>> expiringSoonList = [];
        List<Map<String, dynamic>> notExpiredList = [];
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final expiryTimestamp = data['expiry'] as Timestamp?;
          final expiry = expiryTimestamp?.toDate() ?? now;
          final name = data['name'] ?? 'Unnamed';
          if (expiry.isBefore(now)) {
            expired++;
            expiredList.add({'name': name, 'expiry': expiry});
          } else if (expiry.difference(now).inMinutes < 5) {
            expiringSoon++;
            expiringSoonList.add({'name': name, 'expiry': expiry});
          } else {
            notExpired++;
            notExpiredList.add({'name': name, 'expiry': expiry});
          }
        }
        return SingleChildScrollView(
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Extinguisher Stats', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatBox('Expired', expired, Colors.red),
                        _buildStatBox('Expiring Soon', expiringSoon, Colors.orange),
                        _buildStatBox('Safe', notExpired, Colors.green),
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (expiredList.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Expired:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ),
                      ...expiredList.map((e) => ListTile(
                        leading: const Icon(Icons.warning, color: Colors.red),
                        title: Text(e['name']),
                        subtitle: Text('Expiry: ' + DateFormat('yyyy-MM-dd HH:mm').format(e['expiry'])),
                      )),
                      const SizedBox(height: 16),
                    ],
                    if (expiringSoonList.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Expiring Soon:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ),
                      ...expiringSoonList.map((e) => ListTile(
                        leading: const Icon(Icons.schedule, color: Colors.orange),
                        title: Text(e['name']),
                        subtitle: Text('Expiry: ' + DateFormat('yyyy-MM-dd HH:mm').format(e['expiry'])),
                      )),
                      const SizedBox(height: 16),
                    ],
                    if (notExpiredList.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Safe:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ),
                      ...notExpiredList.map((e) => ListTile(
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(e['name']),
                        subtitle: Text('Expiry: ' + DateFormat('yyyy-MM-dd HH:mm').format(e['expiry'])),
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatBox(String label, int count, Color color) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Text(
            '$count',
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 20),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Color _getExpiryColor(DateTime expiry) {
    if (expiry.isBefore(DateTime.now())) {
      return Colors.red.shade100;
    } else if (expiry.difference(DateTime.now()).inDays < 3) {
      return Colors.orange.shade100;
    } else {
      return Colors.green.shade50;
    }
  }
}
