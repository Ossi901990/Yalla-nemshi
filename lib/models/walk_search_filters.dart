import 'walk_event.dart';
import '../utils/search_utils.dart';



class WalkSearchFilters {
  static const Object _unset = Object();

  const WalkSearchFilters({
    this.keywords = '',
    Set<String>? cities,
    Set<String>? tags,
    Set<String>? paces,
    Set<String>? genders,
    this.comfortLevel,
    this.experienceLevel,
    this.startDate,
    this.endDate,
    this.minDistanceKm,
    this.maxDistanceKm,
    this.recurringOnly = false,
    this.withPhotosOnly = false,
  })  : cities = cities ?? const <String>{},
        tags = tags ?? const <String>{},
        paces = paces ?? const <String>{},
        genders = genders ?? const <String>{};

  final String keywords;
  final Set<String> cities;
  final Set<String> tags;
  final Set<String> paces;
  final Set<String> genders;
  final String? comfortLevel;
  final String? experienceLevel;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minDistanceKm;
  final double? maxDistanceKm;
  final bool recurringOnly;
  final bool withPhotosOnly;

  bool get hasKeywordQuery => keywords.trim().isNotEmpty;

  List<String> get keywordTokens => SearchUtils.tokenizeQuery(keywords).take(10).toList();

  WalkSearchFilters copyWith({
    String? keywords,
    Set<String>? cities,
    Set<String>? tags,
    Set<String>? paces,
    Set<String>? genders,
    Object? comfortLevel = _unset,
    Object? experienceLevel = _unset,
    Object? startDate = _unset,
    Object? endDate = _unset,
    Object? minDistanceKm = _unset,
    Object? maxDistanceKm = _unset,
    bool? recurringOnly,
    bool? withPhotosOnly,
  }) {
    return WalkSearchFilters(
      keywords: keywords ?? this.keywords,
      cities: cities ?? this.cities,
      tags: tags ?? this.tags,
      paces: paces ?? this.paces,
      genders: genders ?? this.genders,
      comfortLevel: identical(comfortLevel, _unset) ? this.comfortLevel : comfortLevel as String?,
      experienceLevel: identical(experienceLevel, _unset) ? this.experienceLevel : experienceLevel as String?,
      startDate: identical(startDate, _unset) ? this.startDate : startDate as DateTime?,
      endDate: identical(endDate, _unset) ? this.endDate : endDate as DateTime?,
      minDistanceKm: identical(minDistanceKm, _unset) ? this.minDistanceKm : minDistanceKm as double?,
      maxDistanceKm: identical(maxDistanceKm, _unset) ? this.maxDistanceKm : maxDistanceKm as double?,
      recurringOnly: recurringOnly ?? this.recurringOnly,
      withPhotosOnly: withPhotosOnly ?? this.withPhotosOnly,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'keywords': keywords,
      'cities': cities.toList(),
      'tags': tags.toList(),
      'paces': paces.toList(),
      'genders': genders.toList(),
      'comfortLevel': comfortLevel,
      'experienceLevel': experienceLevel,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'minDistanceKm': minDistanceKm,
      'maxDistanceKm': maxDistanceKm,
      'recurringOnly': recurringOnly,
      'withPhotosOnly': withPhotosOnly,
    };
  }

  factory WalkSearchFilters.fromJson(Map<String, dynamic> json) {
    Set<String> toSet(dynamic value) {
      if (value is Iterable) {
        return value.whereType<String>().toSet();
      }
      return const <String>{};
    }

    return WalkSearchFilters(
      keywords: (json['keywords'] ?? '').toString(),
      cities: toSet(json['cities']),
      tags: toSet(json['tags']),
      paces: toSet(json['paces']),
      genders: toSet(json['genders']),
      comfortLevel: json['comfortLevel']?.toString(),
      experienceLevel: json['experienceLevel']?.toString(),
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,
      minDistanceKm: json['minDistanceKm'] != null
          ? double.tryParse(json['minDistanceKm'].toString())
          : null,
      maxDistanceKm: json['maxDistanceKm'] != null
          ? double.tryParse(json['maxDistanceKm'].toString())
          : null,
      recurringOnly: json['recurringOnly'] == true,
      withPhotosOnly: json['withPhotosOnly'] == true,
    );
  }

  bool matches(WalkEvent walk) {
    // Never match private walks in search
    if (walk.visibility == 'private') {
      return false;
    }

    if (cities.isNotEmpty) {
      if (walk.city == null || !cities.contains(walk.city)) {
        return false;
      }
    }

    if (comfortLevel != null && comfortLevel!.trim().isNotEmpty) {
      if ((walk.comfortLevel ?? '').toLowerCase() != comfortLevel!.toLowerCase()) {
        return false;
      }
    }

    if (experienceLevel != null && experienceLevel!.trim().isNotEmpty) {
      if ((walk.experienceLevel).toLowerCase() != experienceLevel!.toLowerCase()) {
        return false;
      }
    }

    if (tags.isNotEmpty && !walk.tags.any(tags.contains)) {
      return false;
    }

    if (paces.isNotEmpty && !paces.contains(walk.pace)) {
      return false;
    }

    if (genders.isNotEmpty && !genders.contains(walk.gender)) {
      return false;
    }

    if (recurringOnly && !walk.isRecurring) {
      return false;
    }

    if (withPhotosOnly && walk.photoUrls.isEmpty) {
      return false;
    }

    if (minDistanceKm != null && walk.distanceKm < minDistanceKm!) {
      return false;
    }

    if (maxDistanceKm != null && walk.distanceKm > maxDistanceKm!) {
      return false;
    }

    if (startDate != null && walk.dateTime.isBefore(startDate!)) {
      return false;
    }

    if (endDate != null && walk.dateTime.isAfter(endDate!)) {
      return false;
    }

    final tokens = keywordTokens;
    if (tokens.isNotEmpty) {
      final haystack = <String>[
        walk.title,
        walk.description ?? '',
        walk.city ?? '',
        walk.comfortLevel ?? '',
        walk.experienceLevel,
        ...walk.tags,
      ].map((value) => value.toLowerCase()).join(' ');

      for (final token in tokens) {
        if (!haystack.contains(token)) {
          return false;
        }
      }
    }

    return true;
  }
}

class SavedWalkSearchFilter {
  const SavedWalkSearchFilter({
    required this.id,
    required this.label,
    required this.filters,
  });

  final String id;
  final String label;
  final WalkSearchFilters filters;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'filters': filters.toJson(),
    };
  }

  factory SavedWalkSearchFilter.fromJson(Map<String, dynamic> json) {
    final rawFilters = json['filters'];
    final filtersJson = rawFilters is Map
        ? rawFilters.cast<String, dynamic>()
        : const <String, dynamic>{};
    return SavedWalkSearchFilter(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      filters: WalkSearchFilters.fromJson(filtersJson),
    );
  }

  SavedWalkSearchFilter copyWith({String? label, WalkSearchFilters? filters}) {
    return SavedWalkSearchFilter(
      id: id,
      label: label ?? this.label,
      filters: filters ?? this.filters,
    );
  }

  static SavedWalkSearchFilter create({
    required String label,
    required WalkSearchFilters filters,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return SavedWalkSearchFilter(id: id, label: label, filters: filters);
  }
}
