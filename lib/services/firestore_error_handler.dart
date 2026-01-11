import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_exception.dart';
import 'crash_service.dart';

/// Wrapper service for Firestore operations with consistent error handling
class FirestoreErrorHandler {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Get current user ID or throw if not authenticated
  static String getCurrentUserId() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw AuthException(
        message: 'You must be signed in to perform this action.',
        code: 'unauthenticated',
      );
    }
    return uid;
  }

  /// Wrap a Firestore operation with error handling
  static Future<T> executeFirestoreOperation<T>(
    Future<T> Function() operation, {
    required String operationName,
  }) async {
    try {
      return await operation();
    } on FirebaseException catch (e) {
      final exception = FirestoreException.fromFirebaseException(e);
      CrashService.recordError(exception, StackTrace.current);
      rethrow;
    } catch (e, st) {
      final exception = AppError(
        message: 'Firestore operation failed: $operationName',
        originalError: e,
      );
      CrashService.recordError(exception, st);
      throw exception;
    }
  }

  /// Get a document with error handling
  static Future<DocumentSnapshot<T>> getDocument<T>(
    DocumentReference<T> ref,
  ) async {
    return executeFirestoreOperation(
      () => ref.get(),
      operationName: 'getDocument',
    );
  }

  /// Query documents with error handling
  static Future<QuerySnapshot<T>> queryDocuments<T>(
    Query<T> query,
  ) async {
    return executeFirestoreOperation(
      () => query.get(),
      operationName: 'queryDocuments',
    );
  }

  /// Set document with error handling
  static Future<void> setDocument<T>(
    DocumentReference<T> ref,
    T data, {
    bool merge = false,
  }) async {
    return executeFirestoreOperation(
      () => ref.set(data, SetOptions(merge: merge)),
      operationName: 'setDocument',
    );
  }

  /// Update document with error handling
  static Future<void> updateDocument<T>(
    DocumentReference<T> ref,
    Map<String, dynamic> data,
  ) async {
    return executeFirestoreOperation(
      () => ref.update(data),
      operationName: 'updateDocument',
    );
  }

  /// Delete document with error handling
  static Future<void> deleteDocument<T>(
    DocumentReference<T> ref,
  ) async {
    return executeFirestoreOperation(
      () => ref.delete(),
      operationName: 'deleteDocument',
    );
  }

  /// Batch write with error handling
  static Future<void> executeBatch(
    Future<void> Function(WriteBatch) operation,
  ) async {
    return executeFirestoreOperation(
      () async {
        final batch = _firestore.batch();
        await operation(batch);
        return batch.commit();
      },
      operationName: 'batchWrite',
    );
  }

  /// Transaction with error handling
  static Future<T> runTransaction<T>(
    Future<T> Function(Transaction) transactionHandler,
  ) async {
    return executeFirestoreOperation(
      () => _firestore.runTransaction(transactionHandler),
      operationName: 'transaction',
    );
  }
}
