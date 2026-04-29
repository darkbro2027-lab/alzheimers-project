import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDataService {
  UserDataService._();
  static final UserDataService instance = UserDataService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  bool get isSignedIn => _uid != null;

  DocumentReference<Map<String, dynamic>> _userDoc() {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('No signed-in user.');
    }
    return _db.collection('users').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> profileDoc() =>
      _userDoc().collection('profile').doc('info');

  DocumentReference<Map<String, dynamic>> metaDoc() =>
      _userDoc().collection('meta').doc('app');

  CollectionReference<Map<String, dynamic>> medicationsCol() =>
      _userDoc().collection('medications');

  CollectionReference<Map<String, dynamic>> medicationHistoryCol() =>
      _userDoc().collection('medicationHistory');

  CollectionReference<Map<String, dynamic>> contactsCol() =>
      _userDoc().collection('contacts');

  CollectionReference<Map<String, dynamic>> cognitiveAssessmentsCol() =>
      _userDoc().collection('cognitiveAssessments');

  CollectionReference<Map<String, dynamic>> wellnessLogsCol() =>
      _userDoc().collection('wellnessLogs');

  CollectionReference<Map<String, dynamic>> notesCol() =>
      _userDoc().collection('notes');
}