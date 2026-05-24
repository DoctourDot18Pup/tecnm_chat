import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tecnm_chat/data/models/contact_model.dart';
import 'package:tecnm_chat/data/models/user_model.dart';

sealed class ContactSearchState {
  const ContactSearchState();
}

class ContactSearchIdle extends ContactSearchState {
  const ContactSearchIdle();
}

class ContactSearchLoading extends ContactSearchState {
  const ContactSearchLoading();
}

class ContactSearchFound extends ContactSearchState {
  final UserModel user;
  const ContactSearchFound(this.user);
}

class ContactSearchNotFound extends ContactSearchState {
  const ContactSearchNotFound();
}

class ContactSearchError extends ContactSearchState {
  final String message;
  const ContactSearchError(this.message);
}

class ContactsController extends StateNotifier<ContactSearchState> {
  ContactsController() : super(const ContactSearchIdle());

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> searchByPhone(String phoneNumber) async {
    state = const ContactSearchLoading();
    try {
      final normalized = phoneNumber.startsWith('+')
          ? phoneNumber
          : '+52$phoneNumber';

      final snapshot = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: normalized)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        state = const ContactSearchNotFound();
      } else {
        final user = UserModel.fromJson(snapshot.docs.first.data());
        if (user.uid == _auth.currentUser!.uid) {
          state = const ContactSearchNotFound();
        } else {
          state = ContactSearchFound(user);
        }
      }
    } catch (e) {
      state = ContactSearchError('Error al buscar: ${e.toString()}');
    }
  }

  Future<void> searchByEmail(String email) async {
    state = const ContactSearchLoading();
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('institutionalEmail', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        state = const ContactSearchNotFound();
      } else {
        final user = UserModel.fromJson(snapshot.docs.first.data());
        if (user.uid == _auth.currentUser!.uid) {
          state = const ContactSearchNotFound();
        } else {
          state = ContactSearchFound(user);
        }
      }
    } catch (e) {
      state = ContactSearchError('Error al buscar: ${e.toString()}');
    }
  }

  Future<void> addContact(String contactUid) async {
    try {
      final myUid = _auth.currentUser!.uid;
      final contact = ContactModel(uid: contactUid, addedAt: DateTime.now());

      await _firestore
          .collection('users')
          .doc(myUid)
          .collection('contacts')
          .doc(contactUid)
          .set(contact.toJson());
    } catch (e) {
      state = ContactSearchError('Error al agregar contacto: ${e.toString()}');
    }
  }

  void reset() => state = const ContactSearchIdle();
}

final contactsControllerProvider =
    StateNotifierProvider<ContactsController, ContactSearchState>(
  (_) => ContactsController(),
);

final contactsListProvider = StreamProvider<List<UserModel>>((ref) {
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return const Stream.empty();

  final firestore = FirebaseFirestore.instance;

  return firestore
      .collection('users')
      .doc(myUid)
      .collection('contacts')
      .snapshots()
      .asyncMap((snapshot) async {
    final uids = snapshot.docs.map((d) => d.id).toList();
    if (uids.isEmpty) return <UserModel>[];

    final users = <UserModel>[];
    for (final uid in uids) {
      final doc = await firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        users.add(UserModel.fromJson(doc.data()!));
      }
    }
    users.sort((a, b) => a.displayName.compareTo(b.displayName));
    return users;
  });
});
