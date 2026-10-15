import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/journal.dart';

class JournalRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _journalsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('journals');
  }

  Future<void> createJournal(Journal journal) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    
    await _journalsRef(user.uid).doc(journal.id).set(journal.toMap());
  }

  Stream<List<Journal>> getJournals() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _journalsRef(user.uid).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Journal.fromMap(doc.id, doc.data())).toList();
    });
  }

  Future<void> deleteJournal(String journalId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    
    await _journalsRef(user.uid).doc(journalId).delete();
  }
}
