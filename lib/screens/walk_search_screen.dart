import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_tokens.dart';
import '../models/walk_event.dart';
import '../models/walk_search_filters.dart';
import '../screens/event_details_screen.dart';
import '../services/app_preferences.dart';
import '../services/walk_search_service.dart';

class WalkSearchScreen extends StatefulWidget {
  const WalkSearchScreen({super.key});

  static const routeName = '/walk-search';

  @override
  State<WalkSearchScreen> createState() => _WalkSearchScreenState();
}

class _WalkSearchScreenState extends State<WalkSearchScreen> {
  final WalkSearchService _searchService = WalkSearchService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final DateFormat _dateFormat = DateFormat('EEE, MMM d • h:mm a');

  WalkSearchFilters _filters = const WalkSearchFilters();
  List<WalkEvent> _results = const [];
  List<String> _history = const [];
  List<String> _suggestions = const [];
  List<SavedWalkSearchFilter> _savedFilters = const [];

  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  Timer? _searchDebounce;
  Timer? _suggestionDebounce;

  static const List<String> _tagOptions = [
    'Scenic views',
    'City loop',
    'Trail run',
    'Dog friendly',
    'Family / stroller',
    'Sunrise',
    'Sunset',
    'Coffee after',
    'Mindful pace',
    'Women only',
    'Beginners welcome',
    'Hiking',
  ];

  static const List<String> _paceOptions = ['Relaxed', 'Normal', 'Brisk'];
  static const List<String> _genderOptions = ['Mixed', 'Women only', 'Men only'];
  static const List<String> _comfortOptions = [
    'Social & chatty',
    'Quiet & mindful',
    'Workout focused',
  ];
  static const List<String> _experienceOptions = [
    'All levels',
    'Beginners welcome',
    'Intermediate walkers',
    'Advanced hikers',
  ];
  static const List<String> _cityStarterList = [
    'Dubai',
    'Abu Dhabi',
    'Sharjah',
    'Ajman',
    'Doha',
    'Riyadh',
    'Jeddah',
    'Manama',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = _filters.keywords;
    _searchFocus.addListener(() {
      if (!mounted) return;
      setState(() {}); // rebuild to hide suggestions when focus changes
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _suggestionDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final history = await _searchService.loadSearchHistory(limit: 12);
      final saved = await _searchService.loadSavedFilters();
      if (!mounted) return;
      setState(() {
        _history = history;
        _savedFilters = saved;
      });
    } catch (_) {
      // history failures are non-blocking
    }
    await _runSearch(reset: true);
  }

  Future<void> _runSearch({bool reset = false, bool rememberQuery = false}) async {
    if (_isLoadingMore && !reset) return;

    setState(() {
      if (reset) {
        _isLoading = true;
        _errorMessage = null;
        _hasMore = true;
        _lastDocument = null;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final page = await _searchService.searchWalks(
        filters: _filters,
        startAfter: reset ? null : _lastDocument,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _results = page.results;
        } else {
          _results = [..._results, ...page.results];
        }
        _hasMore = page.hasMore;
        _lastDocument = page.lastDocument;
        _isLoading = false;
        _isLoadingMore = false;
      });

      if (rememberQuery && _filters.keywords.trim().isNotEmpty) {
        await _searchService.rememberSearchQuery(_filters.keywords);
        final history = await _searchService.loadSearchHistory(limit: 12);
        if (mounted) {
          setState(() => _history = history);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'Unable to load walks. Please try again.';
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _filters = _filters.copyWith(keywords: value);
    });
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(const Duration(milliseconds: 220), () {
      _loadSuggestions(value);
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 420), () {
      _runSearch(reset: true);
    });
  }

  Future<void> _loadSuggestions(String input) async {
    if (input.trim().length < 2) {
      if (mounted) {
        setState(() => _suggestions = const []);
      }
      return;
    }
    try {
      final ideas = await _searchService.keywordSuggestions(input, limit: 6);
      if (mounted) {
        setState(() => _suggestions = ideas);
      }
    } catch (_) {
      // ignore suggestions errors
    }
  }

  void _applySuggestion(String term) {
    _searchController.text = term;
    _searchFocus.unfocus();
    setState(() {
      _filters = _filters.copyWith(keywords: term);
      _suggestions = const [];
    });
    _runSearch(reset: true, rememberQuery: true);
  }

  void _applyHistoryTerm(String term) {
    _searchController.text = term;
    setState(() {
      _filters = _filters.copyWith(keywords: term);
    });
    _runSearch(reset: true);
  }

  void _setSort(WalkSearchSort sort) {
    if (_filters.sort == sort) return;
    setState(() => _filters = _filters.copyWith(sort: sort));
    _runSearch(reset: true);
  }

  void _toggleBoolFilter({bool? includePrivate, bool? recurringOnly, bool? withPhotosOnly}) {
    setState(() {
      _filters = _filters.copyWith(
        includePrivate: includePrivate ?? _filters.includePrivate,
        recurringOnly: recurringOnly ?? _filters.recurringOnly,
        withPhotosOnly: withPhotosOnly ?? _filters.withPhotosOnly,
      );
    });
    _runSearch(reset: true);
  }

  void _toggleSetValue(Set<String> current, String value, ValueSetter<Set<String>> onChanged) {
    final updated = current.contains(value)
        ? (Set<String>.from(current)..remove(value))
        : (Set<String>.from(current)..add(value));
    onChanged(updated);
    _runSearch(reset: true);
  }

  void _updateTags(Set<String> updated) {
    setState(() => _filters = _filters.copyWith(tags: updated));
  }

  void _updatePaces(Set<String> updated) {
    setState(() => _filters = _filters.copyWith(paces: updated));
  }

  void _updateGenders(Set<String> updated) {
    setState(() => _filters = _filters.copyWith(genders: updated));
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final existingStart = _filters.startDate ?? now;
    final existingEnd = _filters.endDate ?? now.add(const Duration(days: 14));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: existingStart, end: existingEnd),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(primary: kPrimaryTeal),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    setState(() {
      _filters = _filters.copyWith(
        startDate: picked.start,
        endDate: picked.end,
      );
    });
    _runSearch(reset: true);
  }

  void _clearDateRange() {
    setState(() {
      _filters = _filters.copyWith(startDate: null, endDate: null);
    });
    _runSearch(reset: true);
  }

  Future<void> _promptForCity() async {
    final controller = TextEditingController();
    final city = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add a city'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Example: Dubai'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Add city'),
            ),
          ],
        );
      },
    );

    if (city == null || city.isEmpty) return;
    final updated = Set<String>.from(_filters.cities)..add(city);
    setState(() => _filters = _filters.copyWith(cities: updated));
    _runSearch(reset: true);
  }

  void _removeCity(String city) {
    final updated = Set<String>.from(_filters.cities)..remove(city);
    setState(() => _filters = _filters.copyWith(cities: updated));
    _runSearch(reset: true);
  }

  void _setComfort(String? value) {
    setState(() => _filters = _filters.copyWith(comfortLevel: value));
    _runSearch(reset: true);
  }

  void _setExperience(String? value) {
    setState(() => _filters = _filters.copyWith(experienceLevel: value));
    _runSearch(reset: true);
  }

  Future<void> _saveCurrentFilters() async {
    final controller = TextEditingController(text: 'My filter ${_savedFilters.length + 1}');
    final label = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save this filter set'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Label'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (label == null || label.isEmpty) return;
    final filter = SavedWalkSearchFilter.create(label: label, filters: _filters);
    await _searchService.upsertSavedFilter(filter);
    final saved = await _searchService.loadSavedFilters();
    if (!mounted) return;
    setState(() => _savedFilters = saved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "$label"')), 
    );
  }

  Future<void> _deleteSavedFilter(String filterId) async {
    await _searchService.deleteSavedFilter(filterId);
    final saved = await _searchService.loadSavedFilters();
    if (!mounted) return;
    setState(() => _savedFilters = saved);
  }

  void _applySavedFilter(SavedWalkSearchFilter filter) {
    setState(() {
      _filters = filter.filters;
      _searchController.text = filter.filters.keywords;
    });
    _runSearch(reset: true);
  }

  String _dateRangeLabel() {
    if (_filters.startDate == null || _filters.endDate == null) {
      return 'Any date';
    }
    final start = DateFormat('MMM d').format(_filters.startDate!);
    final end = DateFormat('MMM d').format(_filters.endDate!);
    return '$start → $end';
  }

  int _countActiveFilters() {
    int count = 0;
    if (_filters.tags.isNotEmpty) count++;
    if (_filters.paces.isNotEmpty) count++;
    if (_filters.genders.isNotEmpty) count++;
    if (_filters.cities.isNotEmpty) count++;
    if (_filters.startDate != null || _filters.endDate != null) count++;
    if (_filters.comfortLevel != null) count++;
    if (_filters.experienceLevel != null) count++;
    if (_filters.recurringOnly) count++;
    if (_filters.withPhotosOnly) count++;
    if (_filters.sort != WalkSearchSort.soonest) count++;
    return count;
  }

  Widget _buildActiveFiltersBar(ThemeData theme) {
    final filters = <Widget>[];

    if (_filters.tags.isNotEmpty) {
      filters.add(
        InputChip(
          label: Text('Tags (${_filters.tags.length})'),
          onDeleted: () {
            setState(() => _filters = _filters.copyWith(tags: const {}));
            _runSearch(reset: true);
          },
        ),
      );
    }

    if (_filters.paces.isNotEmpty) {
      filters.add(
        InputChip(
          label: Text('Pace (${_filters.paces.length})'),
          onDeleted: () {
            setState(() => _filters = _filters.copyWith(paces: const {}));
            _runSearch(reset: true);
          },
        ),
      );
    }

    if (_filters.genders.isNotEmpty) {
      filters.add(
        InputChip(
          label: Text('Gender (${_filters.genders.length})'),
          onDeleted: () {
            setState(() => _filters = _filters.copyWith(genders: const {}));
            _runSearch(reset: true);
          },
        ),
      );
    }

    if (_filters.cities.isNotEmpty) {
      filters.add(
        InputChip(
          label: Text('Cities (${_filters.cities.length})'),
          onDeleted: () {
            setState(() => _filters = _filters.copyWith(cities: const {}));
            _runSearch(reset: true);
          },
        ),
      );
    }

    if (_filters.startDate != null || _filters.endDate != null) {
      filters.add(
        InputChip(
          label: Text(_dateRangeLabel()),
          onDeleted: _clearDateRange,
        ),
      );
    }

    if (_filters.comfortLevel != null) {
      filters.add(
        InputChip(
          label: Text('Comfort: ${_filters.comfortLevel}'),
          onDeleted: () {
            setState(() => _filters = _filters.copyWith(comfortLevel: null));
            _runSearch(reset: true);
          },
        ),
      );
    }

    if (_filters.experienceLevel != null) {
      filters.add(
        InputChip(
          label: Text('Level: ${_filters.experienceLevel}'),
          onDeleted: () {
            setState(() => _filters = _filters.copyWith(experienceLevel: null));
            _runSearch(reset: true);
          },
        ),
      );
    }

    if (filters.isEmpty) return const SizedBox();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters,
    );
  }

  void _showFilterModal(BuildContext context, ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FilterModal(
        filters: _filters,
        onFiltersChanged: (updatedFilters) {
          setState(() => _filters = updatedFilters);
          _runSearch(reset: true);
        },
        tagOptions: _tagOptions,
        paceOptions: _paceOptions,
        genderOptions: _genderOptions,
        comfortOptions: _comfortOptions,
        experienceOptions: _experienceOptions,
        cityStarterList: _cityStarterList,
        onAddCity: _promptForCity,
        onRemoveCity: _removeCity,
        onPickDateRange: _pickDateRange,
        onClearDateRange: _clearDateRange,
        dateRangeLabel: _dateRangeLabel,
        onSaveFilters: _saveCurrentFilters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Walk search'),
        actions: [
          IconButton(
            onPressed: _saveCurrentFilters,
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Save current filters',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _runSearch(reset: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _buildSearchBox(theme),
              const SizedBox(height: 12),
              _buildSuggestionList(theme),
              const SizedBox(height: 16),
              _buildHistorySection(theme),
              const SizedBox(height: 16),
              _buildPopularTagsSection(theme),
              const SizedBox(height: 16),
              _buildSavedFiltersSection(theme),
              const SizedBox(height: 24),
              _buildSortSection(theme),
              const SizedBox(height: 24),
              _buildVisibilityToggles(theme),
              const SizedBox(height: 24),
              _buildCitySection(theme, isDark),
              const SizedBox(height: 24),
              _buildTagSection(theme, isDark),
              const SizedBox(height: 24),
              _buildChipSection(
                theme,
                title: 'Pace',
                options: _paceOptions,
                selected: _filters.paces,
                onToggle: (pace) => _toggleSetValue(_filters.paces, pace, _updatePaces),
              ),
              const SizedBox(height: 24),
              _buildChipSection(
                theme,
                title: 'Gender preference',
                options: _genderOptions,
                selected: _filters.genders,
                onToggle: (gender) => _toggleSetValue(_filters.genders, gender, _updateGenders),
              ),
              const SizedBox(height: 24),
              _buildComfortExperience(theme, isDark),
              const SizedBox(height: 24),
              _buildDateRangeCard(theme, isDark),
              const SizedBox(height: 32),
              _buildResultHeader(theme),
              const SizedBox(height: 12),
              _buildResults(theme, isDark),
              const SizedBox(height: 32),
              if (_hasMore)
                OutlinedButton.icon(
                  onPressed: _isLoadingMore ? null : () => _runSearch(reset: false),
                  icon: _isLoadingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: Text(_isLoadingMore ? 'Loading more...' : 'Load more'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find a walk that matches your vibe',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.brightness == Brightness.dark ? Colors.white : kTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _runSearch(reset: true, rememberQuery: true),
          decoration: InputDecoration(
            hintText: 'Search by title, tags, city...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),
            filled: true,
            fillColor: theme.brightness == Brightness.dark
                ? Colors.white12
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionList(ThemeData theme) {
    final showSuggestions = _searchFocus.hasFocus && _suggestions.isNotEmpty;
    if (!showSuggestions) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 20,
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return ListTile(
            title: Text(suggestion),
            leading: const Icon(Icons.north_west, size: 18),
            onTap: () => _applySuggestion(suggestion),
          );
        },
        separatorBuilder: (context, _) => const Divider(height: 0),
        itemCount: _suggestions.length,
      ),
    );
  }

  Widget _buildHistorySection(ThemeData theme) {
    if (_history.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent searches',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: () async {
                await AppPreferences.clearSearchHistory();
                if (!mounted) return;
                setState(() => _history = const []);
              },
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _history
              .map(
                (term) => ActionChip(
                  label: Text(term),
                  avatar: const Icon(Icons.history, size: 16),
                  onPressed: () => _applyHistoryTerm(term),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPopularTagsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular tags',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Browse walks by popular categories',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tagOptions
              .map(
                (tag) {
                  final selected = _filters.tags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (newValue) {
                      setState(() {
                        if (newValue) {
                          _filters = _filters.copyWith(tags: {..._filters.tags, tag});
                        } else {
                          final updated = {..._filters.tags};
                          updated.remove(tag);
                          _filters = _filters.copyWith(tags: updated);
                        }
                      });
                      _runSearch(reset: true);
                    },
                  );
                },
              )
              .toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSavedFiltersSection(ThemeData theme) {
    if (_savedFilters.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saved filters',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Save your favorite combinations to re-use them later. Tap the bookmark button to save one.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saved filters',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final filter = _savedFilters[index];
              return InputChip(
                label: Text(filter.label),
                avatar: const Icon(Icons.push_pin_outlined, size: 16),
                onPressed: () => _applySavedFilter(filter),
                onDeleted: () => _deleteSavedFilter(filter.id),
              );
            },
            separatorBuilder: (context, _) => const SizedBox(width: 8),
            itemCount: _savedFilters.length,
          ),
        ),
      ],
    );
  }

  Widget _buildSortSection(ThemeData theme) {
    final options = {
      WalkSearchSort.soonest: 'Soonest',
      WalkSearchSort.recentlyAdded: 'Recently added',
      WalkSearchSort.distance: 'Shortest distance',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sort order',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.entries.map((entry) {
            final selected = _filters.sort == entry.key;
            return ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (_) => _setSort(entry.key),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVisibilityToggles(ThemeData theme) {
    final chips = [
      (
        label: 'Include private walks',
        value: _filters.includePrivate,
        icon: Icons.lock_open,
        onTap: () => _toggleBoolFilter(includePrivate: !_filters.includePrivate),
      ),
      (
        label: 'Recurring only',
        value: _filters.recurringOnly,
        icon: Icons.repeat,
        onTap: () => _toggleBoolFilter(recurringOnly: !_filters.recurringOnly),
      ),
      (
        label: 'With photos only',
        value: _filters.withPhotosOnly,
        icon: Icons.photo_library_outlined,
        onTap: () => _toggleBoolFilter(withPhotosOnly: !_filters.withPhotosOnly),
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: chips
          .map(
            (item) => FilterChip(
              label: Text(item.label),
              avatar: Icon(item.icon, size: 16),
              selected: item.value,
              onSelected: (_) => item.onTap(),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCitySection(ThemeData theme, bool isDark) {
    final chips = _filters.cities
        .map(
          (city) => InputChip(
            label: Text(city),
            onDeleted: () => _removeCity(city),
          ),
        )
        .toList();

    return _FilterCard(
      title: 'Cities',
      subtitle: 'Focus on walks hosted in specific cities',
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...chips,
              ActionChip(
                avatar: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Add city'),
                onPressed: _promptForCity,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _cityStarterList.map((city) {
                final selected = _filters.cities.contains(city);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(city),
                    selected: selected,
                    onSelected: (_) {
                      final updated = Set<String>.from(_filters.cities);
                      if (selected) {
                        updated.remove(city);
                      } else {
                        updated.add(city);
                      }
                      setState(() => _filters = _filters.copyWith(cities: updated));
                      _runSearch(reset: true);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSection(ThemeData theme, bool isDark) {
    return _FilterCard(
      title: 'Tags',
      subtitle: 'Stack multiple moods or vibe markers',
      isDark: isDark,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _tagOptions.map((tag) {
          final selected = _filters.tags.contains(tag);
          return FilterChip(
            label: Text(tag),
            selected: selected,
            onSelected: (_) => _toggleSetValue(
              _filters.tags,
              tag,
              _updateTags,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChipSection(
    ThemeData theme, {
    required String title,
    required List<String> options,
    required Set<String> selected,
    required ValueChanged<String> onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((value) {
            return FilterChip(
              label: Text(value),
              selected: selected.contains(value),
              onSelected: (_) => onToggle(value),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildComfortExperience(ThemeData theme, bool isDark) {
    return _FilterCard(
      title: 'Comfort & experience',
      subtitle: 'Match the energy level and guidance you need',
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comfort vibe', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Any comfort'),
                selected: (_filters.comfortLevel ?? '').isEmpty,
                onSelected: (_) => _setComfort(null),
              ),
              ..._comfortOptions.map((option) {
                return ChoiceChip(
                  label: Text(option),
                  selected: _filters.comfortLevel == option,
                  onSelected: (_) => _setComfort(option),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          Text('Experience level', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Any experience'),
                selected: (_filters.experienceLevel ?? '').isEmpty,
                onSelected: (_) => _setExperience(null),
              ),
              ..._experienceOptions.map((option) {
                return ChoiceChip(
                  label: Text(option),
                  selected: _filters.experienceLevel == option,
                  onSelected: (_) => _setExperience(option),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildDateRangeCard(ThemeData theme, bool isDark) {
    return _FilterCard(
      title: 'Date range',
      subtitle: 'Pin down the window you are free to walk',
      isDark: isDark,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.calendar_today),
              label: Text(_dateRangeLabel()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Clear range',
            onPressed: (_filters.startDate == null && _filters.endDate == null)
                ? null
                : _clearDateRange,
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
    );
  }

  Widget _buildResultHeader(ThemeData theme) {
    final total = _results.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Results',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (_isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Text(
            '$total walks',
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }

  Widget _buildResults(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return Column(
        children: List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 110,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                isDark ? 80 : 200,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Column(
        children: [
          Text(
            _errorMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => _runSearch(reset: true),
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: getSurfaceColor(isDark),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: theme.dividerColor),
            const SizedBox(height: 12),
            Text(
              'No walks match those filters yet.',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try widening the date range or removing one of the tags.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Column(
      children: _results
          .map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _WalkSearchResultCard(
                event: event,
                dateFormat: _dateFormat,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _WalkSearchResultCard extends StatelessWidget {
  const _WalkSearchResultCard({
    required this.event,
    required this.dateFormat,
  });

  final WalkEvent event;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final showExperience =
        event.experienceLevel.isNotEmpty &&
        event.experienceLevel.toLowerCase() != 'all levels';

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EventDetailsScreen(
              event: event,
              onToggleJoin: (_) {},
              onToggleInterested: (_) {},
              onCancelHosted: (_) {},
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: getSurfaceColor(isDark),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withAlpha(12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(event.dateTime),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildVisibilityChip(theme),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(Icons.place_outlined, event.city ?? 'City TBA', theme),
                _infoChip(Icons.directions_walk, '${event.distanceKm.toStringAsFixed(1)} km', theme),
                _infoChip(Icons.speed, event.pace, theme),
                _infoChip(Icons.groups_2_outlined, event.gender, theme),
              ],
            ),
            if (event.comfortLevel != null || showExperience)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (event.comfortLevel != null)
                      Chip(
                        label: Text(event.comfortLevel!),
                        avatar: const Icon(Icons.mood, size: 16),
                      ),
                    if (showExperience)
                      Chip(
                        label: Text(event.experienceLevel),
                        avatar: const Icon(Icons.school, size: 16),
                      ),
                  ],
                ),
              ),
            if (event.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: event.tags
                      .map((tag) => Chip(
                            label: Text(tag),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, ThemeData theme) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
    );
  }

  Widget _buildVisibilityChip(ThemeData theme) {
    final isPrivate = event.visibility == 'private';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPrivate ? kSecondaryCorall : kPrimaryTeal,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPrivate ? 'Private' : 'Open',
        style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.isDark,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: getSurfaceColor(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withAlpha(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withAlpha(200)),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Bottom sheet modal for advanced filtering
class _FilterModal extends StatefulWidget {
  final WalkSearchFilters filters;
  final Function(WalkSearchFilters) onFiltersChanged;
  final List<String> tagOptions;
  final List<String> paceOptions;
  final List<String> genderOptions;
  final List<String> comfortOptions;
  final List<String> experienceOptions;
  final List<String> cityStarterList;
  final Function() onAddCity;
  final Function(String) onRemoveCity;
  final Function() onPickDateRange;
  final Function() onClearDateRange;
  final String Function() dateRangeLabel;
  final Function() onSaveFilters;

  const _FilterModal({
    required this.filters,
    required this.onFiltersChanged,
    required this.tagOptions,
    required this.paceOptions,
    required this.genderOptions,
    required this.comfortOptions,
    required this.experienceOptions,
    required this.cityStarterList,
    required this.onAddCity,
    required this.onRemoveCity,
    required this.onPickDateRange,
    required this.onClearDateRange,
    required this.dateRangeLabel,
    required this.onSaveFilters,
  });

  @override
  State<_FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<_FilterModal> {
  late WalkSearchFilters _localFilters;

  @override
  void initState() {
    super.initState();
    _localFilters = widget.filters;
  }

  @override
  void didUpdateWidget(covariant _FilterModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync _localFilters when parent updates filters (e.g., from active filter bar deletion)
    setState(() => _localFilters = widget.filters);
  }

  void _updateFilter(WalkSearchFilters updated) {
    setState(() => _localFilters = updated);
    widget.onFiltersChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: getBackgroundColor(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Filter content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  // Tags
                  _buildFilterSection(
                    title: 'Walk Type',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.tagOptions
                          .map(
                            (tag) => FilterChip(
                              label: Text(tag),
                              selected: _localFilters.tags.contains(tag),
                              onSelected: (selected) {
                                final updated = Set<String>.from(_localFilters.tags);
                                if (selected) {
                                  updated.add(tag);
                                } else {
                                  updated.remove(tag);
                                }
                                _updateFilter(_localFilters.copyWith(tags: updated));
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Pace
                  _buildFilterSection(
                    title: 'Pace',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.paceOptions
                          .map(
                            (pace) => FilterChip(
                              label: Text(pace),
                              selected: _localFilters.paces.contains(pace),
                              onSelected: (selected) {
                                final updated = Set<String>.from(_localFilters.paces);
                                if (selected) {
                                  updated.add(pace);
                                } else {
                                  updated.remove(pace);
                                }
                                _updateFilter(_localFilters.copyWith(paces: updated));
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Gender
                  _buildFilterSection(
                    title: 'Who is this walk for?',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.genderOptions
                          .map(
                            (gender) => FilterChip(
                              label: Text(gender),
                              selected: _localFilters.genders.contains(gender),
                              onSelected: (selected) {
                                final updated = Set<String>.from(_localFilters.genders);
                                if (selected) {
                                  updated.add(gender);
                                } else {
                                  updated.remove(gender);
                                }
                                _updateFilter(_localFilters.copyWith(genders: updated));
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Comfort Level
                  _buildFilterSection(
                    title: 'Vibe',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.comfortOptions
                          .map(
                            (comfort) => FilterChip(
                              label: Text(comfort),
                              selected: _localFilters.comfortLevel == comfort,
                              onSelected: (selected) {
                                if (selected) {
                                  _updateFilter(_localFilters.copyWith(comfortLevel: comfort));
                                } else {
                                  _updateFilter(_localFilters.copyWith(comfortLevel: null));
                                }
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Experience Level
                  _buildFilterSection(
                    title: 'Experience Level',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.experienceOptions
                          .map(
                            (exp) => FilterChip(
                              label: Text(exp),
                              selected: _localFilters.experienceLevel == exp,
                              onSelected: (selected) {
                                if (selected) {
                                  _updateFilter(_localFilters.copyWith(experienceLevel: exp));
                                } else {
                                  _updateFilter(_localFilters.copyWith(experienceLevel: null));
                                }
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Cities
                  _buildFilterSection(
                    title: 'Cities',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_localFilters.cities.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _localFilters.cities
                                .map(
                                  (city) => InputChip(
                                    label: Text(city),
                                    onDeleted: () {
                                      final updated = Set<String>.from(_localFilters.cities);
                                      updated.remove(city);
                                      _updateFilter(_localFilters.copyWith(cities: updated));
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            widget.onAddCity();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add city'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Date Range
                  _buildFilterSection(
                    title: 'Date Range',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            widget.onPickDateRange();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(widget.dateRangeLabel()),
                        ),
                        if (_localFilters.startDate != null || _localFilters.endDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton.icon(
                              onPressed: () {
                                widget.onClearDateRange();
                                _updateFilter(_localFilters.copyWith(startDate: null, endDate: null));
                              },
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear dates'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Toggles
                  _buildFilterSection(
                    title: 'More Options',
                    child: Column(
                      children: [
                        CheckboxListTile(
                          title: const Text('Recurring walks only'),
                          value: _localFilters.recurringOnly,
                          onChanged: (value) {
                            _updateFilter(_localFilters.copyWith(recurringOnly: value ?? false));
                          },
                        ),
                        CheckboxListTile(
                          title: const Text('With photos only'),
                          value: _localFilters.withPhotosOnly,
                          onChanged: (value) {
                            _updateFilter(_localFilters.copyWith(withPhotosOnly: value ?? false));
                          },
                        ),
                        CheckboxListTile(
                          title: const Text('Include private walks'),
                          value: _localFilters.includePrivate,
                          onChanged: (value) {
                            _updateFilter(_localFilters.copyWith(includePrivate: value ?? false));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Save filter set button
                  FilledButton.icon(
                    onPressed: widget.onSaveFilters,
                    icon: const Icon(Icons.bookmark_add),
                    label: const Text('Save this filter set'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

