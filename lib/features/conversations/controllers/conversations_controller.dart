import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tecnm_chat/data/models/conversation_model.dart';
import 'package:tecnm_chat/data/models/user_model.dart';

final conversationsProvider = StreamProvider<List<ConversationModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('conversations')
      .where('participants', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => ConversationModel.fromJson(d.data(), d.id))
            .toList(),
      );
});

final unreadCountProvider =
    StreamProvider.family<int, String>((ref, conversationId) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .where('readBy', whereNotIn: [
        [uid]
      ])
      .snapshots()
      .map((snap) => snap.docs.where((d) {
            final readBy = List<String>.from(d.data()['readBy'] as List? ?? []);
            final senderUid = d.data()['senderUid'] as String?;
            return !readBy.contains(uid) && senderUid != uid;
          }).length);
});

Future<String> createDirectConversation(String otherUid) async {
  final myUid = FirebaseAuth.instance.currentUser!.uid;
  final firestore = FirebaseFirestore.instance;

  final existing = await firestore
      .collection('conversations')
      .where('participants', arrayContains: myUid)
      .where('isGroup', isEqualTo: false)
      .get();

  for (final doc in existing.docs) {
    final participants =
        List<String>.from(doc.data()['participants'] as List? ?? []);
    if (participants.contains(otherUid) && participants.length == 2) {
      return doc.id;
    }
  }

  final ref = firestore.collection('conversations').doc();
  final conversation = ConversationModel(
    id: ref.id,
    participants: [myUid, otherUid],
    isGroup: false,
  );
  await ref.set(conversation.toJson());
  return ref.id;
}

final conversationParticipantsProvider =
    FutureProvider.family<Map<String, UserModel>, String>(
  (ref, uidsKey) async {
    final uids = uidsKey.split(',').where((s) => s.isNotEmpty).toList();
    final firestore = FirebaseFirestore.instance;
    final result = <String, UserModel>{};
    for (final uid in uids) {
      final doc = await firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        result[uid] = UserModel.fromJson(doc.data()!);
      }
    }
    return result;
  },
);
