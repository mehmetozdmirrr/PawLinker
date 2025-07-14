import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController petNameController = TextEditingController();
  final TextEditingController petAgeController = TextEditingController();
  final TextEditingController petImageController = TextEditingController();

  String petType = 'Kedi';
  String petGender = 'Dişi';
  bool vaccinated = false;
  bool neutered = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void register() async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'pet': {
          'name': petNameController.text.trim(),
          'type': petType,
          'age': int.parse(petAgeController.text.trim()),
          'gender': petGender,
          'vaccinated': vaccinated,
          'neutered': neutered,
        },
      });

      await _firestore.collection('pets').add({
        'name': petNameController.text.trim(),
        'type': petType.toLowerCase(),
        'image': petImageController.text.trim().isNotEmpty
            ? petImageController.text.trim()
            : 'https://placedog.net/400/300?id=2',
        'ownerId': userCredential.user!.uid,
        'age': int.parse(petAgeController.text.trim()),
        'gender': petGender,
        'vaccinated': vaccinated,
        'neutered': neutered,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıt başarılı!')),
      );
    } catch (e) {
      debugPrint("❌ Firestore Hatası (pets ekleme): $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
            Image.asset('assets/logo.png', height: 100),
            const SizedBox(height: 10),
            const Text(
              "PawLinker",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Adınız"),
                    ),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: "E-posta"),
                    ),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: "Şifre"),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Evcil Hayvan Bilgileri",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextField(
                      controller: petNameController,
                      decoration:
                          const InputDecoration(labelText: "Hayvan Adı"),
                    ),
                    TextField(
                      controller: petAgeController,
                      decoration: const InputDecoration(labelText: "Yaş"),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: petImageController,
                      decoration: const InputDecoration(labelText: "Resim URL"),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text("Tür: "),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: petType,
                          onChanged: (value) =>
                              setState(() => petType = value!),
                          items: ['Kedi', 'Köpek']
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(width: 20),
                        const Text("Cinsiyet: "),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: petGender,
                          onChanged: (value) =>
                              setState(() => petGender = value!),
                          items: ['Dişi', 'Erkek']
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      title: const Text("Aşılı"),
                      value: vaccinated,
                      onChanged: (value) => setState(() => vaccinated = value!),
                    ),
                    CheckboxListTile(
                      title: const Text("Kısırlaştırılmış"),
                      value: neutered,
                      onChanged: (value) => setState(() => neutered = value!),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Kayıt Ol"),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
