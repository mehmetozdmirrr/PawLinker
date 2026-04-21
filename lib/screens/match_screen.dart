import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swipe_cards/swipe_cards.dart';

import 'pet_detail_screen.dart';
import 'chat_list_screen.dart'; // dosya adın bu kalsın

/// İki kullanıcı UID'sini alfabetik sıralayıp deterministik chatId üretir
String chatIdFor(String a, String b) {
  final list = [a, b]..sort();
  return '${list[0]}_${list[1]}';
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  List<SwipeItem> _swipeItems = [];
  MatchEngine? _matchEngine;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPets();
  }

  Future<void> fetchPets() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Kullanıcının pet türü
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userType =
          (userDoc.data()?['pet']?['type'] as String?)?.toLowerCase();
      if (userType == null) {
        debugPrint("❌ Kullanıcının türü (type) yok.");
        setState(() => isLoading = false);
        return;
      }

      // Kullanıcının daha önce beğendiği petId'ler
      final likesSnap = await FirebaseFirestore.instance
          .collection('likes')
          .where('likerId', isEqualTo: user.uid)
          .get();
      final likedPetIds =
          likesSnap.docs.map((d) => d.data()['petId'] as String).toSet();

      // Aynı türdeki tüm pet'leri çek
      final snapshot = await FirebaseFirestore.instance
          .collection('pets')
          .where('type', isEqualTo: userType)
          .get();

      // Kendine ait olmayan ve daha önce beğenmediğin kartları hazırla
      final pets = snapshot.docs
          .where((d) {
            final data = d.data();
            return data['ownerId'] != user.uid && !likedPetIds.contains(d.id);
          })
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

      _swipeItems = pets
          .map(
            (pet) => SwipeItem(
              content: pet,
              likeAction: () => saveLike(pet),
              nopeAction: () {},
            ),
          )
          .toList();

      _matchEngine = MatchEngine(swipeItems: _swipeItems);
      setState(() => isLoading = false);
    } catch (e) {
      debugPrint("❌ Firestore hatası: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> saveLike(Map<String, dynamic> pet) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final petId = pet['id'] as String;
    final me = user.uid;
    final other = pet['ownerId'] as String;

    // 1) Beğeniyi kaydet (petId tabanlı)
    await FirebaseFirestore.instance.collection('likes').add({
      'likerId': me,
      'petId': petId,
      'ownerId': other,
      'likedAt': FieldValue.serverTimestamp(),
    });

    // 2) Karşı taraf seni daha önce beğendiyse eşleşme + chat
    final mutual = await FirebaseFirestore.instance
        .collection('likes')
        .where('likerId', isEqualTo: other)
        .where('ownerId', isEqualTo: me)
        .limit(1)
        .get();

    if (mutual.docs.isNotEmpty) {
      // Karşı tarafın like dokümanı (benim petimi beğendiği kayıt)
      final mutualData = mutual.docs.first.data();
      final myPetId = mutualData['petId'] as String?;
      final otherPetId = petId; // şu an beğendiğim pet

      // Kullanıcı isimlerini çek
      final meUserSnap =
          await FirebaseFirestore.instance.collection('users').doc(me).get();
      final otherUserSnap =
          await FirebaseFirestore.instance.collection('users').doc(other).get();

      final meName = (meUserSnap.data()?['name'] as String?) ?? '';
      final otherName = (otherUserSnap.data()?['name'] as String?) ?? '';

      // Pet isimlerini çek
      String myPetName = '';
      if (myPetId != null && myPetId.isNotEmpty) {
        final myPetSnap = await FirebaseFirestore.instance
            .collection('pets')
            .doc(myPetId)
            .get();
        myPetName = (myPetSnap.data()?['name'] as String?) ?? '';
      }

      String otherPetName = '';
      final otherPetSnap = await FirebaseFirestore.instance
          .collection('pets')
          .doc(otherPetId)
          .get();
      otherPetName = (otherPetSnap.data()?['name'] as String?) ?? '';

      // Kullanıcıları alfabetik sıraya koy
      final usersSorted = [me, other]..sort();

      // Aynı sıraya göre pet ve isim dizilerini hizala
      late final List<String> petIds;
      late final List<String> petNames;
      late final List<String> userNames;

      if (usersSorted[0] == me) {
        petIds = [myPetId ?? '', otherPetId];
        petNames = [myPetName, otherPetName];
        userNames = [meName, otherName];
      } else {
        petIds = [otherPetId, myPetId ?? ''];
        petNames = [otherPetName, myPetName];
        userNames = [otherName, meName];
      }

      // a) Match kaydı
      await FirebaseFirestore.instance.collection('matches').add({
        'users': usersSorted,
        'petIds': petIds,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // b) Chat odasını (upsert) oluştur/güncelle
      final chatId = chatIdFor(me, other);
      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc(chatId);

      await chatRef.set(
        {
          'users': usersSorted,
          'userNames': userNames,
          'petIds': petIds,
          'petNames': petNames,
          'lastMessage': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "🎉 ${pet['name']} ile eşleştiniz! Sohbete başlayabilirsiniz."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Eşleşme Ekranı"),
        actions: [
          // Sohbet listesi
          IconButton(
            tooltip: 'Sohbetler',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatsScreen()),
              );
            },
          ),
          // Çıkış
          IconButton(
            tooltip: 'Çıkış yap',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: _swipeItems.isEmpty
          ? const Center(child: Text("Gösterilecek hayvan kalmadı"))
          : SwipeCards(
              matchEngine: _matchEngine!,
              itemBuilder: (BuildContext context, int index) {
                final pet = _swipeItems[index].content;
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PetDetailScreen(pet: pet),
                      ),
                    );
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: Image.network(
                            pet['image'],
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            // 403 hatalarına karşı placeholder
                            errorBuilder: (_, __, ___) => Container(
                              height: 250,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.pets,
                                  size: 64, color: Colors.grey),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                pet['name'],
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Tür: ${pet['type']} | Yaş: ${pet['age'] ?? 'Bilinmiyor'}",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              onStackFinished: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Tüm hayvanlar görüntülendi.")),
                );
              },
              upSwipeAllowed: false,
              fillSpace: true,
            ),
    );
  }
}
