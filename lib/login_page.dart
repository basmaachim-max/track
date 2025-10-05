import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _loading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw FirebaseAuthException(
            code: "user-not-found", message: "اسم المستخدم غير موجود");
      }

      final userData = query.docs.first.data();
      final email = userData["email"];
      final role = userData["role"];

      if (email == null) {
        throw FirebaseAuthException(
            code: "invalid-email", message: "هذا الحساب لا يحتوي على بريد مسجل");
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        if (role == "rep") {
          Navigator.pushReplacementNamed(context, "/home");
        } else if (role == "manager") {
          Navigator.pushReplacementNamed(context, "/dashboard");
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ لم يتم تحديد دور المستخدم")),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      if (e.code == 'wrong-password') {
        msg = "❌ كلمة المرور غير صحيحة";
      } else if (e.code == 'user-not-found') {
        msg = "❌ المستخدم غير موجود";
      } else {
        msg = "❌ خطأ: ${e.message}";
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ خطأ غير متوقع: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView( // ✅ يمنع overflow
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // ✅ أيقونة أو لوجو
                  const Center(
                    child: Icon(
                      Icons.lock_outline,
                      size: 120,
                      color: Colors.deepPurple,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Center(
                    child: Text(
                      "تسجيل الدخول",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ✅ TextFormField اسم المستخدم
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: TextFormField(
                      controller: _usernameController,
                      textAlign: TextAlign.right,
                      autovalidateMode: AutovalidateMode.onUserInteraction, // 👈
                      decoration: const InputDecoration(
                        hintText: "اسم المستخدم",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      value == null || value.isEmpty
                          ? "⚠️ ادخل اسم المستخدم"
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ TextFormField كلمة المرور
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textAlign: TextAlign.right,
                      autovalidateMode: AutovalidateMode.onUserInteraction, // 👈
                      decoration: const InputDecoration(
                        hintText: "كلمة المرور",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      value == null || value.isEmpty || value.length < 6
                          ? "⚠️ كلمة المرور يجب أن تكون 6 أحرف على الأقل"
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50), // ✅ زرار أطول
                    ),
                    onPressed: _loading
                        ? null
                        : () {
                      if (_formKey.currentState!.validate()) {
                        _login();
                      }
                    },
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "دخول",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
