import 'package:cloud_firestore/cloud_firestore.dart';

class ContactModel {
  final String uid;
  final DateTime addedAt;

  const ContactModel({
    required this.uid,
    required this.addedAt,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      uid: json['uid'] as String,
      addedAt: (json['addedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }
}
