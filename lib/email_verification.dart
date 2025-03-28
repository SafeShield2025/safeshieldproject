import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailVerificationPage extends StatefulWidget {
  final String name;
  final String phone;
  final String email;
  final String password;

  const EmailVerificationPage({
    super.key,
    required this.email,
    required this.name,
    required this.phone,
    required this.password,
  });

  @override
  _EmailVerificationPageState createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final auth = FirebaseAuth.instance;
  late User user;
  late Timer timer;
  bool isEmailVerified = false;
  bool canResendEmail = true;
  int resendCooldown = 0;
  late Timer cooldownTimer;

  @override
  void initState() {
    super.initState();
    user = auth.currentUser!;

    // Check if email is already verified
    checkEmailVerified();

    // Set up timer to check email verification status
    timer = Timer.periodic(const Duration(seconds: 5), (_) => checkEmailVerified());
  }

  Future<void> checkEmailVerified() async {
    // Need to reload user data to get updated email verification status
    await user.reload();
    user = auth.currentUser!;

    if (user.emailVerified) {
      setState(() {
        isEmailVerified = true;
      });
      timer.cancel();

      // Add user details to Firestore when email is verified
      await addUserDetailsToFirestore();
    }
  }

  Future<void> addUserDetailsToFirestore() async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': widget.name ?? '',
        'phone': widget.phone ?? '',
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': true,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add user details: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> resendVerificationEmail() async {
    if (!canResendEmail) return;

    try {
      await user.sendEmailVerification();
      setState(() {
        canResendEmail = false;
        resendCooldown = 60;
      });

      // Set up cooldown timer
      cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          if (resendCooldown > 0) {
            resendCooldown--;
          } else {
            canResendEmail = true;
            cooldownTimer.cancel();
          }
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent. Please check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send email: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    timer.cancel();
    if (resendCooldown > 0) {
      cooldownTimer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isEmailVerified) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 100,
              ),
              const SizedBox(height: 24),
              const Text(
                'Email Verified!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your email has been successfully verified.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/home');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Continue to App'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Email Verification'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.email,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Verify Your Email',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'A verification email has been sent to:\n${user.email}',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'Please check your inbox and click the verification link to continue.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: canResendEmail ? resendVerificationEmail : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text(
                canResendEmail
                    ? 'Resend Verification Email'
                    : 'Resend in ${resendCooldown}s',
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Back to Login'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Didn\'t receive the email? Check your spam folder or try resending.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}