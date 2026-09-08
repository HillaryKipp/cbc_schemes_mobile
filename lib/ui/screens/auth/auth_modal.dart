import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/theme.dart';
import '../../../state/auth_provider.dart';
import '../../../state/scheme_list_provider.dart';

class AuthModal extends StatefulWidget {
  final String title;
  final String message;
  final bool initialIsSignUp;

  const AuthModal({
    super.key,
    this.title = 'Account & Scheme Records',
    this.message = 'Sign in or create an account to customize your profile, auto-fill scheme covers, and keep all your teaching records safely backed up.',
    this.initialIsSignUp = false,
  });

  static void show(BuildContext context, {String? title, String? message, bool isSignUp = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: AuthModal(
          title: title ?? 'Account & Scheme Records',
          message: message ?? 'Sign in or create an account to customize your profile, auto-fill scheme covers, and keep all your teaching records safely backed up.',
          initialIsSignUp: isSignUp,
        ),
      ),
    );
  }

  @override
  State<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends State<AuthModal> {
  final _formKey = GlobalKey<FormState>();
  late bool _isSignUp;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _tscController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _schoolNameController.dispose();
    _tscController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final schemeList = context.read<SchemeListProvider>();

    bool success = false;
    if (_isSignUp) {
      success = await auth.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        fullName: _fullNameController.text.trim(),
        schoolName: _schoolNameController.text.trim(),
        tscNumber: _tscController.text.trim(),
      );
    } else {
      success = await auth.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    }

    if (!mounted) return;

    if (success) {
      await schemeList.loadSchemes();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSignUp ? 'Account created successfully!' : 'Welcome back! Signed in.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } else {
      final error = auth.errorMessage ?? 'Authentication failed. Please check your credentials.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreenLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_rounded, color: AppTheme.primaryGreen, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSignUp ? 'Create Teacher Account' : 'Teacher Sign In',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Access records & sync your schemes',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tab Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isSignUp = false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: !_isSignUp ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: !_isSignUp
                              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: !_isSignUp ? FontWeight.w700 : FontWeight.w500,
                            color: !_isSignUp ? AppTheme.primaryGreen : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isSignUp = true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isSignUp ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _isSignUp
                              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: _isSignUp ? FontWeight.w700 : FontWeight.w500,
                            color: _isSignUp ? AppTheme.primaryGreen : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isSignUp) ...[
                      // Full Name
                      const Text('Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Tr. Jane Wanjiku',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                        validator: (val) {
                          if (_isSignUp && (val == null || val.trim().isEmpty)) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // School Name
                      const Text('School Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _schoolNameController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Nairobi Primary School',
                          prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // TSC Number
                      const Text('TSC Number (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _tscController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. 123456',
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Email Field
                    const Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'teacher@school.ac.ke',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!val.contains('@') || !val.contains('.')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Password Field
                    const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: _isSignUp ? 'Create a secure password (min 6 chars)' : 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: AppTheme.textMuted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your password';
                        }
                        if (val.trim().length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                              )
                            : Text(
                                _isSignUp ? 'Create Account & Continue' : 'Sign In to Account',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Switch Mode / Continue as guest
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _isSignUp = !_isSignUp),
                        child: Text(
                          _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Create one",
                          style: const TextStyle(fontSize: 13, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
