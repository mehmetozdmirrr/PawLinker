import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final query = FirebaseFirestore.instance
        .collection('chats')
        .where('users', arrayContains: uid)
        .orderBy('updatedAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Sohbetler')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Henüz bir sohbet yok'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();
              final chatId = doc.id;

              final users = List<String>.from(data['users'] ?? const []);
              final userNames =
                  List<String>.from(data['userNames'] ?? const []);
              final petNames = List<String>.from(data['petNames'] ?? const []);
              final petIds = List<String>.from(data['petIds'] ?? const []);

              final me = uid;
              final meIndex = users.indexOf(me);
              final peerIndex = meIndex == 0 ? 1 : 0;

              // peerId
              final peerId = (peerIndex >= 0 && peerIndex < users.length)
                  ? users[peerIndex]
                  : '';

              // kullanıcı adı
              final peerName = (peerIndex >= 0 && peerIndex < userNames.length)
                  ? userNames[peerIndex]
                  : (peerId.isEmpty ? 'Kullanıcı' : peerId.substring(0, 6));

              // pet isimleri
              final myPetName = (meIndex >= 0 && meIndex < petNames.length)
                  ? petNames[meIndex]
                  : '';
              final peerPetName =
                  (peerIndex >= 0 && peerIndex < petNames.length)
                      ? petNames[peerIndex]
                      : '';

              // pet id (karşı tarafın hayvanı)
              final peerPetId = (peerIndex >= 0 && peerIndex < petIds.length)
                  ? petIds[peerIndex]
                  : '';

              final last = (data['lastMessage'] as String?) ?? '';

              final petLine = (myPetName.isNotEmpty || peerPetName.isNotEmpty)
                  ? "${myPetName.isNotEmpty ? myPetName : 'Pet'} 🐾 ${peerPetName.isNotEmpty ? peerPetName : 'Pet'}"
                  : '';

              // 🔹 ListTile döndürmeden önce pet fotoğrafını FutureBuilder ile çekiyoruz
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: (peerPetId.isNotEmpty)
                    ? FirebaseFirestore.instance
                        .collection('pets')
                        .doc(peerPetId)
                        .get()
                    : Future.value(null),
                builder: (context, petSnap) {
                  String? petImage;
                  if (petSnap.hasData && petSnap.data != null) {
                    final petData = petSnap.data!.data();
                    petImage = petData?['image'] as String?;
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (petImage != null && petImage.isNotEmpty)
                          ? NetworkImage(petImage)
                          : null,
                      child: (petImage == null || petImage.isEmpty)
                          ? const Icon(Icons.pets)
                          : null,
                    ),
                    title: Text(peerName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (petLine.isNotEmpty)
                          Text(
                            petLine,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        Text(
                          last.isEmpty ? 'Yeni sohbet' : last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: chatId,
                            peerId: peerId,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
