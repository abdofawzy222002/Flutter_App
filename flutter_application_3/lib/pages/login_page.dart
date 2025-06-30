import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_3/pages/signup_page.dart';
import 'package:flutter_application_3/tabBar.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  LoginPage({super.key});
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool visible = true;

  void _togglePasswordVisibility() {
    setState(() => visible = !visible);
  }

  Future _signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.standard(
        scopes: ['email'],
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.idToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'name': user.displayName ?? '',
                'email': user.email ?? '',
                'createdAt': FieldValue.serverTimestamp(),
              });
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TabBarScreen()),
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Error"),
          content: Text("Google sign-in failed.\n$e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      try {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        final user = credential.user;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
        if (userDoc.exists) {
          final userName = userDoc.data()?['name'] ?? '';
          await user.updateDisplayName(userName);
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TabBarScreen()),
        );
      } on FirebaseAuthException catch (e) {
        String message = "Login failed";
        if (e.code == 'user-not-found') {
          message = "No user found for that email.";
        } else if (e.code == 'wrong-password') {
          message = "Wrong password provided.";
        }

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Login Failed"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          ),
        );
      } catch (e) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Error"),
            content: Text("An error occurred."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network('data:image/jpeg;base64,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', fit: BoxFit.cover),
          Center(
            child: Card(
              color: Colors.white.withOpacity(0.85),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: SizedBox(
                    width: 300,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email, color: Colors.indigo),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please enter your email';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value))
                              return 'Please enter a valid email';
                            return null;
                          },
                        ),
                        SizedBox(height: 15),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: visible,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock, color: Colors.indigo),
                            suffixIcon: IconButton(
                              icon: Icon(
                                visible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.indigo,
                              ),
                              onPressed: _togglePasswordVisibility,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 25),
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Login',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        SizedBox(height: 15),
                        ElevatedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: Icon(Icons.account_circle, color: Colors.white),
                          label: Text(
                            'Login with Google',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(height: 15),
                                      InkWell(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => SignupPage()),
                              );
                            },
                            child: const Text(
                              'If you haven`t an Account Go to Signup',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.indigo,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
