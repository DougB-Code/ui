/// Provides reusable panel primitives for Aurora section workspaces.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';

/// PanelSplit describes the default and allowed split ratios for two panels.
class PanelSplit {
  /// Creates split ratio constraints for a two-panel workspace.
  const PanelSplit({required this.left, this.min = 0.2, this.max = 0.8});

  /// Initial fraction assigned to the left panel.
  final double left;

  /// Minimum allowed left panel fraction while dragging.
  final double min;

  /// Maximum allowed left panel fraction while dragging.
  final double max;
}

/// SectionLayout describes one two-panel app section composition.
class SectionLayout {
  /// Creates a section layout with reusable panels.
  const SectionLayout({
    required this.split,
    required this.left,
    required this.right,
  });

  /// Split ratio configuration.
  final PanelSplit split;

  /// Left panel widget.
  final Widget left;

  /// Right panel widget.
  final Widget right;
}

/// SplitPanelShell renders a reusable resizable two-panel workspace.
class SplitPanelShell extends StatefulWidget {
  /// Creates a two-panel workspace shell.
  const SplitPanelShell({
    super.key,
    required this.left,
    required this.right,
    this.split = const PanelSplit(left: 0.5),
  });

  /// Left panel widget.
  final Widget left;

  /// Right panel widget.
  final Widget right;

  /// Split ratio configuration.
  final PanelSplit split;

  @override
  State<SplitPanelShell> createState() => _SplitPanelShellState();
}

class _SplitPanelShellState extends State<SplitPanelShell> {
  static const double _handleHitWidth = 12;

  late double _leftPaneFraction = widget.split.left;

  /// Updates the initial split when switching section layouts.
  @override
  void didUpdateWidget(covariant SplitPanelShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.split.left != widget.split.left) {
      _leftPaneFraction = widget.split.left;
    }
  }

  /// Builds the split shell and drag handle.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 940) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: constraints.maxHeight, child: widget.left),
                SizedBox(height: constraints.maxHeight, child: widget.right),
              ],
            ),
          );
        }
        final totalWidth = constraints.maxWidth;
        final leftWidth = totalWidth * _leftPaneFraction;
        final rightWidth = totalWidth - leftWidth;
        return Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: leftWidth,
              child: widget.left,
            ),
            Positioned(
              left: leftWidth,
              top: 0,
              bottom: 0,
              width: rightWidth,
              child: widget.right,
            ),
            Positioned(
              left: leftWidth - (_handleHitWidth / 2),
              top: 0,
              bottom: 0,
              width: _handleHitWidth,
              child: _SplitPanelHandle(
                onDragUpdate: (details) => _resizePanes(details, totalWidth),
              ),
            ),
          ],
        );
      },
    );
  }

  void _resizePanes(DragUpdateDetails details, double paneWidth) {
    if (paneWidth <= 0) {
      return;
    }
    setState(() {
      _leftPaneFraction =
          ((_leftPaneFraction * paneWidth + details.delta.dx) / paneWidth)
              .clamp(widget.split.min, widget.split.max);
    });
  }
}

class _SplitPanelHandle extends StatefulWidget {
  const _SplitPanelHandle({required this.onDragUpdate});

  final GestureDragUpdateCallback onDragUpdate;

  @override
  State<_SplitPanelHandle> createState() => _SplitPanelHandleState();
}

class _SplitPanelHandleState extends State<_SplitPanelHandle> {
  bool _active = false;

  /// Builds the draggable divider for split panel panes.
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => _setActive(true),
      onExit: (_) => _setActive(false),
      child: GestureDetector(
        key: const ValueKey<String>('command-split-handle'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _setActive(true),
        onHorizontalDragUpdate: widget.onDragUpdate,
        onHorizontalDragEnd: (_) => _setActive(false),
        onHorizontalDragCancel: () => _setActive(false),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AuroraColors.border,
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: _active ? 4 : 0,
              color: AuroraColors.green,
            ),
          ],
        ),
      ),
    );
  }

  void _setActive(bool value) {
    if (_active == value) {
      return;
    }
    setState(() {
      _active = value;
    });
  }
}

/// SwitcherPanelArea describes one selectable content area.
class SwitcherPanelArea {
  /// Creates a selectable panel area.
  const SwitcherPanelArea({
    required this.title,
    required this.icon,
    required this.builder,
  });

  /// Area title.
  final String title;

  /// Area icon.
  final IconData icon;

  /// Builds filtered area content.
  final Widget Function(String query) builder;
}

/// SwitcherPanel is a high-density command panel with area and filter controls.
class SwitcherPanel extends StatefulWidget {
  /// Creates a switchable high-density panel.
  const SwitcherPanel({super.key, required this.areas});

  /// Selectable content areas.
  final List<SwitcherPanelArea> areas;

  @override
  State<SwitcherPanel> createState() => _SwitcherPanelState();
}

class _SwitcherPanelState extends State<SwitcherPanel> {
  final TextEditingController _filterController = TextEditingController();
  int _selectedIndex = 0;
  String _query = '';

  /// Cleans up search field state.
  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  /// Builds a dense command content panel with area selection and filtering.
  @override
  Widget build(BuildContext context) {
    final areas = widget.areas;
    final selectedArea = areas[_selectedIndex.clamp(0, areas.length - 1)];
    return ColoredBox(
      color: const Color(0xfffffcf8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 38,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _selectNextArea,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              selectedArea.title.toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AuroraColors.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _SwitcherPanelSelect(
                        areas: areas,
                        selectedIndex: _selectedIndex,
                        onChanged: _selectArea,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: <Widget>[
                      for (var index = 0; index < areas.length; index++)
                        _SwitcherPanelQuickSelect(
                          icon: areas[index].icon,
                          selected: index == _selectedIndex,
                          tooltip: areas[index].title,
                          onPressed: () => _selectArea(index),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: TextField(
                    key: ValueKey<String>(
                      'command-panel-filter-${selectedArea.title}',
                    ),
                    controller: _filterController,
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: AuroraColors.muted,
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 36),
                      hintText: 'Filter...',
                      hintStyle: const TextStyle(color: AuroraColors.muted),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: AuroraColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AuroraColors.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AuroraColors.border,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AuroraColors.border),
          Expanded(child: selectedArea.builder(_query)),
        ],
      ),
    );
  }

  void _selectNextArea() {
    _selectArea((_selectedIndex + 1) % widget.areas.length);
  }

  void _selectArea(int index) {
    setState(() {
      _selectedIndex = index;
      _query = '';
      _filterController.clear();
    });
  }
}

class _SwitcherPanelSelect extends StatelessWidget {
  const _SwitcherPanelSelect({
    required this.areas,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<SwitcherPanelArea> areas;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Builds the compact area dropdown beside the panel title.
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 38,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AuroraColors.surface,
          border: Border.all(color: AuroraColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: selectedIndex,
            isDense: true,
            isExpanded: true,
            icon: const Icon(Icons.expand_more, size: 18),
            selectedItemBuilder: (context) {
              return <Widget>[
                for (final area in areas)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(area.title, overflow: TextOverflow.ellipsis),
                  ),
              ];
            },
            items: <DropdownMenuItem<int>>[
              for (var index = 0; index < areas.length; index++)
                DropdownMenuItem<int>(
                  value: index,
                  child: Text(
                    areas[index].title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _SwitcherPanelQuickSelect extends StatelessWidget {
  const _SwitcherPanelQuickSelect({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onPressed;

  /// Builds one compact icon selector for a switcher panel area.
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: selected ? AuroraColors.greenSoft : AuroraColors.panel,
            border: Border.all(
              color: selected ? AuroraColors.green : AuroraColors.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? AuroraColors.green : AuroraColors.muted,
          ),
        ),
      ),
    );
  }
}

/// CollectionPanelItem describes one dynamic content item.
class CollectionPanelItem<T> {
  /// Creates a dynamic collection panel item.
  const CollectionPanelItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.value,
    this.detail = '',
    this.badge = '',
  });

  /// Stable item identifier.
  final String id;

  /// Display label.
  final String label;

  /// Display icon.
  final IconData icon;

  /// Backing value for the selected item editor.
  final T value;

  /// Optional supporting detail.
  final String detail;

  /// Optional status badge.
  final String badge;
}

/// CollectionSwitcherPanel renders dynamic same-type content panels.
class CollectionSwitcherPanel<T> extends StatefulWidget {
  /// Creates a managed collection switcher panel.
  const CollectionSwitcherPanel({
    super.key,
    required this.title,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    required this.builder,
    this.onCreate,
    this.onDuplicate,
    this.onDelete,
    this.emptyLabel = 'No items configured',
  });

  /// Panel title.
  final String title;

  /// Dynamic collection items.
  final List<CollectionPanelItem<T>> items;

  /// Currently selected item id.
  final String? selectedId;

  /// Selection callback.
  final ValueChanged<String> onSelect;

  /// Selected item content builder.
  final Widget Function(T value, String query) builder;

  /// Optional create callback.
  final VoidCallback? onCreate;

  /// Optional duplicate callback for the selected item.
  final ValueChanged<T>? onDuplicate;

  /// Optional delete callback for the selected item.
  final ValueChanged<T>? onDelete;

  /// Empty collection label.
  final String emptyLabel;

  @override
  State<CollectionSwitcherPanel<T>> createState() =>
      _CollectionSwitcherPanelState<T>();
}

class _CollectionSwitcherPanelState<T>
    extends State<CollectionSwitcherPanel<T>> {
  final TextEditingController _filterController = TextEditingController();
  String _query = '';

  /// Cleans up filter input state.
  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  /// Builds a high-density panel for a dynamic collection.
  @override
  Widget build(BuildContext context) {
    final selectedItem = _selectedItem();
    return ColoredBox(
      color: const Color(0xfffffcf8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 38,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.title.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AuroraColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (widget.items.isNotEmpty)
                        _CollectionPanelSelect<T>(
                          items: widget.items,
                          selectedId: selectedItem?.id,
                          onChanged: _selectItem,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (final item in widget.items)
                              _CollectionQuickSelect(
                                icon: item.icon,
                                selected: item.id == selectedItem?.id,
                                tooltip: item.label,
                                onPressed: () => _selectItem(item.id),
                              ),
                          ],
                        ),
                      ),
                    ),
                    _CollectionActionButton(
                      icon: Icons.add,
                      tooltip: 'Add',
                      onPressed: widget.onCreate,
                    ),
                    _CollectionActionButton(
                      icon: Icons.content_copy,
                      tooltip: 'Duplicate',
                      onPressed:
                          selectedItem == null || widget.onDuplicate == null
                          ? null
                          : () => widget.onDuplicate!(selectedItem.value),
                    ),
                    _CollectionActionButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Remove',
                      onPressed: selectedItem == null || widget.onDelete == null
                          ? null
                          : () => widget.onDelete!(selectedItem.value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: TextField(
                    key: ValueKey<String>(
                      'collection-panel-filter-${widget.title}',
                    ),
                    controller: _filterController,
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: AuroraColors.muted,
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 36),
                      hintText: 'Filter selected...',
                      hintStyle: const TextStyle(color: AuroraColors.muted),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: AuroraColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AuroraColors.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AuroraColors.border,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AuroraColors.border),
          Expanded(
            child: selectedItem == null
                ? _CollectionEmptyState(
                    label: widget.emptyLabel,
                    onCreate: widget.onCreate,
                  )
                : widget.builder(selectedItem.value, _query),
          ),
        ],
      ),
    );
  }

  CollectionPanelItem<T>? _selectedItem() {
    if (widget.items.isEmpty) {
      return null;
    }
    final selectedId = widget.selectedId;
    if (selectedId != null) {
      for (final item in widget.items) {
        if (item.id == selectedId) {
          return item;
        }
      }
    }
    return widget.items.first;
  }

  void _selectItem(String id) {
    setState(() {
      _query = '';
      _filterController.clear();
    });
    widget.onSelect(id);
  }
}

class _CollectionPanelSelect<T> extends StatelessWidget {
  const _CollectionPanelSelect({
    required this.items,
    required this.selectedId,
    required this.onChanged,
  });

  final List<CollectionPanelItem<T>> items;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  /// Builds the compact item dropdown beside a collection title.
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 38,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AuroraColors.surface,
          border: Border.all(color: AuroraColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedId,
            isDense: true,
            isExpanded: true,
            menuWidth: 360,
            icon: const Icon(Icons.expand_more, size: 18),
            selectedItemBuilder: (context) {
              return <Widget>[
                for (final item in items)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
              ];
            },
            items: <DropdownMenuItem<String>>[
              for (final item in items)
                DropdownMenuItem<String>(
                  value: item.id,
                  child: _CollectionDropdownLabel(item: item),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _CollectionDropdownLabel<T> extends StatelessWidget {
  const _CollectionDropdownLabel({required this.item});

  final CollectionPanelItem<T> item;

  /// Builds one collection dropdown label.
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(item.icon, size: 16, color: AuroraColors.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(item.label, softWrap: false)),
        if (item.badge.isNotEmpty) ...<Widget>[
          const SizedBox(width: 8),
          Text(
            item.badge,
            style: const TextStyle(color: AuroraColors.green, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _CollectionQuickSelect extends StatelessWidget {
  const _CollectionQuickSelect({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onPressed;

  /// Builds one compact selector for a collection item.
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: selected ? AuroraColors.greenSoft : AuroraColors.panel,
            border: Border.all(
              color: selected ? AuroraColors.green : AuroraColors.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? AuroraColors.green : AuroraColors.muted,
          ),
        ),
      ),
    );
  }
}

class _CollectionActionButton extends StatelessWidget {
  const _CollectionActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Builds one icon-only collection action button.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip,
        child: IconButton.outlined(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _CollectionEmptyState extends StatelessWidget {
  const _CollectionEmptyState({required this.label, required this.onCreate});

  final String label;
  final VoidCallback? onCreate;

  /// Builds an empty collection state with an optional create action.
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: const TextStyle(color: AuroraColors.muted)),
          if (onCreate != null) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ],
      ),
    );
  }
}

/// PanelEmptyState renders a standard empty state for filtered panel content.
class PanelEmptyState extends StatelessWidget {
  /// Creates a panel empty state for a search query.
  const PanelEmptyState({super.key, required this.query});

  /// Filter query that produced no results.
  final String query;

  /// Builds a compact empty state for filtered command panel content.
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No results for "$query"',
        style: const TextStyle(color: AuroraColors.muted),
      ),
    );
  }
}

/// MenuPanelItem describes one item in a reusable menu panel.
class MenuPanelItem {
  /// Creates a menu item for panel navigation.
  const MenuPanelItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.detail,
  });

  /// Stable selection key.
  final String key;

  /// Display label.
  final String label;

  /// Display icon.
  final IconData icon;

  /// Short supporting description.
  final String detail;
}

/// MenuPanel renders a vertical sub-navigation panel.
class MenuPanel extends StatelessWidget {
  /// Creates a reusable menu panel.
  const MenuPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.selectedKey,
    required this.onSelected,
  });

  /// Panel title.
  final String title;

  /// Supporting subtitle.
  final String subtitle;

  /// Menu items.
  final List<MenuPanelItem> items;

  /// Currently selected item key.
  final String selectedKey;

  /// Selection callback.
  final ValueChanged<String> onSelected;

  /// Builds the menu panel.
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xfffffcf8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(color: AuroraColors.muted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AuroraColors.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                for (final item in items)
                  _MenuPanelTile(
                    item: item,
                    selected: selectedKey == item.key,
                    onTap: () => onSelected(item.key),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuPanelTile extends StatelessWidget {
  const _MenuPanelTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final MenuPanelItem item;
  final bool selected;
  final VoidCallback onTap;

  /// Builds one menu panel tile.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AuroraColors.greenSoft : AuroraColors.surface,
            border: Border.all(
              color: selected ? AuroraColors.green : AuroraColors.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                item.icon,
                color: selected ? AuroraColors.green : AuroraColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AuroraColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AuroraColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// DetailPanel renders a right-side header and content area.
class DetailPanel extends StatelessWidget {
  /// Creates a reusable details panel.
  const DetailPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  /// Panel title.
  final String title;

  /// Supporting subtitle.
  final String subtitle;

  /// Panel body.
  final Widget child;

  /// Builds the detail panel.
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AuroraColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AuroraColors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(color: AuroraColors.muted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AuroraColors.border),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// FormPanel renders grouped form content with standard padding.
class FormPanel extends StatelessWidget {
  /// Creates a reusable form panel.
  const FormPanel({super.key, required this.children});

  /// Form children.
  final List<Widget> children;

  /// Builds a scrollable form body.
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(24), children: children);
  }
}

/// StatusPanel renders process and endpoint status rows.
class StatusPanel extends StatelessWidget {
  /// Creates a reusable status panel.
  const StatusPanel({super.key, required this.children});

  /// Status row widgets.
  final List<Widget> children;

  /// Builds a status panel body.
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(24), children: children);
  }
}

/// StatusRow renders one service/process status line.
class StatusRow extends StatelessWidget {
  /// Creates a reusable status row.
  const StatusRow({
    super.key,
    required this.name,
    required this.url,
    required this.state,
    required this.message,
  });

  /// Status subject name.
  final String name;

  /// Endpoint or path detail.
  final String url;

  /// Current connection state.
  final ConnectionStateKind state;

  /// Supporting status message.
  final String message;

  /// Builds one reusable connection status row.
  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      ConnectionStateKind.connected => AuroraColors.green,
      ConnectionStateKind.disconnected => AuroraColors.coral,
      ConnectionStateKind.unknown => AuroraColors.muted,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xfffffcf8),
        border: Border.all(color: AuroraColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 14),
          SizedBox(
            width: 160,
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(child: Text(url, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              message,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AuroraColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// ChatPanel renders chat timeline content in a section panel.
class ChatPanel extends StatelessWidget {
  /// Creates a chat panel body.
  const ChatPanel({super.key, required this.children, required this.empty});

  /// Timeline children.
  final List<Widget> children;

  /// Empty state widget.
  final Widget empty;

  /// Builds the chat panel.
  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return empty;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      children: children,
    );
  }
}
