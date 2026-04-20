import 'package:flutter/material.dart';

import 'package:ui/shared/ui.dart';

class ConfigWorkspaceShell extends StatelessWidget {
  const ConfigWorkspaceShell({
    super.key,
    required this.stacked,
    required this.collectionPane,
    required this.detailPane,
    this.stackedChild,
    this.collectionFlex = 50,
    this.detailFlex = 50,
    this.stackedCollectionFlex = 46,
    this.stackedDetailFlex = 54,
    this.stackedGap = 16,
    this.minPaneWidth = 320,
    this.dividerHitWidth = 20,
  });

  final bool stacked;
  final Widget collectionPane;
  final Widget detailPane;
  final Widget? stackedChild;
  final int collectionFlex;
  final int detailFlex;
  final int stackedCollectionFlex;
  final int stackedDetailFlex;
  final double stackedGap;
  final double minPaneWidth;
  final double dividerHitWidth;

  @override
  Widget build(BuildContext context) {
    return _ConfigWorkspaceFrame(
      stacked: stacked,
      stackedChild: stackedChild,
      stackedBuilder: () {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(flex: stackedCollectionFlex, child: collectionPane),
              SizedBox(height: stackedGap),
              Expanded(flex: stackedDetailFlex, child: detailPane),
            ],
          ),
        );
      },
      child: _ConfigWorkspaceHorizontalSplit(
        leadingPane: collectionPane,
        trailingPane: detailPane,
        leadingFlex: collectionFlex,
        trailingFlex: detailFlex,
        minLeadingPaneWidth: minPaneWidth,
        minTrailingPaneWidth: minPaneWidth,
        dividerHitWidth: dividerHitWidth,
        dividerKey: const ValueKey<String>('config-workspace-divider'),
        handleKey: const ValueKey<String>('config-workspace-divider-handle'),
      ),
    );
  }
}

class ConfigWorkspaceThreePaneShell extends StatelessWidget {
  const ConfigWorkspaceThreePaneShell({
    super.key,
    required this.stacked,
    required this.collectionPane,
    required this.editorPane,
    required this.detailPane,
    this.showDetailPane = true,
    this.stackedChild,
    this.collectionFlex = 28,
    this.editorFlex = 44,
    this.detailFlex = 28,
    this.stackedCollectionFlex = 28,
    this.stackedEditorFlex = 42,
    this.stackedDetailFlex = 30,
    this.stackedGap = 16,
    this.minCollectionPaneWidth = 320,
    this.minEditorPaneWidth = 360,
    this.minDetailPaneWidth = 320,
    this.dividerHitWidth = 20,
  });

  final bool stacked;
  final Widget collectionPane;
  final Widget editorPane;
  final Widget detailPane;
  final bool showDetailPane;
  final Widget? stackedChild;
  final int collectionFlex;
  final int editorFlex;
  final int detailFlex;
  final int stackedCollectionFlex;
  final int stackedEditorFlex;
  final int stackedDetailFlex;
  final double stackedGap;
  final double minCollectionPaneWidth;
  final double minEditorPaneWidth;
  final double minDetailPaneWidth;
  final double dividerHitWidth;

  @override
  Widget build(BuildContext context) {
    final combinedTrailingMinWidth = showDetailPane
        ? minEditorPaneWidth + minDetailPaneWidth + dividerHitWidth
        : minEditorPaneWidth;
    final trailingPane = showDetailPane
        ? _ConfigWorkspaceHorizontalSplit(
            leadingPane: editorPane,
            trailingPane: detailPane,
            leadingFlex: editorFlex,
            trailingFlex: detailFlex,
            minLeadingPaneWidth: minEditorPaneWidth,
            minTrailingPaneWidth: minDetailPaneWidth,
            dividerHitWidth: dividerHitWidth,
            dividerKey: const ValueKey<String>(
              'config-workspace-detail-divider',
            ),
            handleKey: const ValueKey<String>(
              'config-workspace-detail-divider-handle',
            ),
          )
        : editorPane;

    return _ConfigWorkspaceFrame(
      stacked: stacked,
      stackedChild: stackedChild,
      stackedBuilder: () {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(flex: stackedCollectionFlex, child: collectionPane),
              SizedBox(height: stackedGap),
              Expanded(flex: stackedEditorFlex, child: editorPane),
              if (showDetailPane) ...[
                SizedBox(height: stackedGap),
                Expanded(flex: stackedDetailFlex, child: detailPane),
              ],
            ],
          ),
        );
      },
      child: _ConfigWorkspaceHorizontalSplit(
        leadingPane: collectionPane,
        trailingPane: trailingPane,
        leadingFlex: collectionFlex,
        trailingFlex: editorFlex + (showDetailPane ? detailFlex : 0),
        minLeadingPaneWidth: minCollectionPaneWidth,
        minTrailingPaneWidth: combinedTrailingMinWidth,
        dividerHitWidth: dividerHitWidth,
        dividerKey: const ValueKey<String>('config-workspace-divider'),
        handleKey: const ValueKey<String>('config-workspace-divider-handle'),
      ),
    );
  }
}

class _ConfigWorkspaceFrame extends StatelessWidget {
  const _ConfigWorkspaceFrame({
    required this.stacked,
    required this.stackedBuilder,
    required this.child,
    this.stackedChild,
  });

  final bool stacked;
  final Widget child;
  final Widget? stackedChild;
  final Widget Function() stackedBuilder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x94101929),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: stacked ? stackedChild ?? stackedBuilder() : child,
    );
  }
}

class _ConfigWorkspaceHorizontalSplit extends StatefulWidget {
  const _ConfigWorkspaceHorizontalSplit({
    required this.leadingPane,
    required this.trailingPane,
    required this.leadingFlex,
    required this.trailingFlex,
    required this.minLeadingPaneWidth,
    required this.minTrailingPaneWidth,
    required this.dividerHitWidth,
    required this.dividerKey,
    required this.handleKey,
  });

  final Widget leadingPane;
  final Widget trailingPane;
  final int leadingFlex;
  final int trailingFlex;
  final double minLeadingPaneWidth;
  final double minTrailingPaneWidth;
  final double dividerHitWidth;
  final Key dividerKey;
  final Key handleKey;

  @override
  State<_ConfigWorkspaceHorizontalSplit> createState() =>
      _ConfigWorkspaceHorizontalSplitState();
}

class _ConfigWorkspaceHorizontalSplitState
    extends State<_ConfigWorkspaceHorizontalSplit> {
  double? _leadingFraction;
  bool _dividerHovered = false;
  bool _dividerDragging = false;

  double get _defaultLeadingFraction {
    final total = widget.leadingFlex + widget.trailingFlex;
    if (total <= 0) {
      return 0.5;
    }
    return widget.leadingFlex / total;
  }

  double _clampLeadingFraction(double fraction, double maxWidth) {
    final availableWidth = maxWidth - widget.dividerHitWidth;
    if (availableWidth <= 0) {
      return 0.5;
    }
    final minLeadingFraction = (widget.minLeadingPaneWidth / availableWidth)
        .clamp(0.18, 0.82);
    final maxLeadingFraction =
        1 - (widget.minTrailingPaneWidth / availableWidth).clamp(0.18, 0.82);
    final minFraction = minLeadingFraction.toDouble();
    final maxFraction = maxLeadingFraction.toDouble();
    if (minFraction >= maxFraction) {
      return 0.5;
    }
    return fraction.clamp(minFraction, maxFraction);
  }

  void _syncFractionForWidth(double maxWidth) {
    final currentFraction = _leadingFraction ?? _defaultLeadingFraction;
    final nextFraction = _clampLeadingFraction(currentFraction, maxWidth);
    if (_leadingFraction != nextFraction) {
      _leadingFraction = nextFraction;
    }
  }

  void _setDividerHovered(bool hovered) {
    if (_dividerHovered == hovered) {
      return;
    }
    setState(() => _dividerHovered = hovered);
  }

  void _setDividerDragging(bool dragging) {
    if (_dividerDragging == dragging) {
      return;
    }
    setState(() => _dividerDragging = dragging);
  }

  void _updateFractionFromGlobalDx(double globalDx, double maxWidth) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final localDx = box.globalToLocal(Offset(globalDx, 0)).dx;
    final availableWidth = maxWidth - widget.dividerHitWidth;
    if (availableWidth <= 0) {
      return;
    }
    final rawFraction =
        (localDx - (widget.dividerHitWidth / 2)) / availableWidth;
    final nextFraction = _clampLeadingFraction(rawFraction, maxWidth);
    if (nextFraction == _leadingFraction) {
      return;
    }
    setState(() => _leadingFraction = nextFraction);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _syncFractionForWidth(constraints.maxWidth);
        final leadingFraction = _leadingFraction ?? _defaultLeadingFraction;
        final availableWidth = constraints.maxWidth - widget.dividerHitWidth;
        final leadingWidth = availableWidth * leadingFraction;
        final trailingWidth = availableWidth - leadingWidth;
        final dividerActive = _dividerHovered || _dividerDragging;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: leadingWidth, child: widget.leadingPane),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => _setDividerHovered(true),
              onExit: (_) => _setDividerHovered(false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => _setDividerDragging(true),
                onHorizontalDragUpdate: (DragUpdateDetails details) {
                  _updateFractionFromGlobalDx(
                    details.globalPosition.dx,
                    constraints.maxWidth,
                  );
                },
                onHorizontalDragEnd: (_) => _setDividerDragging(false),
                onHorizontalDragCancel: () => _setDividerDragging(false),
                child: SizedBox(
                  width: widget.dividerHitWidth,
                  child: Center(
                    child: AnimatedContainer(
                      key: widget.dividerKey,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      width: _dividerDragging ? 12 : 10,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: dividerActive
                            ? infoColor.withValues(alpha: 0.10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          width: _dividerDragging ? 3 : 2,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: _dividerDragging
                                ? infoColor
                                : dividerActive
                                ? infoColor.withValues(alpha: 0.78)
                                : borderColor.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: dividerActive
                                ? [
                                    BoxShadow(
                                      color: infoColor.withValues(
                                        alpha: _dividerDragging ? 0.26 : 0.16,
                                      ),
                                      blurRadius: _dividerDragging ? 12 : 8,
                                    ),
                                  ]
                                : const <BoxShadow>[],
                          ),
                          child: Align(
                            alignment: Alignment.center,
                            child: AnimatedContainer(
                              key: widget.handleKey,
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOutCubic,
                              width: _dividerDragging ? 3 : 2,
                              height: dividerActive ? 72 : 52,
                              decoration: BoxDecoration(
                                color: dividerActive
                                    ? textPrimaryColor.withValues(
                                        alpha: _dividerDragging ? 0.88 : 0.70,
                                      )
                                    : textSubtleColor.withValues(alpha: 0.52),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: trailingWidth, child: widget.trailingPane),
          ],
        );
      },
    );
  }
}

class ConfigWorkspacePopupButton<T> extends StatelessWidget {
  const ConfigWorkspacePopupButton({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
  });

  final T value;
  final String label;
  final IconData icon;
  final String tooltip;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final button = context.findRenderObject() as RenderBox?;
            final overlay =
                Overlay.of(context).context.findRenderObject() as RenderBox?;
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
            final selected = await showMenu<T>(
              context: context,
              color: const Color(0xFF111B29),
              position: RelativeRect.fromRect(
                buttonRect,
                Offset.zero & overlay.size,
              ),
              items: items.map((T item) {
                final selectedItem = item == value;
                return PopupMenuItem<T>(
                  value: item,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selectedItem
                            ? Icons.check_rounded
                            : Icons.circle_outlined,
                        size: 16,
                        color: selectedItem ? infoColor : textSubtleColor,
                      ),
                      const SizedBox(width: 10),
                      Flexible(child: Text(itemLabel(item))),
                    ],
                  ),
                );
              }).toList(),
            );
            if (selected != null) {
              onSelected(selected);
            }
          },
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0x80172231),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor.withValues(alpha: 0.85)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: textMutedColor),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textMutedColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConfigWorkspaceTabBar<T> extends StatelessWidget {
  const ConfigWorkspaceTabBar({
    super.key,
    required this.items,
    required this.value,
    required this.labelBuilder,
    required this.onChanged,
    this.indicatorWidth = 58,
  });

  final List<T> items;
  final T value;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;
  final double indicatorWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0x48101825),
        border: Border(
          top: BorderSide(color: borderColor.withValues(alpha: 0.9)),
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.9)),
        ),
      ),
      child: Wrap(
        spacing: 22,
        children: items.map((T item) {
          final selected = item == value;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onChanged(item),
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labelBuilder(item),
                    style: TextStyle(
                      color: selected ? textPrimaryColor : textMutedColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: indicatorWidth,
                    height: 2,
                    decoration: BoxDecoration(
                      color: selected ? infoColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ConfigWorkspaceSectionCard extends StatelessWidget {
  const ConfigWorkspaceSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x7D182130),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: textPrimaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
