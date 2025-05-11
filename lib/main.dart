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
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        ),
                      ),
                      const SizedBox(height: 16),
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

  List<FireExtinguisher> extinguishers = [
    FireExtinguisher(name: 'Extinguisher A', expiry: DateTime.now().add(const Duration(days: 10))),
    FireExtinguisher(name: 'Extinguisher B', expiry: DateTime.now().add(const Duration(days: 5))),
    FireExtinguisher(name: 'Extinguisher C', expiry: DateTime.now().add(const Duration(days: -1))),
    FireExtinguisher(name: 'Extinguisher D', expiry: DateTime.now().add(const Duration(days: 0))), // expires today
    FireExtinguisher(name: 'Extinguisher E', expiry: DateTime.now().add(const Duration(days: 30))),
    FireExtinguisher(name: 'Extinguisher F', expiry: DateTime.now().add(const Duration(days: -10))), // expired 10 days ago
  ];

  void _editExpiry(int index) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: extinguishers[index].expiry,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(extinguishers[index].expiry),
      );
      if (pickedTime != null) {
        final newExpiry = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          extinguishers[index].expiry = newExpiry;
        });
      }
    }
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

  Widget _buildExtinguisherList() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView.builder(
        itemCount: extinguishers.length,
        itemBuilder: (context, index) {
          final extinguisher = extinguishers[index];
          final expired = extinguisher.expiry.isBefore(DateTime.now());
          final expiresSoon = extinguisher.expiry.difference(DateTime.now()).inDays < 3 && !expired;
          return Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: _getExpiryColor(extinguisher.expiry),
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
                extinguisher.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text(
                'Expiry: ' + DateFormat('yyyy-MM-dd HH:mm').format(extinguisher.expiry),
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
                    onPressed: () => _editExpiry(index),
                    tooltip: 'Edit Expiry',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Extinguisher'),
                          content: Text('Are you sure you want to delete ${extinguisher.name}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  extinguishers.removeAt(index);
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfile() {
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
          const Text(
            'Admin',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurple),
          ),
          const SizedBox(height: 8),
            const Text(
            'admin@example.com',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          _buildProfileSection('Settings', Icons.settings, () {
            // Placeholder for settings
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings coming soon!')),
            );
          }),
          _buildProfileSection('Notifications', Icons.notifications, () {
            // Placeholder for notifications
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
    final TextEditingController nameController = TextEditingController(text: 'Extinguisher ${extinguishers.length + 1}');
    DateTime? pickedDate;
    TimeOfDay? pickedTime;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Extinguisher'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Extinguisher Name'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (pickedDate != null) {
                  pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
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
            onPressed: () {
              if (nameController.text.isNotEmpty && pickedDate != null && pickedTime != null) {
                final newExpiry = DateTime(
                  pickedDate!.year,
                  pickedDate!.month,
                  pickedDate!.day,
                  pickedTime!.hour,
                  pickedTime!.minute,
                );
                setState(() {
                  extinguishers.add(FireExtinguisher(name: nameController.text, expiry: newExpiry));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
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
      body: _selectedIndex == 0 ? _buildExtinguisherList() : _buildProfile(),
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
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
