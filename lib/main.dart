import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'dashboard_page.dart';
import 'map_page.dart'; // 📌 استيراد صفحة الخريطة
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // تهيئة Hive
  await Hive.initFlutter();
  // افتح صندوق لتخزين الزيارات offline
  await Hive.openBox('offlineVisits');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sales Track',
      home: const AuthCheck(), // ✅ هنا بدلنا initialRoute بالـ AuthCheck
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/dashboard': (context) => const DashboardPage(),
        '/map': (context) => const MapPage(),
      },
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  Future<String?> _getUserRole(String uid) async {
    final snap =
    await FirebaseFirestore.instance.collection("users").doc(uid).get();
    if (snap.exists) {
      return (snap.data()!["role"] ?? "").toString().toLowerCase();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 🚪 لو مفيش مستخدم مسجل
        if (!snapshot.hasData) {
          return const LoginPage();
        }

        // ✅ لو في مستخدم مسجل → نجيب دوره
        final user = snapshot.data!;
        return FutureBuilder<String?>(
          future: _getUserRole(user.uid),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = roleSnap.data;

            if (role == "rep") {
              return const HomePage();
            } else if (role == "manager" || role == "admin") {
              return const DashboardPage();
            } else {
              // 🔄 fallback → لو الدور مش متسجل يرجع لصفحة تسجيل الدخول
              return const LoginPage();
            }
          },
        );
      },
    );
  }
}
