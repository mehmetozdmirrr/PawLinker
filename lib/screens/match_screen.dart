import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pet_detail_screen.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  List<Map<String, dynamic>> pets = [];
  int currentIndex = 0;
  bool isLoading = true;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    fetchPets();
  }

  Future<void> fetchPets() async {
    try {
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      final userData = userDoc.data();
      final userType = userData?['pet']?['type']?.toString().toLowerCase();

      if (userType == null) {
        debugPrint("❌ Kullanıcının türü (type) yok.");
        return;
      }

      final likesSnapshot = await FirebaseFirestore.instance
          .collection('likes')
          .where('userId', isEqualTo: user!.uid)
          .get();

      final likedPetNames = likesSnapshot.docs
          .map((doc) => doc.data()['petName'].toString().toLowerCase())
          .toSet();

      final snapshot = await FirebaseFirestore.instance
          .collection('pets')
          .where('type', isEqualTo: userType)
          .get();

      pets = snapshot.docs
          .map((doc) => doc.data())
          .where((pet) =>
              pet['ownerId'] != user!.uid &&
              !likedPetNames.contains(pet['name'].toString().toLowerCase()))
          .toList();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Firestore hatası: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveLike(Map<String, dynamic> pet) async {
    if (user == null) return;

    await FirebaseFirestore.instance.collection('likes').add({
      'userId': user!.uid,
      'petName': pet['name'],
      'petType': pet['type'],
      'petImage': pet['image'],
      'likedAt': FieldValue.serverTimestamp(),
    });
  }

  void swipeRight() {
    final likedPet = pets[currentIndex];
    saveLike(likedPet);
    setState(() {
      currentIndex++;
    });
  }

  void swipeLeft() {
    setState(() {
      currentIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (currentIndex >= pets.length) {
      return Scaffold(
        appBar: AppBar(title: const Text("Eşleşme Ekranı")),
        body: const Center(child: Text("Tüm hayvanlar görüntülendi.")),
      );
    }

    final pet = pets[currentIndex];

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/logo_background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PetDetailScreen(pet: pet),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              pet['image'],
                              height: 240,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          pet['name'],
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Tür: ${pet['type']}  |  Yaş: ${pet['age'] ?? 'Bilinmiyor'}",
                          style:
                              const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              onPressed: swipeLeft,
                              icon: const Icon(Icons.clear),
                              label: const Text("Geç"),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              onPressed: swipeRight,
                              icon: const Icon(Icons.favorite),
                              label: const Text("Beğen"),
                            ),
                          ],
                        )
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
