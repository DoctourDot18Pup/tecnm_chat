import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String id;
  final String authorUid;
  final String mediaUrl;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy;

  const StoryModel({
    required this.id,
    required this.authorUid,
    required this.mediaUrl,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.viewedBy,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory StoryModel.fromJson(Map<String, dynamic> json, String docId) {
    return StoryModel(
      id: docId,
      authorUid: json['authorUid'] as String,
      mediaUrl: json['mediaUrl'] as String,
      caption: json['caption'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      expiresAt: (json['expiresAt'] as Timestamp).toDate(),
      viewedBy: List<String>.from(json['viewedBy'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'authorUid': authorUid,
      'mediaUrl': mediaUrl,
      'caption': caption,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewedBy': viewedBy,
    };
  }
}
