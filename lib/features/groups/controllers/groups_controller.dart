import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tecnm_chat/core/constants/app_constants.dart';
import 'package:tecnm_chat/data/models/conversation_model.dart';
import 'package:tecnm_chat/data/repositories/cloudinary_service.dart';

sealed class GroupState {
  const GroupState();
}

class GroupInitial extends GroupState {
  const GroupInitial();
}

class GroupLoading extends GroupState {
  const GroupLoading();
}

class GroupCreated extends GroupState {
  final String conversationId;
  const GroupCreated(this.conversationId);
}

class GroupError extends GroupState {
  final String message;
  const GroupError(this.message);
}

class GroupsController extends StateNotifier<GroupState> {
  GroupsController() : super(const GroupInitial());

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _cloudinary = CloudinaryService();

  Future<void> createGroup({
    required String groupName,
    required List<String> participantUids,
    bool hidePhoneNumbers = false,
    File? avatarFile,
  }) async {
    state = const GroupLoading();

    try {
      final myUid = _auth.currentUser!.uid;

      // Verificar que sea profesor
      final myDoc = await _firestore.collection('users').doc(myUid).get();
      final myRole = myDoc.data()?['role'] as String?;

      if (myRole != AppConstants.roleProfessor) {
        state = const GroupError(
          'Solo los profesores pueden crear grupos.',
        );
        return;
      }

      String? avatarUrl;
      if (avatarFile != null) {
        avatarUrl = await _cloudinary.uploadFile(
          avatarFile,
          AppConstants.folderAvatars,
        );
      }

      final allParticipants = [myUid, ...participantUids];

      final ref = _firestore.collection('conversations').doc();
      final conversation = ConversationModel(
        id: ref.id,
        participants: allParticipants,
        isGroup: true,
        groupName: groupName.trim(),
        groupAvatarUrl: avatarUrl,
        hidePhoneNumbers: hidePhoneNumbers,
        adminUid: myUid,
      );

      await ref.set(conversation.toJson());
      state = GroupCreated(ref.id);
    } catch (e) {
      state = GroupError('Error al crear el grupo: ${e.toString()}');
    }
  }
}

final groupsControllerProvider =
    StateNotifierProvider<GroupsController, GroupState>(
  (_) => GroupsController(),
);

/// Agrega nuevos participantes a un grupo existente.
Future<void> addMembersToGroup({
  required String conversationId,
  required List<String> newUids,
}) async {
  await FirebaseFirestore.instance
      .collection('conversations')
      .doc(conversationId)
      .update({
    'participants': FieldValue.arrayUnion(newUids),
  });
}
