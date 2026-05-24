import 'package:cloud_firestore/cloud_firestore.dart';

class BoardPostModel {
  final String id;
  final String authorUid;
  final String authorName;
  final String? groupId;
  final String title;
  final String body;
  final String type; // tarea | aviso | examen | material
  final DateTime? deadline;
  final List<String> readBy;
  final int totalParticipants;
  final DateTime createdAt;
  final String? fileUrl;
  final String? fileName;

  const BoardPostModel({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.groupId,
    required this.title,
    required this.body,
    required this.type,
    this.deadline,
    required this.readBy,
    required this.totalParticipants,
    required this.createdAt,
    this.fileUrl,
    this.fileName,
  });

  factory BoardPostModel.fromJson(Map<String, dynamic> json, String docId) {
    return BoardPostModel(
      id: docId,
      authorUid: json['authorUid'] as String,
      authorName: json['authorName'] as String? ?? 'Docente',
      groupId: json['groupId'] as String?,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String? ?? 'aviso',
      deadline: json['deadline'] != null
          ? (json['deadline'] as Timestamp).toDate()
          : null,
      readBy: List<String>.from(json['readBy'] as List? ?? []),
      totalParticipants: json['totalParticipants'] as int? ?? 0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fileUrl: json['fileUrl'] as String?,
      fileName: json['fileName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'groupId': groupId,
        'title': title,
        'body': body,
        'type': type,
        'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
        'readBy': readBy,
        'totalParticipants': totalParticipants,
        'createdAt': FieldValue.serverTimestamp(),
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (fileName != null) 'fileName': fileName,
      };
}
