import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController petNameController = TextEditingController();
  final TextEditingController petAgeController = TextEditingController();
  final TextEditingController petImageController = TextEditingController();

  // Form alanları
  String petType = 'Kedi';
  String petGender = 'Dişi';
  bool vaccinated = false;
  bool neutered = false;

  bool _loading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    petNameController.dispose();
    petAgeController.dispose();
    petImageController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    // Basit doğrulamalar
    final email = emailController.text.trim();
    final pass = passwordController.text;
    final displayName = nameController.text.trim();
    final petName = petNameController.text.trim();
    final petAgeStr = petAgeController.text.trim();
    final age = int.tryParse(petAgeStr);

    if (email.isEmpty ||
        pass.isEmpty ||
        displayName.isEmpty ||
        petName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm zorunlu alanları doldurun')),
      );
      return;
    }
    if (age == null || age < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yaş geçersiz')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // 1) Kullanıcı oluştur
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      final uid = cred.user!.uid;

      // 2) Users dokümanı
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': displayName,
        'email': email,
        'pet': {
          'name': petName,
          'type': petType.toLowerCase(),
          'age': age,
          'gender': petGender,
          'vaccinated': vaccinated,
          'neutered': neutered,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3) Pets koleksiyonu
      final petDoc = await _firestore.collection('pets').add({
        'name': petName,
        'type': petType.toLowerCase(),
        'image': petImageController.text.trim().isNotEmpty
            ? petImageController.text.trim()
            : 'https://placedog.net/400/300?id=2',
        'ownerId': uid,
        'age': age,
        'gender': petGender,
        'vaccinated': vaccinated,
        'neutered': neutered,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4) Kullanıcıya primaryPetId iliştir (ileride işimize yarar)
      await _firestore.collection('users').doc(uid).update({
        'primaryPetId': petDoc.id,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıt başarılı!')),
      );
      // Başarılı durumda Navigator kullanmıyoruz; AuthGate MatchScreen'e geçirecek.
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'email-already-in-use' => 'Bu e-posta zaten kullanılıyor',
        'weak-password' => 'Şifre zayıf (en az 6 karakter önerilir)',
        'invalid-email' => 'E-posta biçimi hatalı',
        _ => 'Kayıt başarısız: ${e.code}',
      };
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bir hata oluştu')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
                    // Kullanıcı bilgileri
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: "Adınız"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: "E-posta"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: "Şifre"),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    const Text(
                      "Evcil Hayvan Bilgileri",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: petNameController,
                      textInputAction: TextInputAction.next,
                      decoration:
                          const InputDecoration(labelText: "Hayvan Adı"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: petAgeController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: "Yaş"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: petImageController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                          labelText: "Resim URL (opsiyonel)"),
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
                          items: ['Kedi', 'Köpek'].map((e) {
                            return DropdownMenuItem(value: e, child: Text(e));
                          }).toList(),
                        ),
                        const SizedBox(width: 20),
                        const Text("Cinsiyet: "),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: petGender,
                          onChanged: (value) =>
                              setState(() => petGender = value!),
                          items: ['Dişi', 'Erkek'].map((e) {
                            return DropdownMenuItem(value: e, child: Text(e));
                          }).toList(),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      title: const Text("Aşılı"),
                      contentPadding: EdgeInsets.zero,
                      value: vaccinated,
                      onChanged: (value) => setState(() => vaccinated = value!),
                    ),
                    CheckboxListTile(
                      title: const Text("Kısırlaştırılmış"),
                      contentPadding: EdgeInsets.zero,
                      value: neutered,
                      onChanged: (value) => setState(() => neutered = value!),
                    ),

                    const SizedBox(height: 16),

                    // Kayıt butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("Kayıt Ol"),
                      ),
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
