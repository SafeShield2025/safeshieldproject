import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  _EmailVerificationPageState createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isVerified = false;
  late User _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser!;
    _checkEmailVerified();
  }

  Future<void> _checkEmailVerified() async {
    await _user.reload();
    setState(() {
      _isVerified = _user.emailVerified;
    });

    if (_isVerified) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _resendVerificationEmail() async {
    await _user.sendEmailVerification();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification email resent! Please check your inbox.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email Verification')),
      body: Center(
        child:
            _isVerified
                ? const Text('Email verified! Redirecting to Login...')
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'A verification email has been sent to your email address.\nPlease verify before proceeding.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _checkEmailVerified,
                      child: const Text('I have verified my email'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _resendVerificationEmail,
                      child: const Text('Resend Email Verification'),
                    ),
                  ],
                ),
      ),
    );
  }
}
