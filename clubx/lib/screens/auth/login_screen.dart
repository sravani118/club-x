import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  final String selectedRole;
  
  const LoginScreen({super.key, this.selectedRole = 'student'});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Color _getRoleColor() {
    switch (widget.selectedRole.toLowerCase()) {
      case 'admin':
        return const Color(0xFF6C63FF);
      case 'coordinator':
        return const Color(0xFFFF6B2C);
      case 'student':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  IconData _getRoleIcon() {
    switch (widget.selectedRole.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'coordinator':
        return Icons.groups;
      case 'student':
        return Icons.school;
      default:
        return Icons.school;
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Check user role from Firestore (force server fetch to get latest data)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get(const GetOptions(source: Source.server));

      debugPrint('🔑 [LOGIN] User logged in: ${userCredential.user!.uid}');
      debugPrint('📊 [LOGIN] User doc exists: ${userDoc.exists}');
      if (userDoc.exists) {
        debugPrint('📊 [LOGIN] User data: ${userDoc.data()}');
      }

      // Admin emails configuration
      final adminEmails = [
        'admin@gmail.com',
        'admin@clubx.com',
        'admin@example.com',
      ];

      String userRole = 'student'; // Default role

      // First check if email is in admin list (takes priority)
      if (adminEmails.contains(_emailController.text.trim().toLowerCase())) {
        userRole = 'admin';
        
        // Update or create Firestore document with admin role (use merge to preserve existing fields like name, profileImage)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'email': _emailController.text.trim(),
          'role': 'admin',
          'createdAt': userDoc.exists && userDoc.data()?['createdAt'] != null
              ? userDoc.data()!['createdAt']
              : FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (userDoc.exists && userDoc.data() != null) {
        // User document exists and not an admin email
        final userData = userDoc.data()!;
        userRole = (userData['role'] ?? 'student').toString().trim().toLowerCase();
        
        debugPrint('✅ [LOGIN] Existing user - role: $userRole');
        if (userRole == 'coordinator') {
          debugPrint('🏛️ [LOGIN] Coordinator detected - clubId: ${userData['clubId']}');
        }
        
        // Auto-assign Student ID for students who don't have one (migration logic)
        if (userRole == 'student' && 
            (userData['studentId'] == null || userData['studentId'].toString().trim().isEmpty)) {
          debugPrint('🆔 [LOGIN] Student missing ID, generating...');
          
          try {
            // Use transaction to generate unique Student ID
            final generatedStudentId = await FirebaseFirestore.instance.runTransaction<String>((transaction) async {
              // Reference to counter document
              final counterRef = FirebaseFirestore.instance
                  .collection('counters')
                  .doc('studentCounter');
              
              // Get current counter value
              final counterDoc = await transaction.get(counterRef);
              
              int currentCount;
              if (!counterDoc.exists) {
                // First student - initialize counter
                currentCount = 0;
              } else {
                currentCount = counterDoc.data()?['current'] ?? 0;
              }
              
              // Increment counter
              final newCount = currentCount + 1;
              
              // Generate formatted Student ID
              final paddedNumber = newCount.toString().padLeft(4, '0');
              final studentId = 'CLX-STU-$paddedNumber';
              
              // Update counter
              transaction.set(counterRef, {'current': newCount});
              
              // Update user document with generated Student ID
              final userRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(userCredential.user!.uid);
              
              transaction.update(userRef, {
                'studentId': studentId,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              
              return studentId;
            });
            
            debugPrint('✅ [LOGIN] Student ID generated: $generatedStudentId');
          } catch (e) {
            debugPrint('❌ [LOGIN] Error generating Student ID: $e');
            // Continue login even if ID generation fails
          }
        }
        // No write operation - preserves all fields including clubId
      } else {
        // New user logging in without existing document - generate Student ID with transaction
        debugPrint('🆔 [LOGIN] New user, generating Student ID...');
        
        try {
          final generatedStudentId = await FirebaseFirestore.instance.runTransaction<String>((transaction) async {
            // Reference to counter document
            final counterRef = FirebaseFirestore.instance
                .collection('counters')
                .doc('studentCounter');
            
            // Get current counter value
            final counterDoc = await transaction.get(counterRef);
            
            int currentCount;
            if (!counterDoc.exists) {
              // First student - initialize counter
              currentCount = 0;
            } else {
              currentCount = counterDoc.data()?['current'] ?? 0;
            }
            
            // Increment counter
            final newCount = currentCount + 1;
            
            // Generate formatted Student ID
            final paddedNumber = newCount.toString().padLeft(4, '0');
            final studentId = 'CLX-STU-$paddedNumber';
            
            // Update counter
            transaction.set(counterRef, {'current': newCount});
            
            // Create user document with Student ID
            final userRef = FirebaseFirestore.instance
                .collection('users')
                .doc(userCredential.user!.uid);
            
            transaction.set(userRef, {
              'email': _emailController.text.trim(),
              'role': 'student',
              'studentId': studentId,
              'createdAt': FieldValue.serverTimestamp(),
            });
            
            return studentId;
          });
          
          debugPrint('✅ [LOGIN] Student ID generated: $generatedStudentId');
        } catch (e) {
          debugPrint('❌ [LOGIN] Error generating Student ID: $e');
          // Fallback to creating without ID
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'email': _emailController.text.trim(),
            'role': 'student',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Login successful!'),
            backgroundColor: const Color(0xFFFF6B2C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        // Redirect based on role
        if (userRole == 'admin') {
          context.go('/admin');
        } else if (userRole == 'coordinator') {
          context.go('/coordinator');
        } else {
          context.go('/student');
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid email or password';
          break;
        default:
          errorMessage = 'Login failed: ${e.message}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/role-selection'),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Title
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getRoleColor().withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getRoleIcon(),
                            color: _getRoleColor(),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Logging in as ${widget.selectedRole.substring(0, 1).toUpperCase()}${widget.selectedRole.substring(1)}',
                            style: TextStyle(
                              color: _getRoleColor(),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      'Login to continue',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Email Field
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      prefixIcon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 20),
                    // Password Field
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      isPassword: true,
                      obscureText: _obscurePassword,
                      validator: _validatePassword,
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey[400],
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Login Button
                    PrimaryButton(
                      text: 'Login',
                      onPressed: _handleLogin,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 32),
                    // Divider with OR
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey[700],
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey[700],
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Navigate to Signup
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/signup?role=${widget.selectedRole}'),
                        child: RichText(
                          text: TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                            children: const [
                              TextSpan(
                                text: 'Create Account',
                                style: TextStyle(
                                  color: Color(0xFFFF6B2C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool obscureText = false,
    String? Function(String?)? validator,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600]),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.grey[400])
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF6B2C), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red[700]!, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red[700]!, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
