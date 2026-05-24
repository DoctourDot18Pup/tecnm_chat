import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tecnm_chat/core/constants/app_constants.dart';
import 'package:tecnm_chat/data/models/board_post_model.dart';
import 'package:tecnm_chat/data/repositories/cloudinary_service.dart';

final boardPostsProvider = StreamProvider<List<BoardPostModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('board_posts')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => BoardPostModel.fromJson(d.data(), d.id))
          .toList());
});

final boardControllerProvider =
    StateNotifierProvider<BoardController, AsyncValue<void>>(
  (_) => BoardController(),
);

class BoardController extends StateNotifier<AsyncValue<void>> {
  BoardController() : super(const AsyncData(null));

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> createPost({
    required String title,
    required String body,
    required String type,
    DateTime? deadline,
    String? groupId,
    File? attachmentFile,
    String? attachmentName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    state = const AsyncLoading();
    try {
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final authorName =
          userDoc.data()?['displayName'] as String? ?? 'Docente';

      String? fileUrl;
      if (attachmentFile != null) {
        fileUrl = await CloudinaryService().uploadFile(
          attachmentFile,
          AppConstants.folderFiles,
        );
      }

      final post = BoardPostModel(
        id: '',
        authorUid: user.uid,
        authorName: authorName,
        groupId: groupId,
        title: title,
        body: body,
        type: type,
        deadline: deadline,
        readBy: [user.uid],
        totalParticipants: 0,
        createdAt: DateTime.now(),
        fileUrl: fileUrl,
        fileName: attachmentName,
      );

      await _firestore.collection('board_posts').add(post.toJson());
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> markAsRead(String postId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('board_posts').doc(postId).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }
}
