import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _loading = true);

    try {
      // ✅ افحص لو اسم المستخدم مستخدم قبل كده
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception("اسم المستخدم مستخدم بالفعل. اختار اسم تاني.");
      }

      // ✅ إنشاء حساب Firebase Auth
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = userCred.user!.uid;

      // ✅ تحديد الدور
      String role = "rep";
      if (email.toLowerCase() == "manager@company.com") {
        role = "manager";
      }

      // ✅ تخزين البيانات في Firestore
      await FirebaseFirestore.instance.collection("users").doc(username).set({
        "username": username,
        "email": email,
        "createdAt": DateTime.now(),
        "role": role,
      });

      // ✅ توجيه حسب الدور
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم إنشاء الحساب ✅")),
        );
        if (role == "manager") {
          Navigator.pushReplacementNamed(context, "/dashboard");
        } else {
          Navigator.pushReplacementNamed(context, "/home");
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // ✅ أيقونة أو لوجو فوق
                  const Center(
                    child: Icon(
                      Icons.person_add_alt_1,
                      size: 120,
                      color: Colors.deepPurple,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Center(
                    child: Text(
                      "إنشاء حساب جديد",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ✅ اسم المستخدم
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: TextFormField(
                      controller: _usernameController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        hintText: "اسم المستخدم",
                        border: OutlineInputBorder(),
                        errorStyle: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                      validator: (value) =>
                      value == null || value.isEmpty
                          ? "⚠️ ادخل اسم المستخدم"
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ البريد الإلكتروني
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        hintText: "البريد الإلكتروني",
                        border: OutlineInputBorder(),
                        errorStyle: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                      validator: (value) => value == null || !value.contains("@")
                          ? "⚠️ ادخل بريد إلكتروني صحيح"
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ كلمة المرور
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        hintText: "كلمة المرور",
                        border: OutlineInputBorder(),
                        errorStyle: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                      validator: (value) =>
                      value == null || value.length < 6
                          ? "⚠️ كلمة المرور يجب أن تكون 6 أحرف على الأقل"
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () {
                      if (_formKey.currentState!.validate()) {
                        _register();
                      }
                    },
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "إنشاء حساب",
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
