import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/walk_event.dart';
import 'crash_service.dart';
import 'walk_history_service.dart';

/// Centralized offline helpers: persistence, connectivity state, cached data, and
/// lightweight action queueing for sync-on-reconnect flows.
class OfflineService {
  OfflineService._();

  static final OfflineService instance = OfflineService._();

  static const _walkCacheKey = 'cached_walks_v1';
  static const _pendingJoinKey = 'pending_join_actions_v1';

  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);
  final ValueNotifier<int> pendingActionCount = ValueNotifier<int>(0);

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Enable Firestore persistence for mobile/desktop. Web handles this
    // differently and may throw if we attempt to set persistence.
    if (!kIsWeb) {
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
        );
      } catch (e, st) {
        // Persistence may already be enabled; log and continue.
        CrashService.recordError(
          e,
          st,
          reason: 'OfflineService.enablePersistence',
        );
      }
    }

    // Track connectivity to drive UI and queued actions.
    final connectivity = Connectivity();
    _connSub = connectivity.onConnectivityChanged.listen((result) {
      final offline = result.every((r) => r == ConnectivityResult.none);
      isOffline.value = offline;
      if (!offline) {
        _syncPendingActions();
      }
    });

    // Seed the initial state.
    final initial = await connectivity.checkConnectivity();
    isOffline.value = initial.every((r) => r == ConnectivityResult.none);

    // Seed any stored pending count.
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_pendingJoinKey) ?? const [];
    pendingActionCount.value = stored.length;
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
  }

  // --- Walk list caching ---

  Future<void> cacheWalks(List<WalkEvent> walks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final limited = walks.take(50).toList();
      final encoded = jsonEncode(limited.map((w) => w.toCacheMap()).toList());
      await prefs.setString(_walkCacheKey, encoded);
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'OfflineService.cacheWalks');
    }
  }

  Future<List<WalkEvent>> loadCachedWalks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_walkCacheKey);
      if (raw == null) return const [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((m) => WalkEvent.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'OfflineService.loadCachedWalks');
      return const [];
    }
  }

  // --- Pending join/leave actions ---

  Future<void> queueJoinAction({
    required String walkId,
    required bool join,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_pendingJoinKey) ?? <String>[];
      final payload = jsonEncode({
        'walkId': walkId,
        'join': join,
        'ts': DateTime.now().toIso8601String(),
      });
      pending.add(payload);
      await prefs.setStringList(_pendingJoinKey, pending);
      pendingActionCount.value = pending.length;
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'OfflineService.queueJoinAction');
    }
  }

  Future<void> _syncPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_pendingJoinKey) ?? <String>[];
      if (pending.isEmpty) return;

      debugPrint('🔄 Syncing ${pending.length} pending offline actions...');

      // Re-execute each action explicitly instead of just waiting for Firestore
      // This ensures actions aren't lost if Firestore dropped them
      final succeeded = <String>[];
      final failed = <String>[];

      for (final actionJson in pending) {
        try {
          final action = jsonDecode(actionJson) as Map<String, dynamic>;
          final walkId = action['walkId'] as String;
          final join = action['join'] as bool;

          debugPrint(
            '  → Re-executing ${join ? "join" : "leave"} for walk $walkId',
          );

          // Actually call the service methods to re-execute the action
          if (join) {
            await WalkHistoryService.instance.recordWalkJoin(walkId);
          } else {
            await WalkHistoryService.instance.recordWalkLeave(walkId);
          }

          // Mark as succeeded
          succeeded.add(actionJson);
          debugPrint('  ✅ Action succeeded');
        } catch (e) {
          // Keep failed actions in queue for retry
          failed.add(actionJson);
          debugPrint('  ❌ Action failed: $e');
        }
      }

      // Update queue: remove succeeded, keep failed for retry
      if (succeeded.isNotEmpty) {
        await prefs.setStringList(_pendingJoinKey, failed);
        pendingActionCount.value = failed.length;
        debugPrint(
          '✅ Synced ${succeeded.length} actions, ${failed.length} remaining',
        );
      }

      // If all succeeded, clear the pending writes from Firestore too
      if (failed.isEmpty) {
        await FirebaseFirestore.instance.waitForPendingWrites();
      }
    } catch (e, st) {
      CrashService.recordError(e, st, reason: 'OfflineService.syncPending');
    }
  }
}
