import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'email_verification.dart';
import 'home_page.dart';
import 'register.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SafeShieldApp());
}

class SafeShieldApp extends StatelessWidget {
  const SafeShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeShield',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/verify-email': (context) => const EmailVerificationPage(),
        '/home': (context) => const HomePage(),
      },
      home: const AuthenticationWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Wrapper to handle authentication state
class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      // User is signed in
      if (firebaseUser.emailVerified) {
        return const HomePage();
      } else {
        return const EmailVerificationPage();
      }
    }

    // User is not signed in
    return const LoginPage();
  }
}

// Keep your existing RegisterPage class...