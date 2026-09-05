import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/firebase_runtime.dart';
import 'package:cloud_functions/cloud_functions.dart';

class FirestoreService {
  final Future<Map<String, dynamic>> Function(
    String name,
    Map<String, dynamic> data,
  )?
  _callOverride;
  final Future<dynamic> Function(String path, String docId)? _getOverride;
  final Stream<dynamic> Function(String path, String docId)? _streamOverride;

  final FirebaseFirestore? _databaseOverride;

  FirestoreService()
    : _callOverride = null,
      _getOverride = null,
      _streamOverride = null,
      _databaseOverride = null;

  FirestoreService.test({
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> data,
    )?
    call,
    Future<dynamic> Function(String path, String docId)? get,
    Stream<dynamic> Function(String path, String docId)? stream,
  }) : _callOverride = call,
       _getOverride = get,
       _streamOverride = stream,
       _databaseOverride = null;

  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (_callOverride != null) {
      return _callOverride(name, data);
    }
    final result =
        await FirebaseFunctions.instanceFor(
              app: FirebaseRuntime.app,
              region: 'asia-southeast2',
            )
            .httpsCallable(
              name,
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 20),
              ),
            )
            .call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  FirebaseFirestore get _db =>
      _databaseOverride ??
      FirebaseFirestore.instanceFor(
        app: FirebaseRuntime.app,
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
    if (_getOverride != null) {
      final value = await _getOverride(path, docId);
      if (value == null) return null;
      if (value is T) return value;
      return fromJson(Map<String, dynamic>.from(value as Map), docId);
    }
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
    if (_streamOverride != null) {
      return _streamOverride(path, docId).map((value) {
        if (value == null) return null;
        if (value is T) return value;
        return fromJson(Map<String, dynamic>.from(value as Map), docId);
      });
    }
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
    if (path == usersPath) {
      await call('manageUser', {'action': 'update', 'uid': docId, ...data});
      return;
    }
    await _db.collection(path).doc(docId).update(data);
  }

  // Generic Delete Document
  Future<void> deleteDocument({
    required String path,
    required String docId,
  }) async {
    if (path == usersPath) {
      await call('manageUser', {'action': 'delete', 'uid': docId});
      return;
    }
    await _db.collection(path).doc(docId).delete();
  }
}
