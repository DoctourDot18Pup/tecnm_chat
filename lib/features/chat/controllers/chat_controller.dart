import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tecnm_chat/core/constants/app_constants.dart';
import 'package:tecnm_chat/data/models/conversation_model.dart';
import 'package:tecnm_chat/data/models/message_model.dart';
import 'package:tecnm_chat/data/repositories/cloudinary_service.dart';

/// UIDs de participantes que están escribiendo actualmente (excluye al usuario local).
final typingProvider =
    StreamProvider.family<List<String>, String>((ref, conversationId) {
  return FirebaseFirestore.instance
      .collection('conversations')
      .doc(conversationId)
      .snapshots()
      .map((snap) {
    final data = snap.data();
    if (data == null) return <String>[];
    final typingMap = data['typingUsers'] as Map<String, dynamic>? ?? {};
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(seconds: 5)),
    );
    return typingMap.entries
        .where((e) {
          final ts = e.value;
          return ts is Timestamp && ts.compareTo(cutoff) >= 0;
        })
        .map((e) => e.key)
        .toList();
  });
});

final messagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, conversationId) {
  return FirebaseFirestore.instance
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => MessageModel.fromJson(d.data(), d.id))
            .toList(),
      );
});

final conversationProvider =
    StreamProvider.family<ConversationModel?, String>((ref, id) {
  return FirebaseFirestore.instance
      .collection('conversations')
      .doc(id)
      .snapshots()
      .map((snap) {
    if (!snap.exists || snap.data() == null) return null;
    return ConversationModel.fromJson(snap.data()!, snap.id);
  });
});

class ChatController {
  final String conversationId;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _cloudinary = CloudinaryService();

  ChatController(this.conversationId);

  String get _myUid => _auth.currentUser!.uid;

  Future<void> sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;

    final isEmojiOnly = _isOnlyEmoji(text.trim());
    final type = isEmojiOnly ? AppConstants.msgEmoji : AppConstants.msgText;

    await _saveMessage(content: text.trim(), type: type);
  }

  Future<void> sendImageMessage(File imageFile) async {
    final compressed = await _compressImage(imageFile);
    final url = await _cloudinary.uploadFile(
      compressed ?? imageFile,
      AppConstants.folderChatMedia,
    );
    await _saveMessage(
      content: '📷 Imagen',
      type: AppConstants.msgImage,
      mediaUrl: url,
    );
  }

  Future<void> setTyping(bool isTyping) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'typingUsers.$_myUid': isTyping
            ? FieldValue.serverTimestamp()
            : FieldValue.delete(),
      });
    } catch (_) {}
  }

  Future<void> sendFileMessage(File file, String fileName) async {
    final url = await _cloudinary.uploadFile(
      file,
      AppConstants.folderChatMedia,
    );
    await _saveMessage(
      content: fileName,
      type: AppConstants.msgFile,
      mediaUrl: url,
    );
  }

  Future<void> sendVideoMessage(File videoFile) async {
    final url = await _cloudinary.uploadFile(
      videoFile,
      AppConstants.folderChatMedia,
    );
    await _saveMessage(
      content: '🎥 Video',
      type: AppConstants.msgVideo,
      mediaUrl: url,
    );
  }

  Future<void> markAsRead() async {
    final myUid = _myUid;
    final messages = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('senderUid', isNotEqualTo: myUid)
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] as List? ?? []);
      if (!readBy.contains(myUid)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([myUid]),
        });
      }
    }
    await batch.commit();
  }

  Future<void> _saveMessage({
    required String content,
    required String type,
    String? mediaUrl,
  }) async {
    final ref = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    final message = MessageModel(
      id: ref.id,
      conversationId: conversationId,
      senderUid: _myUid,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      createdAt: DateTime.now(),
      readBy: [_myUid],
    );

    final batch = _firestore.batch();
    batch.set(ref, message.toJson());
    batch.update(
      _firestore.collection('conversations').doc(conversationId),
      {
        'lastMessage': content,
        'lastMessageAt': Timestamp.fromDate(message.createdAt),
      },
    );
    await batch.commit();
  }

  Future<File?> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/chat_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 65,
      minWidth: 1024,
      minHeight: 1024,
    );

    if (result == null) return null;
    return File(result.path);
  }

  bool _isOnlyEmoji(String text) {
    final emojiPattern = RegExp(
      r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}'
      r'\u{1F000}-\u{1F02F}\u{1F0A0}-\u{1F0FF}'
      r'\u{1F100}-\u{1F1FF}\u{1F200}-\u{1F2FF}'
      r'\s]+$',
      unicode: true,
    );
    return emojiPattern.hasMatch(text) && text.isNotEmpty;
  }
}

final chatControllerProvider =
    Provider.family<ChatController, String>((_, conversationId) {
  return ChatController(conversationId);
});
