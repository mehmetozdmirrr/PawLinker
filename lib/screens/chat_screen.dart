import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String peerId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.peerId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  final _picker = ImagePicker();

  bool sending = false;
  bool sendingImage = false;
  Timer? _typingDebounce;

  // messages/{chatId}/items/{messageId}
  CollectionReference<Map<String, dynamic>> get _messagesCol =>
      FirebaseFirestore.instance
          .collection('messages')
          .doc(widget.chatId)
          .collection('items');

  @override
  void dispose() {
    _typingDebounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  // ------------------ TYPING ------------------

  Future<void> _updateTyping(bool isTyping) async {
    final me = FirebaseAuth.instance.currentUser!.uid;
    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

    try {
      // Asıl istediğimiz: typing: { uid: true/false }
      await chatRef.update({
        'typing.$me': isTyping,
      });
    } catch (_) {
      // Doküman yoksa vs. – merge ile oluştur
      await chatRef.set(
        {
          'typing': {me: isTyping},
        },
        SetOptions(merge: true),
      );
    }
  }

  void _onTextChanged(String value) {
    final hasText = value.trim().isNotEmpty;

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 400), () {
      _updateTyping(hasText);
    });
  }

  // ------------------ MESAJ GÖNDERME ------------------

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);

    final me = FirebaseAuth.instance.currentUser!.uid;
    final now = FieldValue.serverTimestamp();

    final batch = FirebaseFirestore.instance.batch();

    final msgRef = _messagesCol.doc();
    batch.set(msgRef, {
      'senderId': me,
      'text': text,
      'imageUrl': null,
      'createdAt': now,
    });

    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    batch.set(
      chatRef,
      {
        'lastMessage': text,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    controller.clear();
    _updateTyping(false);

    if (mounted) setState(() => sending = false);
  }

  Future<void> sendImage() async {
    if (sendingImage) return;
    setState(() => sendingImage = true);

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (picked == null) {
        setState(() => sendingImage = false);
        return;
      }

      final me = FirebaseAuth.instance.currentUser!.uid;
      final now = FieldValue.serverTimestamp();

      // Mesaj dokümanını önceden oluştur ki id'yi kullanabilelim
      final msgRef = _messagesCol.doc();

      // Storage path: chatImages/{chatId}/{messageId}.jpg
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chatImages')
          .child(widget.chatId)
          .child('${msgRef.id}.jpg');

      final file = File(picked.path);
      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();

      final batch = FirebaseFirestore.instance.batch();

      batch.set(msgRef, {
        'senderId': me,
        'text': '',
        'imageUrl': url,
        'createdAt': now,
      });

      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      batch.set(
        chatRef,
        {
          'lastMessage': '📷 Fotoğraf',
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      debugPrint('sendImage error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf gönderilemedi')),
        );
      }
    } finally {
      if (mounted) setState(() => sendingImage = false);
    }
  }

  /// Karşı tarafın mesajlarını "görüldü" işaretler
  Future<void> _markMessagesAsSeen(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> msgs,
    String myUid,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    bool hasUpdate = false;

    for (final doc in msgs) {
      final data = doc.data();
      // Sadece karşı tarafın attığı mesajlar için
      if (data['senderId'] == myUid) continue;

      final seenBy = List<String>.from(data['seenBy'] ?? const []);
      if (!seenBy.contains(myUid)) {
        batch.update(doc.reference, {
          'seenBy': FieldValue.arrayUnion([myUid]),
        });
        hasUpdate = true;
      }
    }

    if (hasUpdate) {
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Önce chat meta bilgisini dinleyelim (isimler, petler vs.)
    final chatDocStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: chatDocStream,
      builder: (context, chatSnap) {
        final chatData = chatSnap.data?.data();

        String peerId = widget.peerId;
        String title = 'Sohbet';
        String petLine = '';
        String? peerPetId;
        bool peerTyping = false;

        if (chatData != null) {
          final users = List<String>.from(chatData['users'] ?? const []);
          final userNames =
              List<String>.from(chatData['userNames'] ?? const []);
          final petNames = List<String>.from(chatData['petNames'] ?? const []);
          final petIds = List<String>.from(chatData['petIds'] ?? const []);

          final meIndex = users.indexOf(uid);
          final peerIndex = meIndex == 0 ? 1 : 0;

          if (peerIndex >= 0 && peerIndex < users.length) {
            peerId = users[peerIndex];
          }

          String peerName = (peerIndex >= 0 && peerIndex < userNames.length)
              ? userNames[peerIndex]
              : (peerId.isEmpty ? 'Kullanıcı' : peerId.substring(0, 6));

          String myPetName = (meIndex >= 0 && meIndex < petNames.length)
              ? petNames[meIndex]
              : '';
          String peerPetName = (peerIndex >= 0 && peerIndex < petNames.length)
              ? petNames[peerIndex]
              : '';

          if (peerIndex >= 0 && peerIndex < petIds.length) {
            peerPetId = petIds[peerIndex];
          }

          title = peerName;
          if (myPetName.isNotEmpty || peerPetName.isNotEmpty) {
            petLine = "${myPetName.isNotEmpty ? myPetName : 'Pet'} 🐾 "
                "${peerPetName.isNotEmpty ? peerPetName : 'Pet'}";
          }

          // ---- YAZIYOR MU? ----
          if (peerId.isNotEmpty) {
            final typingField = chatData['typing'];

            // 1) Normal map: typing: { uid: true/false }
            if (typingField is Map) {
              final v = typingField[peerId];
              if (v is bool && v == true) {
                peerTyping = true;
              }
            }

            // 2) Eski/düz alan: "typing.uid": true/false
            if (!peerTyping) {
              final flatKey = 'typing.$peerId';
              final flatValue = chatData[flatKey];
              if (flatValue is bool && flatValue == true) {
                peerTyping = true;
              }
            }
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                if (petLine.isNotEmpty)
                  Text(
                    petLine,
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Profili gör',
                icon: const Icon(Icons.info_outline),
                onPressed: chatData == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: peerId,
                              petId: peerPetId,
                            ),
                          ),
                        );
                      },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messagesCol
                      .orderBy('createdAt', descending: true)
                      .limit(200)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final msgs = snap.data?.docs ?? [];

                    // Mesajları okundu işaretle
                    if (msgs.isNotEmpty) {
                      _markMessagesAsSeen(msgs, uid);
                    }

                    // En son benim attığım mesaj + görüldü mü
                    String? lastMyMsgId;
                    bool lastMyMsgSeen = false;

                    for (final doc in msgs) {
                      final data = doc.data();
                      if (data['senderId'] == uid) {
                        lastMyMsgId = doc.id;
                        final seenBy =
                            List<String>.from(data['seenBy'] ?? const []);
                        if (peerId.isNotEmpty) {
                          lastMyMsgSeen = seenBy.contains(peerId);
                        }
                        break;
                      }
                    }

                    if (msgs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pets,
                                  size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                '$title ile eşleştiniz!',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (petLine.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  petLine,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Text(
                                'Sohbete başlamak için bir merhaba yaz 😊',
                                style: TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      itemCount: msgs.length,
                      itemBuilder: (context, i) {
                        final doc = msgs[i];
                        final m = doc.data();
                        final mine = m['senderId'] == uid;

                        final String text = (m['text'] ?? '') as String;
                        final String? imageUrl = m['imageUrl'] as String?;

                        // Saat formatlama
                        final createdAt = m['createdAt'];
                        DateTime? dt;
                        if (createdAt is Timestamp) {
                          dt = createdAt.toDate();
                        }
                        String timeStr = '';
                        if (dt != null) {
                          final h = dt.hour.toString().padLeft(2, '0');
                          final min = dt.minute.toString().padLeft(2, '0');
                          timeStr = '$h:$min';
                        }

                        final isLastMyMsg =
                            lastMyMsgId != null && doc.id == lastMyMsgId;

                        Widget content;
                        if (imageUrl != null && imageUrl.isNotEmpty) {
                          content = GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  child: InteractiveViewer(
                                    child: Image.network(imageUrl),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl,
                                width: MediaQuery.of(context).size.width * 0.6,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        } else {
                          content = Text(text);
                        }

                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? Colors.teal.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: mine
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                content,
                                if (timeStr.isNotEmpty ||
                                    (mine && isLastMyMsg && lastMyMsgSeen)) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (timeStr.isNotEmpty)
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      if (mine &&
                                          isLastMyMsg &&
                                          lastMyMsgSeen) ...[
                                        if (timeStr.isNotEmpty)
                                          const SizedBox(width: 6),
                                        Text(
                                          'Görüldü',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade800,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Karşı taraf yazıyorsa
              if (peerTyping)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$title yazıyor…',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),

              SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Fotoğraf butonu
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 12, bottom: 12, right: 4),
                      child: IconButton(
                        onPressed: sendingImage ? null : sendImage,
                        icon: sendingImage
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 8, 8, 12),
                        child: TextField(
                          controller: controller,
                          onChanged: _onTextChanged,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => send(),
                          decoration: const InputDecoration(
                            hintText: 'Mesaj yaz…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 12),
                      child: FilledButton(
                        onPressed: sending ? null : send,
                        child: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
