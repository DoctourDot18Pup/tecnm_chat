import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String conversationId;
  final String senderUid;
  final String content;
  final String type;
  final String? mediaUrl;
  final DateTime createdAt;
  final List<String> readBy;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderUid,
    required this.content,
    required this.type,
    this.mediaUrl,
    required this.createdAt,
    required this.readBy,
  });

  bool get isTextOnly => type == 'text';
  bool get isEmojiOnly => type == 'emoji';
  bool get hasMedia => mediaUrl != null;

  factory MessageModel.fromJson(Map<String, dynamic> json, String docId) {
    return MessageModel(
      id: docId,
      conversationId: json['conversationId'] as String,
      senderUid: json['senderUid'] as String,
      content: json['content'] as String,
      type: json['type'] as String,
      mediaUrl: json['mediaUrl'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      readBy: List<String>.from(json['readBy'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'senderUid': senderUid,
      'content': content,
      'type': type,
      'mediaUrl': mediaUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'readBy': readBy,
    };
  }
}
