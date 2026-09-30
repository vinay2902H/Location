import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'receiver_screen.dart';

class ReceiverLoginScreen extends StatefulWidget {
  const ReceiverLoginScreen({super.key});

  @override
  State<ReceiverLoginScreen> createState() => _ReceiverLoginScreenState();
}

class _ReceiverLoginScreenState extends State<ReceiverLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim().toLowerCase();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mapped_receiver_username', username);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ReceiverScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save receiver login: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/icons/winzowin.png',
                            width: 76,
                            height: 76,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.location_on, color: Colors.white, size: 40),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // App Title
                    const Text(
                      'WinzoWin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Location Receiver Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF334155), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Enter Receiver Username',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'You will only see the senders mapped to your username by the administrator.',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Username Field
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Receiver Username',
                              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                              hintText: 'e.g. x, receiver1, supervisor',
                              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                              prefixIcon: const Icon(
                                Icons.alternate_email_rounded,
                                color: Color(0xFF60A5FA),
                                size: 20,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF334155)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.8),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444)),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your receiver username';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 16),

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF450A0A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFB91C1C)),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Submit Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Login to Receiver',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded, size: 18),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Admin Mapping Note
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155), width: 0.8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFF60A5FA), size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Permissions are managed by your administrator via the Admin Panel.',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
