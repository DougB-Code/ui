import 'package:flutter/material.dart';
import 'package:ui/shared/ui.dart';

typedef AppSidePanelContentBuilder =
    Widget Function(BuildContext context, String searchQuery);
typedef AppSidePanelControlsBuilder =
    Widget? Function(BuildContext context, String searchQuery);
typedef AppSidePanelQuickActionsBuilder =
    Widget? Function(BuildContext context, String searchQuery);
typedef AppDenseSidePanelSearchFields<T> = Iterable<String> Function(T item);
typedef AppDenseSidePanelRowBuilder<T> =
    Widget Function(
      BuildContext context,
      T item,
      bool selected,
      VoidCallback onTap,
    );
typedef AppDenseSidePanelHeaderBuilder<T> =
    Widget? Function(
      BuildContext context,
      List<T> entries,
      List<T> filteredEntries,
      String searchQuery,
    );

enum AppSidePanelSide { left, right }

class AppSidePanelSection {
  const AppSidePanelSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.quickActionsBuilder,
    this.controlsBuilder,
  });

  final String id;
  final String label;
  final IconData icon;
  final AppSidePanelContentBuilder builder;
  final AppSidePanelQuickActionsBuilder? quickActionsBuilder;
  final AppSidePanelControlsBuilder? controlsBuilder;
}

class AppDenseSidePanelSection<T> {
  const AppDenseSidePanelSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.entries,
    required this.searchFields,
    required this.rowBuilder,
    required this.emptyTitle,
    required this.emptyBody,
    this.quickActionsBuilder,
    this.headerBuilder,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<T> entries;
  final AppDenseSidePanelSearchFields<T> searchFields;
  final AppDenseSidePanelRowBuilder<T> rowBuilder;
  final String emptyTitle;
  final String emptyBody;
  final AppSidePanelQuickActionsBuilder? quickActionsBuilder;
  final AppDenseSidePanelHeaderBuilder<T>? headerBuilder;
}

class AppSidePanel extends StatefulWidget {
  const AppSidePanel({
    super.key,
    required this.sections,
    required this.searchHintText,
    this.side = AppSidePanelSide.left,
    this.initialSectionId,
    this.initialSearchQuery = '',
    this.onSectionChanged,
    this.onSearchChanged,
    this.headerActions = const <Widget>[],
    this.emptyTitle = 'No panels available',
    this.emptyBody = 'Add a panel section to render side panel content.',
    this.headerPadding = const EdgeInsets.fromLTRB(20, 18, 16, 0),
    this.controlsPadding = const EdgeInsets.fromLTRB(20, 14, 20, 0),
    this.bodyPadding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
  });

  final List<AppSidePanelSection> sections;
  final String searchHintText;
  final AppSidePanelSide side;
  final String? initialSectionId;
  final String initialSearchQuery;
  final ValueChanged<String>? onSectionChanged;
  final ValueChanged<String>? onSearchChanged;
  final List<Widget> headerActions;
  final String emptyTitle;
  final String emptyBody;
  final EdgeInsets headerPadding;
  final EdgeInsets controlsPadding;
  final EdgeInsets bodyPadding;

  @override
  State<AppSidePanel> createState() => _AppSidePanelState();
}

class _AppSidePanelState extends State<AppSidePanel> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.initialSearchQuery,
  );
  final GlobalKey _menuButtonKey = GlobalKey();

  String? _activeSectionId;

  @override
  void initState() {
    super.initState();
    _activeSectionId = _resolveInitialSectionId();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void didUpdateWidget(covariant AppSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initialSectionChanged =
        widget.initialSectionId != null &&
        widget.initialSectionId != oldWidget.initialSectionId;
    if (initialSectionChanged && _hasSection(widget.initialSectionId)) {
      _activeSectionId = widget.initialSectionId;
    } else if (!_hasSection(_activeSectionId)) {
      _activeSectionId = _resolveInitialSectionId();
    }

    final initialSearchChanged =
        widget.initialSearchQuery != oldWidget.initialSearchQuery &&
        widget.initialSearchQuery != _searchController.text;
    if (initialSearchChanged) {
      _searchController.text = widget.initialSearchQuery;
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  AppSidePanelSection? get _activeSection {
    if (widget.sections.isEmpty) {
      return null;
    }
    final selectedId = _activeSectionId;
    if (selectedId == null) {
      return widget.sections.first;
    }
    for (final section in widget.sections) {
      if (section.id == selectedId) {
        return section;
      }
    }
    return widget.sections.first;
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    widget.onSearchChanged?.call(_searchController.text);
  }

  String? _resolveInitialSectionId() {
    if (_hasSection(widget.initialSectionId)) {
      return widget.initialSectionId;
    }
    return widget.sections.isEmpty ? null : widget.sections.first.id;
  }

  bool _hasSection(String? sectionId) {
    if (sectionId == null) {
      return false;
    }
    return widget.sections.any(
      (AppSidePanelSection section) => section.id == sectionId,
    );
  }

  void _selectSection(String sectionId) {
    if (_activeSectionId == sectionId) {
      return;
    }
    setState(() => _activeSectionId = sectionId);
    widget.onSectionChanged?.call(sectionId);
  }

  void _cycleSections() {
    if (widget.sections.length <= 1) {
      return;
    }
    final activeSection = _activeSection;
    final activeIndex = activeSection == null
        ? -1
        : widget.sections.indexWhere(
            (AppSidePanelSection section) => section.id == activeSection.id,
          );
    final nextIndex = activeIndex < 0
        ? 0
        : (activeIndex + 1) % widget.sections.length;
    _selectSection(widget.sections[nextIndex].id);
  }

  Future<void> _showSectionMenu() async {
    final menuContext = _menuButtonKey.currentContext;
    if (menuContext == null || widget.sections.isEmpty) {
      return;
    }
    final button = menuContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(menuContext).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) {
      return;
    }

    final buttonRect = Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );
    final selected = await showMenu<String>(
      context: context,
      color: const Color(0xFF111B29),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      position: RelativeRect.fromRect(buttonRect, Offset.zero & overlay.size),
      items: widget.sections.map((AppSidePanelSection section) {
        final selectedSection = section.id == _activeSection?.id;
        return PopupMenuItem<String>(
          value: section.id,
          child: Row(
            children: [
              Icon(
                selectedSection
                    ? Icons.check_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: selectedSection ? infoColor : textSubtleColor,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  section.label,
                  style: TextStyle(
                    color: selectedSection ? infoColor : textPrimaryColor,
                    fontWeight: selectedSection
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
    if (selected != null) {
      _selectSection(selected);
    }
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) {
      return;
    }
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final activeSection = _activeSection;
    final searchQuery = _searchController.text;
    final hasSearch = searchQuery.trim().isNotEmpty;
    final showNavigation = widget.sections.length > 1;
    final quickActions = activeSection?.quickActionsBuilder?.call(
      context,
      searchQuery,
    );
    final sectionControls = activeSection?.controlsBuilder?.call(
      context,
      searchQuery,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: widget.headerPadding,
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: showNavigation
                      ? 'Cycle panels'
                      : 'Active panel title',
                  child: TextButton(
                    onPressed: showNavigation ? _cycleSections : null,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: textPrimaryColor,
                    ),
                    child: Text(
                      (activeSection?.label ?? 'Panels').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textMutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
              ...widget.headerActions,
              Tooltip(
                message: 'Open panel menu',
                child: IconButton(
                  key: _menuButtonKey,
                  onPressed: showNavigation ? _showSectionMenu : null,
                  splashRadius: 18,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  color: textMutedColor,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: widget.controlsPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showNavigation || quickActions != null) ...[
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final quickButtons = showNavigation
                        ? Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final section in widget.sections)
                                Tooltip(
                                  message: section.label,
                                  child: _SidePanelIconButton(
                                    icon: section.icon,
                                    selected: section.id == activeSection?.id,
                                    onTap: () => _selectSection(section.id),
                                  ),
                                ),
                            ],
                          )
                        : const SizedBox.shrink();

                    if (quickActions == null) {
                      return quickButtons;
                    }

                    if (!showNavigation) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: quickActions,
                      );
                    }

                    if (constraints.maxWidth < 560) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          quickButtons,
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: quickActions,
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: quickButtons),
                        const SizedBox(width: 12),
                        quickActions,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.searchHintText,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: textSubtleColor,
                  ),
                  suffixIcon: hasSearch
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                  fillColor: const Color(0xB00C1220),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: borderColor.withValues(alpha: 0.82),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: infoColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              if (sectionControls != null) ...[
                const SizedBox(height: 16),
                sectionControls,
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: borderColor.withValues(alpha: 0.85)),
        Expanded(
          child: Padding(
            padding: widget.bodyPadding,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: KeyedSubtree(
                key: ValueKey<String>(activeSection?.id ?? 'empty'),
                child: activeSection == null
                    ? EmptyState(
                        title: widget.emptyTitle,
                        body: widget.emptyBody,
                      )
                    : activeSection.builder(context, searchQuery),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AppDenseSidePanel<T> extends StatelessWidget {
  const AppDenseSidePanel({
    super.key,
    required this.sections,
    required this.searchHintText,
    required this.selectedEntryId,
    required this.entryId,
    required this.onSelectEntry,
    this.side = AppSidePanelSide.left,
    this.initialSectionId,
    this.initialSearchQuery = '',
    this.onSectionChanged,
    this.onSearchChanged,
    this.headerActions = const <Widget>[],
    this.emptyTitle = 'No panels available',
    this.emptyBody = 'Add a panel section to render side panel content.',
    this.headerPadding = const EdgeInsets.fromLTRB(20, 18, 16, 0),
    this.controlsPadding = const EdgeInsets.fromLTRB(20, 14, 20, 0),
    this.bodyPadding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
  });

  final List<AppDenseSidePanelSection<T>> sections;
  final String searchHintText;
  final String? selectedEntryId;
  final String Function(T item) entryId;
  final ValueChanged<T> onSelectEntry;
  final AppSidePanelSide side;
  final String? initialSectionId;
  final String initialSearchQuery;
  final ValueChanged<String>? onSectionChanged;
  final ValueChanged<String>? onSearchChanged;
  final List<Widget> headerActions;
  final String emptyTitle;
  final String emptyBody;
  final EdgeInsets headerPadding;
  final EdgeInsets controlsPadding;
  final EdgeInsets bodyPadding;

  @override
  Widget build(BuildContext context) {
    return AppSidePanel(
      side: side,
      searchHintText: searchHintText,
      initialSectionId: initialSectionId,
      initialSearchQuery: initialSearchQuery,
      onSectionChanged: onSectionChanged,
      onSearchChanged: onSearchChanged,
      headerActions: headerActions,
      emptyTitle: emptyTitle,
      emptyBody: emptyBody,
      headerPadding: headerPadding,
      controlsPadding: controlsPadding,
      bodyPadding: bodyPadding,
      sections: sections
          .map((AppDenseSidePanelSection<T> section) {
            return AppSidePanelSection(
              id: section.id,
              label: section.label,
              icon: section.icon,
              quickActionsBuilder: section.quickActionsBuilder,
              controlsBuilder: (BuildContext context, String searchQuery) {
                if (section.headerBuilder == null) {
                  return null;
                }
                final filteredEntries = AppFuzzySearch.filter<T>(
                  section.entries,
                  searchQuery,
                  section.searchFields,
                );
                return section.headerBuilder!(
                  context,
                  section.entries,
                  filteredEntries,
                  searchQuery,
                );
              },
              builder: (BuildContext context, String searchQuery) {
                final filteredEntries = AppFuzzySearch.filter<T>(
                  section.entries,
                  searchQuery,
                  section.searchFields,
                );
                return _DenseSidePanelSectionContent<T>(
                  entries: section.entries,
                  filteredEntries: filteredEntries,
                  selectedEntryId: selectedEntryId,
                  entryId: entryId,
                  emptyTitle: section.emptyTitle,
                  emptyBody: section.emptyBody,
                  rowBuilder: section.rowBuilder,
                  onSelectEntry: onSelectEntry,
                );
              },
            );
          })
          .toList(growable: false),
    );
  }
}

class _DenseSidePanelSectionContent<T> extends StatelessWidget {
  const _DenseSidePanelSectionContent({
    required this.entries,
    required this.filteredEntries,
    required this.selectedEntryId,
    required this.entryId,
    required this.emptyTitle,
    required this.emptyBody,
    required this.rowBuilder,
    required this.onSelectEntry,
  });

  final List<T> entries;
  final List<T> filteredEntries;
  final String? selectedEntryId;
  final String Function(T item) entryId;
  final String emptyTitle;
  final String emptyBody;
  final AppDenseSidePanelRowBuilder<T> rowBuilder;
  final ValueChanged<T> onSelectEntry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: filteredEntries.isEmpty
              ? EmptyState(title: emptyTitle, body: emptyBody)
              : ListView.separated(
                  itemCount: filteredEntries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final entry = filteredEntries[index];
                    return rowBuilder(
                      context,
                      entry,
                      entryId(entry) == selectedEntryId,
                      () => onSelectEntry(entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class AppDenseSidePanelRow extends StatelessWidget {
  const AppDenseSidePanelRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle = '',
    this.trailing,
    this.footer = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? const Color(0xE3213045) : const Color(0xB4182231),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? infoColor.withValues(alpha: 0.75) : borderColor,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textMutedColor, height: 1.4),
                ),
              ],
              if (footer.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: footer),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SidePanelIconButton extends StatelessWidget {
  const _SidePanelIconButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: selected
              ? infoColor.withValues(alpha: 0.14)
              : const Color(0x66141E2C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? infoColor.withValues(alpha: 0.9)
                : borderColor.withValues(alpha: 0.82),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? infoColor : textMutedColor,
        ),
      ),
    );
  }
}

class AppFuzzySearch {
  const AppFuzzySearch._();

  static List<T> filter<T>(
    Iterable<T> items,
    String query,
    Iterable<String> Function(T item) fieldsForItem,
  ) {
    final normalizedQuery = _normalize(query);
    final candidates = items.toList(growable: false);
    if (normalizedQuery.isEmpty) {
      return candidates;
    }

    final scored = <({T item, int index, int score})>[];
    for (var index = 0; index < candidates.length; index++) {
      final item = candidates[index];
      final score = AppFuzzySearch.score(query, fieldsForItem(item));
      if (score > 0) {
        scored.add((item: item, index: index, score: score));
      }
    }

    scored.sort((left, right) {
      final scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return left.index.compareTo(right.index);
    });
    return scored.map((result) => result.item).toList(growable: false);
  }

  static bool matches(String query, Iterable<String> fields) {
    return score(query, fields) > 0;
  }

  static int score(String query, Iterable<String> fields) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return 1;
    }

    var bestScore = 0;
    for (final field in fields) {
      final candidateScore = _scoreCandidate(normalizedQuery, field);
      if (candidateScore > bestScore) {
        bestScore = candidateScore;
      }
    }
    return bestScore;
  }

  static int _scoreCandidate(String normalizedQuery, String candidate) {
    final normalizedCandidate = _normalize(candidate);
    if (normalizedCandidate.isEmpty) {
      return 0;
    }
    if (normalizedCandidate == normalizedQuery) {
      return 1000;
    }
    if (normalizedCandidate.startsWith(normalizedQuery)) {
      return 840 - normalizedCandidate.length;
    }

    final directIndex = normalizedCandidate.indexOf(normalizedQuery);
    if (directIndex >= 0) {
      return 760 - (directIndex * 8);
    }

    final queryTokens = normalizedQuery
        .split(' ')
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    final candidateWords = normalizedCandidate
        .split(RegExp(r'[^a-z0-9]+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);

    if (queryTokens.isNotEmpty &&
        queryTokens.every(
          (String token) => candidateWords.any(
            (String word) => word.startsWith(token) || word.contains(token),
          ),
        )) {
      var prefixMatches = 0;
      for (final token in queryTokens) {
        if (candidateWords.any((String word) => word.startsWith(token))) {
          prefixMatches += 1;
        }
      }
      return 620 + (prefixMatches * 20) - candidateWords.length;
    }

    final compactCandidate = normalizedCandidate.replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final compactQuery = normalizedQuery.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return _subsequenceScore(compactQuery, compactCandidate);
  }

  static int _subsequenceScore(String query, String candidate) {
    if (query.isEmpty || candidate.isEmpty) {
      return 0;
    }

    var queryIndex = 0;
    var consecutive = 0;
    var bestConsecutive = 0;
    var gaps = 0;

    for (
      var candidateIndex = 0;
      candidateIndex < candidate.length && queryIndex < query.length;
      candidateIndex++
    ) {
      if (candidate[candidateIndex] == query[queryIndex]) {
        queryIndex += 1;
        consecutive += 1;
        if (consecutive > bestConsecutive) {
          bestConsecutive = consecutive;
        }
      } else if (queryIndex > 0) {
        gaps += 1;
        consecutive = 0;
      }
    }

    if (queryIndex != query.length) {
      return 0;
    }
    return 360 +
        (bestConsecutive * 24) -
        (gaps * 5) -
        (candidate.length - query.length);
  }

  static String _normalize(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
