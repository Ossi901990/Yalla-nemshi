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
    return count;
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
    final activeFilterCount = _countActiveFilters();

    return Scaffold(
      backgroundColor: getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Walk search'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _runSearch(reset: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _buildSearchBox(theme, isDark, activeFilterCount),
              const SizedBox(height: 12),
              _buildSuggestionList(theme),
              const SizedBox(height: 16),
              _buildHistorySection(theme),
              const SizedBox(height: 16),
              _buildPopularTagsSection(theme),
              const SizedBox(height: 16),
              _buildSavedFiltersSection(theme),
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

  Widget _buildSearchBox(ThemeData theme, bool isDark, int activeFilterCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find a walk that matches your vibe',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : kTextPrimary,
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
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),
                IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.tune),
                      if (activeFilterCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            constraints: const BoxConstraints(minWidth: 18),
                            alignment: Alignment.center,
                            child: Text(
                              activeFilterCount > 9 ? '9+' : '$activeFilterCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: () => _showFilterModal(context, theme, isDark),
                  tooltip: activeFilterCount > 0
                      ? 'Filters ($activeFilterCount active)'
                      : 'Filters',
                ),
              ],
            ),
            filled: true,
            fillColor: isDark ? Colors.white12 : Colors.white,
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
            // Header with save and close buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Filters',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.bookmark_add_outlined),
                        onPressed: widget.onSaveFilters,
                        tooltip: 'Save filter set',
                      ),
                    ],
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
                            (tag) {
                              final selected = _localFilters.tags.contains(tag);
                              return _buildStyledChip(
                                label: tag,
                                selected: selected,
                                onTap: () {
                                  final updated = Set<String>.from(_localFilters.tags);
                                  if (selected) {
                                    updated.remove(tag);
                                  } else {
                                    updated.add(tag);
                                  }
                                  _updateFilter(_localFilters.copyWith(tags: updated));
                                },
                              );
                            },
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
                            (pace) {
                              final selected = _localFilters.paces.contains(pace);
                              return _buildStyledChip(
                                label: pace,
                                selected: selected,
                                onTap: () {
                                  final updated = Set<String>.from(_localFilters.paces);
                                  if (selected) {
                                    updated.remove(pace);
                                  } else {
                                    updated.add(pace);
                                  }
                                  _updateFilter(_localFilters.copyWith(paces: updated));
                                },
                              );
                            },
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
                            (gender) {
                              final selected = _localFilters.genders.contains(gender);
                              return _buildStyledChip(
                                label: gender,
                                selected: selected,
                                onTap: () {
                                  final updated = Set<String>.from(_localFilters.genders);
                                  if (selected) {
                                    updated.remove(gender);
                                  } else {
                                    updated.add(gender);
                                  }
                                  _updateFilter(_localFilters.copyWith(genders: updated));
                                },
                              );
                            },
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
                            (comfort) {
                              final selected = _localFilters.comfortLevel == comfort;
                              return _buildStyledChip(
                                label: comfort,
                                selected: selected,
                                onTap: () {
                                  if (selected) {
                                    _updateFilter(_localFilters.copyWith(comfortLevel: null));
                                  } else {
                                    _updateFilter(_localFilters.copyWith(comfortLevel: comfort));
                                  }
                                },
                              );
                            },
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
                            (exp) {
                              final selected = _localFilters.experienceLevel == exp;
                              return _buildStyledChip(
                                label: exp,
                                selected: selected,
                                onTap: () {
                                  if (selected) {
                                    _updateFilter(_localFilters.copyWith(experienceLevel: null));
                                  } else {
                                    _updateFilter(_localFilters.copyWith(experienceLevel: exp));
                                  }
                                },
                              );
                            },
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
                      ],
                    ),
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

  /// Build a styled filter chip matching Walks_screen tag style
  Widget _buildStyledChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? Colors.teal.shade100 : Colors.transparent,
          border: Border.all(
            color: selected ? Colors.teal : Colors.grey.shade400,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.teal : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

