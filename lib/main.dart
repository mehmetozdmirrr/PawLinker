import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ⬅️ eklendi

import 'screens/auth/login_screen.dart';
import 'screens/match_screen.dart'; // ⬅️ eklendi (dosyan senin projede kök dizinde)


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBFsp-7VK-VO7mTjQT7jYP74bdE42kVrm4",
      appId: "1:418748903694:android:8141a6e91458544beba75f",
      messagingSenderId: "418748903694",
      projectId: "pawlinker-5ad10",
      storageBucket: "pawlinker-5ad10.firebasestorage.app",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PawLinker',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const AuthGate(), // ⬅️ LoginScreen yerine AuthGate
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasData) {
          // kullanıcı girişliyse
          return const MatchScreen();
        }
        // kullanıcı girişli değilse
        return const LoginScreen();
      },
    );
  }
}
