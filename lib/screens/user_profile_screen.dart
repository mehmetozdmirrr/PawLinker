import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;
  final String? petId;
  const UserProfileScreen({super.key, required this.userId, this.petId});

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final petRef = (petId != null && petId!.isNotEmpty)
        ? FirebaseFirestore.instance.collection('pets').doc(petId)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          userRef.get(),
          if (petRef != null) petRef.get(),
        ]),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData) {
            return const Center(child: Text('Veri bulunamadı'));
          }

          final userSnap =
              snap.data![0] as DocumentSnapshot<Map<String, dynamic>>;
          final userData = userSnap.data() ?? {};

          DocumentSnapshot<Map<String, dynamic>>? petSnap;
          Map<String, dynamic>? petData;
          if (snap.data!.length > 1) {
            petSnap = snap.data![1] as DocumentSnapshot<Map<String, dynamic>>;
            petData = petSnap.data();
          }

          final userName = (userData['name'] as String?) ?? 'Kullanıcı';
          final city = (userData['city'] as String?) ?? '';
          final about = (userData['about'] as String?) ?? '';
          final photoUrl = (userData['photoUrl'] as String?) ?? '';

          final petName = petData?['name'] as String?;
          final petType = petData?['type'] as String?;
          final petAge = petData?['age']?.toString();
          final petImage = petData?['image'] as String?;
          final hasPetImage = petImage != null &&
              petImage.isNotEmpty &&
              petImage.startsWith('http');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kullanıcı avatarı
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage:
                        (photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Kullanıcı adı
                Center(
                  child: Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Şehir
                if (city.isNotEmpty)
                  Center(
                    child: Text(
                      city,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),

                const SizedBox(height: 16),

                // Hakkında
                if (about.isNotEmpty) ...[
                  const Text(
                    'Hakkında',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(about),
                  const SizedBox(height: 16),
                ],

                // Pet bilgileri
                if (petData != null) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Evcil Hayvanı',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // 🔥 Pet foto - hata olursa kırmızı yazı yerine ikon çıkacak
                  if (hasPetImage)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          petImage!,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 180,
                              width: double.infinity,
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.pets,
                                size: 48,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.pets,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),
                  if (petName != null) Text('İsim: $petName'),
                  if (petType != null) Text('Tür: $petType'),
                  if (petAge != null) Text('Yaş: $petAge'),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
