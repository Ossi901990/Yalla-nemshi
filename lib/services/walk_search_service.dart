import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/walk_event.dart';
import '../models/walk_search_filters.dart';
import '../utils/search_utils.dart';
import 'app_preferences.dart';

class WalkSearchPage {
  const WalkSearchPage({
    required this.results,
    required this.hasMore,
    this.lastDocument,
  });

  final List<WalkEvent> results;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

class WalkSearchService {
  WalkSearchService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int defaultPageSize = 25;

  Future<WalkSearchPage> searchWalks({
    required WalkSearchFilters filters,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = defaultPageSize,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('walks')
        .where('cancelled', isEqualTo: false);

    if (!filters.includePrivate) {
      query = query.where('visibility', isEqualTo: 'open');
    }

    if (filters.recurringOnly) {
      query = query.where('isRecurring', isEqualTo: true);
    }

    if (filters.cities.isNotEmpty) {
      final cityList = filters.cities.toList();
      if (cityList.length == 1) {
        query = query.where('city', isEqualTo: cityList.first);
      } else if (cityList.length <= 10) {
        query = query.where('city', whereIn: cityList);
      }
    }

    final tagList = filters.tags.take(10).toList();
    if (tagList.isNotEmpty) {
      query = query.where('tags', arrayContainsAny: tagList);
    }

    final keywordTokens = filters.keywordTokens;
    if (keywordTokens.isNotEmpty) {
      query = query.where('searchKeywords', arrayContainsAny: keywordTokens);
    }

    if (filters.startDate != null) {
      query = query.where(
        'dateTime',
        isGreaterThanOrEqualTo: filters.startDate!.toIso8601String(),
      );
    }

    if (filters.endDate != null) {
      query = query.where(
        'dateTime',
        isLessThanOrEqualTo: filters.endDate!.toIso8601String(),
      );
    }

    query = query.orderBy('dateTime');

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.limit(limit).get();

    final walks = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      data['firestoreId'] = doc.id;
      return WalkEvent.fromMap(data);
    }).where(filters.matches).toList();

    walks.sort((a, b) {
      switch (filters.sort) {
        case WalkSearchSort.recentlyAdded:
          return b.dateTime.compareTo(a.dateTime);
        case WalkSearchSort.distance:
          return a.distanceKm.compareTo(b.distanceKm);
        case WalkSearchSort.soonest:
          return a.dateTime.compareTo(b.dateTime);
      }
    });

    return WalkSearchPage(
      results: walks,
      hasMore: snapshot.docs.length == limit,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : startAfter,
    );
  }

  Future<void> rememberSearchQuery(String query) async {
    await AppPreferences.addSearchHistoryTerm(query.trim());
  }

  Future<List<String>> loadSearchHistory({int limit = 12}) async {
    return AppPreferences.getSearchHistory(maxItems: limit);
  }

  Future<List<String>> keywordSuggestions(String input, {int limit = 8}) async {
    final normalized = input.trim().toLowerCase();
    final history = await AppPreferences.getSearchHistory(maxItems: limit * 2);
    final pool = [...history, ...SearchUtils.defaultKeywordSeeds];
    final suggestions = <String>[];

    for (final candidate in pool) {
      final value = candidate.trim();
      if (value.isEmpty) continue;
      if (normalized.isNotEmpty && !value.toLowerCase().startsWith(normalized)) {
        continue;
      }
      final alreadyAdded = suggestions.any(
        (entry) => entry.toLowerCase() == value.toLowerCase(),
      );
      if (alreadyAdded) continue;
      suggestions.add(value);
      if (suggestions.length >= limit) break;
    }

    return suggestions;
  }

  Future<List<SavedWalkSearchFilter>> loadSavedFilters() async {
    final rawList = await AppPreferences.getSavedSearchFilterJson();
    final filters = <SavedWalkSearchFilter>[];

    for (final jsonString in rawList) {
      try {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        filters.add(SavedWalkSearchFilter.fromJson(map));
      } catch (_) {
        continue;
      }
    }

    return filters;
  }

  Future<void> upsertSavedFilter(SavedWalkSearchFilter filter) async {
    final existing = await loadSavedFilters();
    final updated = <SavedWalkSearchFilter>[];
    bool replaced = false;

    for (final item in existing) {
      if (item.id == filter.id) {
        updated.add(filter);
        replaced = true;
      } else {
        updated.add(item);
      }
    }

    if (!replaced) {
      updated.insert(0, filter);
    }

    final payload = updated.map((item) => jsonEncode(item.toJson())).toList();
    await AppPreferences.setSavedSearchFilterJson(payload);
  }

  Future<void> deleteSavedFilter(String filterId) async {
    final existing = await loadSavedFilters();
    final remaining = existing.where((item) => item.id != filterId).toList();
    final payload = remaining.map((item) => jsonEncode(item.toJson())).toList();
    await AppPreferences.setSavedSearchFilterJson(payload);
  }
}
