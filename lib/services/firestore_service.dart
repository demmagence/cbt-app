import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'cbt-db',
  );

  // Collection Paths
  static const String usersPath = 'users';
  static const String examsPath = 'exams';
  static const String examSessionsPath = 'exam_sessions';
  static const String examResultsPath = 'exam_results';
  static const String questionBankPath = 'question_bank';

  // Helper to get questions subcollection path for an exam
  String questionsPath(String examId) => 'exams/$examId/questions';

  // Generic Get Document
  Future<T?> getDocument<T>({
    required String path,
    required String docId,
    required T Function(Map<String, dynamic> json, String id) fromJson,
  }) async {
    final doc = await _db.collection(path).doc(docId).get();
    if (doc.exists && doc.data() != null) {
      return fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  // Generic Get Collection
  Future<List<T>> getCollection<T>({
    required String path,
    required T Function(Map<String, dynamic> json, String id) fromJson,
    Query Function(Query query)? queryBuilder,
  }) async {
    Query query = _db.collection(path);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    final querySnapshot = await query.get();
    return querySnapshot.docs.map((doc) {
      return fromJson(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  // Generic Stream Collection (for real-time queries)
  Stream<List<T>> streamCollection<T>({
    required String path,
    required T Function(Map<String, dynamic> json, String id) fromJson,
    Query Function(Query query)? queryBuilder,
  }) {
    Query query = _db.collection(path);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Generic Stream Document
  Stream<T?> streamDocument<T>({
    required String path,
    required String docId,
    required T Function(Map<String, dynamic> json, String id) fromJson,
  }) {
    return _db.collection(path).doc(docId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return fromJson(doc.data()!, doc.id);
      }
      return null;
    });
  }

  // Generic Add Document (set or add)
  Future<void> addDocument({
    required String path,
    required Map<String, dynamic> data,
    String? docId,
  }) async {
    if (docId != null) {
      await _db.collection(path).doc(docId).set(data);
    } else {
      await _db.collection(path).add(data);
    }
  }

  // Generic Update Document
  Future<void> updateDocument({
    required String path,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection(path).doc(docId).update(data);
  }

  // Generic Delete Document
  Future<void> deleteDocument({
    required String path,
    required String docId,
  }) async {
    await _db.collection(path).doc(docId).delete();
  }
}
