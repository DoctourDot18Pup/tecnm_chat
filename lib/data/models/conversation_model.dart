import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool isGroup;
  final String? groupName;
  final String? groupAvatarUrl;
  final bool hidePhoneNumbers;
  final String? adminUid;

  const ConversationModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
    required this.isGroup,
    this.groupName,
    this.groupAvatarUrl,
    this.hidePhoneNumbers = false,
    this.adminUid,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json, String docId) {
    return ConversationModel(
      id: docId,
      participants: List<String>.from(json['participants'] as List),
      lastMessage: json['lastMessage'] as String?,
      lastMessageAt: json['lastMessageAt'] != null
          ? (json['lastMessageAt'] as Timestamp).toDate()
          : null,
      isGroup: json['isGroup'] as bool? ?? false,
      groupName: json['groupName'] as String?,
      groupAvatarUrl: json['groupAvatarUrl'] as String?,
      hidePhoneNumbers: json['hidePhoneNumbers'] as bool? ?? false,
      adminUid: json['adminUid'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageAt':
          lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupAvatarUrl': groupAvatarUrl,
      'hidePhoneNumbers': hidePhoneNumbers,
      'adminUid': adminUid,
    };
  }

  String displayName(String myUid, Map<String, String> userNames) {
    if (isGroup) return groupName ?? 'Grupo';
    final otherUid = participants.firstWhere(
      (uid) => uid != myUid,
      orElse: () => myUid,
    );
    return userNames[otherUid] ?? 'Usuario';
  }
}
