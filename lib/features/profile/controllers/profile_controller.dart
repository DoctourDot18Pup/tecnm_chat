import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tecnm_chat/data/models/user_model.dart';
import 'package:tecnm_chat/data/repositories/cloudinary_service.dart';
import 'package:tecnm_chat/core/constants/app_constants.dart';

sealed class ProfileState {
  const ProfileState();
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileSaved extends ProfileState {
  const ProfileSaved();
}

class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
}

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController() : super(const ProfileInitial());

  final _cloudinary = CloudinaryService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<File?> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 70,
      minWidth: 512,
      minHeight: 512,
    );

    if (result == null) return null;
    return File(result.path);
  }

  Future<void> saveProfile({
    required String displayName,
    required String institutionalEmail,
    required String role,
    required String career,
    int? semester,
    File? avatarFile,
  }) async {
    state = const ProfileLoading();

    try {
      final uid = _auth.currentUser!.uid;
      final phone = _auth.currentUser!.phoneNumber ?? '';

      String? avatarUrl;
      if (avatarFile != null) {
        final compressed = await compressImage(avatarFile) ?? avatarFile;
        avatarUrl = await _cloudinary.uploadFile(
          compressed,
          AppConstants.folderAvatars,
        );
      }

      final user = UserModel(
        uid: uid,
        phoneNumber: phone,
        institutionalEmail: institutionalEmail,
        displayName: displayName,
        avatarUrl: avatarUrl,
        role: role,
        career: career,
        semester: role == AppConstants.roleStudent ? semester : null,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(user.toJson());
      state = const ProfileSaved();
    } catch (e) {
      state = ProfileError('Error al guardar el perfil: ${e.toString()}');
    }
  }

  Future<void> updateProfile({
    required String displayName,
    required String institutionalEmail,
    required String career,
    int? semester,
    File? avatarFile,
  }) async {
    state = const ProfileLoading();

    try {
      final uid = _auth.currentUser!.uid;
      final updates = <String, dynamic>{
        'displayName': displayName,
        'institutionalEmail': institutionalEmail,
        'career': career,
        'semester': semester,
      };

      if (avatarFile != null) {
        final compressed = await compressImage(avatarFile) ?? avatarFile;
        updates['avatarUrl'] = await _cloudinary.uploadFile(
          compressed,
          AppConstants.folderAvatars,
        );
      }

      await _firestore.collection('users').doc(uid).update(updates);
      state = const ProfileSaved();
    } catch (e) {
      state = ProfileError('Error al actualizar el perfil: ${e.toString()}');
    }
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>(
  (_) => ProfileController(),
);

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromJson(doc.data()!);
  });
});
