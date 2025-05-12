import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'dart:async';

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
  Timer? _refreshTimer;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'expiry'; // 'expiry', 'name', 'status'
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Kitchen', 'Office', 'Warehouse', 'Factory', 'Other'];

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _expiryDialogDismissed = false;
    super.dispose();
  }

  List<QueryDocumentSnapshot> _sortAndFilterDocs(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    var filteredDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    filteredDocs.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      final expiryA = (dataA['expiry'] as Timestamp?)?.toDate() ?? now;
      final expiryB = (dataB['expiry'] as Timestamp?)?.toDate() ?? now;
      final nameA = (dataA['name'] ?? '').toString();
      final nameB = (dataB['name'] ?? '').toString();

      switch (_sortBy) {
        case 'name':
          return nameA.compareTo(nameB);
        case 'status':
          final statusA = _getStatusValue(expiryA);
          final statusB = _getStatusValue(expiryB);
          return statusA.compareTo(statusB);
        case 'expiry':
        default:
          return expiryA.compareTo(expiryB);
      }
    });

    return filteredDocs;
  }

  int _getStatusValue(DateTime expiry) {
    final now = DateTime.now();
    if (expiry.isBefore(now)) return 0; // Expired
    if (expiry.difference(now).inMinutes < 5) return 1; // Expiring soon
    return 2; // Safe
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
      child: Column(
        children: [
          // Search and Sort Controls
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search extinguishers...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((category) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (bool selected) {
                              setState(() {
                                _selectedCategory = selected ? category : 'All';
                              });
                            },
                            backgroundColor: Colors.grey.shade200,
                            selectedColor: Colors.deepPurple.shade200,
                            checkmarkColor: Colors.deepPurple,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildSortButton('expiry', 'Expiry'),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildSortButton('name', 'Name'),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildSortButton('status', 'Status'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Extinguisher List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('fire')
                  .where('userId', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: \n'+snapshot.error.toString()));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No extinguishers found.'));
                }

                var filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final category = (data['category'] ?? 'Other').toString();
                  return name.contains(_searchQuery.toLowerCase()) &&
                         (_selectedCategory == 'All' || category == _selectedCategory);
                }).toList();

                final sortedAndFilteredDocs = _sortAndFilterDocs(filteredDocs);
                if (sortedAndFilteredDocs.isEmpty) {
                  return const Center(child: Text('No matching extinguishers found.'));
                }

                final now = DateTime.now();
                final soonToExpire = sortedAndFilteredDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final expiryTimestamp = data['expiry'] as Timestamp?;
                  final expiry = expiryTimestamp?.toDate() ?? now;
                  return expiry.isBefore(now.add(const Duration(minutes: 5)));
                }).toList();

                // Show a dialog in the middle of the screen on app open/refresh, only if not dismissed
                if (soonToExpire.isNotEmpty && !_expiryDialogDismissed) {
                  final names = soonToExpire
                      .map((doc) => (doc.data() as Map<String, dynamic>)['name'] ?? 'Unnamed')
                      .join(', ');
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

                return ListView.builder(
                  itemCount: sortedAndFilteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = sortedAndFilteredDocs[index].data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unnamed';
                    final expiryTimestamp = data['expiry'] as Timestamp?;
                    final expiry = expiryTimestamp?.toDate() ?? DateTime.now();
                    final expired = expiry.isBefore(DateTime.now());
                    final expiresSoon = expiry.difference(DateTime.now()).inMinutes < 5 && !expired;
                    final category = data['category'] ?? 'Other';
                    final notes = data['notes'] as String?;

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: _getExpiryColor(expiry),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ExpansionTile(
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expiry: ' + DateFormat('yyyy-MM-dd HH:mm').format(expiry),
                              style: TextStyle(
                                color: expired
                                    ? Colors.red.shade700
                                    : (expiresSoon ? Colors.orange.shade800 : Colors.black87),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Category: $category',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.deepPurple),
                              tooltip: 'Edit',
                              onPressed: () async {
                                final TextEditingController editNameController = TextEditingController(text: name);
                                final TextEditingController editNotesController = TextEditingController(text: notes ?? '');
                                String editCategory = category;
                                
                                await showDialog(
                                  context: context,
                                  builder: (context) => StatefulBuilder(
                                    builder: (context, setState) => AlertDialog(
                                      title: const Text('Edit Extinguisher'),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: editNameController,
                                              decoration: const InputDecoration(
                                                labelText: 'Name',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            DropdownButtonFormField<String>(
                                              value: editCategory,
                                              decoration: const InputDecoration(
                                                labelText: 'Category',
                                                border: OutlineInputBorder(),
                                              ),
                                              items: _categories.where((cat) => cat != 'All').map((String category) {
                                                return DropdownMenuItem<String>(
                                                  value: category,
                                                  child: Text(category),
                                                );
                                              }).toList(),
                                              onChanged: (String? newValue) {
                                                if (newValue != null) {
                                                  setState(() {
                                                    editCategory = newValue;
                                                  });
                                                }
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            TextField(
                                              controller: editNotesController,
                                              decoration: const InputDecoration(
                                                labelText: 'Notes',
                                                border: OutlineInputBorder(),
                                              ),
                                              maxLines: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            try {
                                              await sortedAndFilteredDocs[index].reference.update({
                                                'name': editNameController.text,
                                                'category': editCategory,
                                                'notes': editNotesController.text.trim(),
                                              });
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Extinguisher updated!')),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Failed to update: \n$e')),
                                                );
                                              }
                                            }
                                            Navigator.pop(context);
                                          },
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
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
                                    await sortedAndFilteredDocs[index].reference.delete();
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
                        children: [
                          if (notes != null && notes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Notes:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(notes),
                                ],
                              ),
                            ),
                        ],
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

  Widget _buildSortButton(String sortType, String label) {
    final isSelected = _sortBy == sortType;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _sortBy = sortType;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.deepPurple : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: isSelected ? 4 : 1,
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
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
    final TextEditingController notesController = TextEditingController();
    DateTime? pickedDate;
    TimeOfDay? pickedTime;
    final DateTime minDate = DateTime.now().add(const Duration(days: 10));
    bool testingMode = false;
    String selectedCategory = 'Other';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fire_extinguisher, color: Colors.deepPurple, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: const Text(
                        'Add New Extinguisher',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Extinguisher Name',
                            hintText: 'Enter a descriptive name',
                            prefixIcon: const Icon(Icons.label),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: _categories.where((cat) => cat != 'All').map((String category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  selectedCategory = newValue;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: notesController,
                          decoration: InputDecoration(
                            labelText: 'Notes (optional)',
                            hintText: 'Add any additional information',
                            prefixIcon: const Icon(Icons.note),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 0,
                          color: Colors.grey.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.timer, color: Colors.deepPurple),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Expiry Settings',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Switch(
                                      value: testingMode,
                                      onChanged: (val) => setState(() => testingMode = val),
                                      activeColor: Colors.deepPurple,
                                    ),
                                    const Text('Testing Mode'),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: testingMode ? DateTime.now() : minDate,
                                        firstDate: testingMode ? DateTime.now().subtract(const Duration(days: 365)) : minDate,
                                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: const ColorScheme.light(
                                                primary: Colors.deepPurple,
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (pickedDate != null) {
                                        pickedTime = await showTimePicker(
                                          context: context,
                                          initialTime: const TimeOfDay(hour: 12, minute: 0),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme: const ColorScheme.light(
                                                  primary: Colors.deepPurple,
                                                ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.calendar_today),
                                    label: Flexible(
                                      child: Text(
                                        pickedDate != null && pickedTime != null
                                            ? '${DateFormat('yyyy-MM-dd').format(pickedDate!)} ${pickedTime!.format(context)}'
                                            : 'Pick Expiry Date & Time',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: ElevatedButton(
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
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              await FirebaseFirestore.instance.collection('fire').add({
                                'name': nameController.text,
                                'expiry': Timestamp.fromDate(newExpiry),
                                'userId': user?.uid,
                                'category': selectedCategory,
                                'notes': notesController.text.trim(),
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Extinguisher added successfully!')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to add extinguisher: \n$e')),
                                );
                              }
                            }
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill in all required fields')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Add Extinguisher'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsPage() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('fire')
          .where('userId', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
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
