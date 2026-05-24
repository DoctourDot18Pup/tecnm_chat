import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tecnm_chat/core/constants/app_constants.dart';
import 'package:tecnm_chat/data/models/story_model.dart';
import 'package:tecnm_chat/data/repositories/cloudinary_service.dart';

sealed class StoryUploadState {
  const StoryUploadState();
}

class StoryIdle extends StoryUploadState {
  const StoryIdle();
}

class StoryUploading extends StoryUploadState {
  const StoryUploading();
}

class StoryUploaded extends StoryUploadState {
  const StoryUploaded();
}

class StoryError extends StoryUploadState {
  final String message;
  const StoryError(this.message);
}

class StoriesController extends StateNotifier<StoryUploadState> {
  StoriesController() : super(const StoryIdle());

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _cloudinary = CloudinaryService();

  Future<void> uploadStory({
    required File mediaFile,
    String? caption,
    required bool isImage,
  }) async {
    state = const StoryUploading();

    try {
      final myUid = _auth.currentUser!.uid;

      File fileToUpload = mediaFile;
      if (isImage) {
        final compressed = await _compressImage(mediaFile);
        if (compressed != null) fileToUpload = compressed;
      }

      final mediaUrl = await _cloudinary.uploadFile(
        fileToUpload,
        AppConstants.folderStories,
      );

      final now = DateTime.now();
      final ref = _firestore.collection('stories').doc();

      final story = StoryModel(
        id: ref.id,
        authorUid: myUid,
        mediaUrl: mediaUrl,
        caption: caption?.trim().isEmpty == true ? null : caption?.trim(),
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        viewedBy: [],
      );

      await ref.set(story.toJson());
      state = const StoryUploaded();
    } catch (e) {
      state = StoryError('Error al publicar el story: ${e.toString()}');
    }
  }

  Future<void> markAsViewed(String storyId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    await _firestore.collection('stories').doc(storyId).update({
      'viewedBy': FieldValue.arrayUnion([myUid]),
    });
  }

  Future<File?> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/story_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 75,
      minWidth: 1080,
      minHeight: 1920,
    );

    if (result == null) return null;
    return File(result.path);
  }
}

final storiesControllerProvider =
    StateNotifierProvider<StoriesController, StoryUploadState>(
  (_) => StoriesController(),
);

final contactStoriesProvider = StreamProvider<Map<String, List<StoryModel>>>(
  (ref) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return Stream.value({});

    final now = Timestamp.fromDate(DateTime.now());

    return FirebaseFirestore.instance
        .collection('stories')
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt')
        .snapshots()
        .map((snap) {
      final stories = snap.docs
          .map((d) => StoryModel.fromJson(d.data(), d.id))
          .where((s) => !s.isExpired)
          .toList();

      final Map<String, List<StoryModel>> grouped = {};
      for (final story in stories) {
        grouped.putIfAbsent(story.authorUid, () => []).add(story);
      }
      return grouped;
    });
  },
);

final myStoriesProvider = StreamProvider<List<StoryModel>>((ref) {
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return Stream.value([]);

  final now = Timestamp.fromDate(DateTime.now());

  return FirebaseFirestore.instance
      .collection('stories')
      .where('authorUid', isEqualTo: myUid)
      .where('expiresAt', isGreaterThan: now)
      .orderBy('expiresAt')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => StoryModel.fromJson(d.data(), d.id))
            .where((s) => !s.isExpired)
            .toList(),
      );
});
