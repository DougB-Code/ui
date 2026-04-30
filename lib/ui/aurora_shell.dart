/// Implements the Aurora assistant workspace shell and feature surfaces.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/config_files.dart';
import '../app/local_services.dart';
import '../app/runtime_profile.dart';
import '../app/theme.dart';
import '../domain/models.dart';
import 'panels/panels.dart';
import 'tasks_section.dart';

/// AuroraShell renders the desktop assistant workspace.
class AuroraShell extends StatefulWidget {
  /// Creates the shell bound to an app controller.
  const AuroraShell({super.key, required this.controller});

  /// Shared app controller.
  final AuroraAppController controller;

  @override
  State<AuroraShell> createState() => _AuroraShellState();
}

class _AuroraShellState extends State<AuroraShell> {
  final TextEditingController _commandController = TextEditingController();
  String _section = 'Today';
  String _settingsSection = 'Profiles';
  bool _sidebarExpanded = true;

  /// Cleans up text input state.
  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  /// Builds the main desktop shell.
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          body: ColoredBox(
            color: AuroraColors.surface,
            child: _AppShellFrame(
              selectedSection: _section,
              controller: widget.controller,
              commandController: _commandController,
              sidebarExpanded: _sidebarExpanded,
              onSelected: _selectSection,
              onToggleSidebar: _toggleSidebar,
              onSubmit: _submitCommand,
              onOpenSettings: () => _selectSection('Settings'),
              content: _buildContent(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final panelLayout = _buildPanelLayout();
    if (panelLayout != null) {
      return SplitPanelShell(
        split: panelLayout.split,
        left: panelLayout.left,
        right: panelLayout.right,
      );
    }
    switch (_section) {
      case 'Files':
        return _FullPanelSubShell(
          child: _SourcesPage(workspace: widget.controller.workspace),
        );
      case 'Calendar':
        return _FullPanelSubShell(
          child: _MemoryTimelineRoute(controller: widget.controller),
        );
      case 'People':
        return _FullPanelSubShell(
          child: _MemoryPeopleRoute(controller: widget.controller),
        );
      default:
        return _FullPanelSubShell(
          child: _HomeWorkspace(controller: widget.controller),
        );
    }
  }

  /// Builds the reusable two-panel layout for sections that use command panels.
  SectionLayout? _buildPanelLayout() {
    switch (_section) {
      case 'Chat':
        return SectionLayout(
          split: const PanelSplit(left: 0.62),
          left: _ChatCommandPanel(controller: widget.controller),
          right: _ChatUtilitiesPanel(controller: widget.controller),
        );
      case 'Workflows':
        return SectionLayout(
          split: const PanelSplit(left: 0.5),
          left: _WorkflowCommandPanel(
            controller: widget.controller,
            onBackHome: () => _selectSection('Today'),
          ),
          right: _MemoryCommandPanel(controller: widget.controller),
        );
      case 'Memory':
        return SectionLayout(
          split: const PanelSplit(left: 0.5),
          left: _MemoryLibraryPanel(controller: widget.controller),
          right: _MemoryStewardshipPanel(controller: widget.controller),
        );
      case 'Tasks':
        return SectionLayout(
          split: const PanelSplit(left: 0.58, min: 0.36, max: 0.74),
          left: TasksQueuePanel(controller: widget.controller),
          right: TasksInspectorPanel(controller: widget.controller),
        );
      case 'Settings':
        return SectionLayout(
          split: const PanelSplit(left: 0.25, min: 0.2, max: 0.45),
          left: _SettingsMenuPanel(
            selected: _settingsSection,
            onSelected: (section) {
              setState(() {
                _settingsSection = section;
              });
            },
          ),
          right: _SettingsDetailsPanel(
            controller: widget.controller,
            section: _settingsSection,
          ),
        );
      default:
        return null;
    }
  }

  void _selectSection(String section) {
    setState(() {
      _section = section;
    });
    if (section == 'Chat') {
      widget.controller.openHome();
    } else if (section == 'Workflows') {
      widget.controller.openWorkspace();
    } else if (section == 'Today') {
      widget.controller.openHome();
    }
  }

  void _submitCommand() {
    final value = _commandController.text;
    _commandController.clear();
    setState(() {
      _section = 'Chat';
    });
    widget.controller.sendUserMessage(value);
  }

  void _toggleSidebar() {
    setState(() {
      _sidebarExpanded = !_sidebarExpanded;
    });
  }
}

class _AppShellFrame extends StatelessWidget {
  const _AppShellFrame({
    required this.selectedSection,
    required this.controller,
    required this.commandController,
    required this.sidebarExpanded,
    required this.onSelected,
    required this.onToggleSidebar,
    required this.onSubmit,
    required this.onOpenSettings,
    required this.content,
  });

  final String selectedSection;
  final AuroraAppController controller;
  final TextEditingController commandController;
  final bool sidebarExpanded;
  final ValueChanged<String> onSelected;
  final VoidCallback onToggleSidebar;
  final VoidCallback onSubmit;
  final VoidCallback onOpenSettings;
  final Widget content;

  /// Builds the single app shell that owns navigation and panel placement.
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _Sidebar(
          selected: selectedSection,
          expanded: sidebarExpanded,
          onSelected: onSelected,
          onToggleExpanded: onToggleSidebar,
        ),
        Expanded(
          child: Column(
            children: <Widget>[
              _CommandBar(
                controller: commandController,
                onSubmit: onSubmit,
                onNewChat: controller.createChat,
                onOpenSettings: onOpenSettings,
              ),
              Expanded(child: content),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullPanelSubShell extends StatelessWidget {
  const _FullPanelSubShell({required this.child});

  final Widget child;

  /// Builds a sub-shell that lets one feature own the full content area.
  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Returns whether a value matches a query using ordered fuzzy characters.
bool _matchesFuzzyQuery(String value, String query) {
  final normalizedValue = value.toLowerCase();
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return true;
  }
  var cursor = 0;
  for (final codeUnit in normalizedQuery.codeUnits) {
    cursor = normalizedValue.indexOf(String.fromCharCode(codeUnit), cursor);
    if (cursor == -1) {
      return false;
    }
    cursor++;
  }
  return true;
}

/// Formats a chat timestamp for dense chat utility rows.
String _chatTimestamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.expanded,
    required this.onSelected,
    required this.onToggleExpanded,
  });

  final String selected;
  final bool expanded;
  final ValueChanged<String> onSelected;
  final VoidCallback onToggleExpanded;

  static const List<({String label, IconData icon})> _items =
      <({String label, IconData icon})>[
        (label: 'Today', icon: Icons.auto_awesome),
        (label: 'Chat', icon: Icons.forum_outlined),
        (label: 'Workflows', icon: Icons.radio_button_unchecked),
        (label: 'Tasks', icon: Icons.task_alt_outlined),
        (label: 'Memory', icon: Icons.chat_bubble_outline),
        (label: 'Files', icon: Icons.folder_outlined),
        (label: 'Calendar', icon: Icons.calendar_today_outlined),
        (label: 'People', icon: Icons.people_outline),
        (label: 'Settings', icon: Icons.settings_outlined),
      ];

  /// Builds the left navigation rail.
  @override
  Widget build(BuildContext context) {
    final compact = !expanded;
    return Container(
      width: expanded ? 292 : 92,
      color: const Color(0xfff5f0e6),
      padding: EdgeInsets.fromLTRB(26, 26, expanded ? 24 : 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SidebarHeader(
            expanded: expanded,
            onToggleExpanded: onToggleExpanded,
          ),
          SizedBox(height: compact ? 24 : 32),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                for (final item in _items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _NavButton(
                      label: item.label,
                      icon: item.icon,
                      selected: selected == item.label,
                      onTap: () => onSelected(item.label),
                      compact: compact,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _FocusCard(compact: compact),
          if (expanded) ...const <Widget>[SizedBox(height: 14), _ProfileTile()],
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.expanded,
    required this.onToggleExpanded,
  });

  final bool expanded;
  final VoidCallback onToggleExpanded;

  /// Builds the top sidebar logo row and expansion control.
  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Align(
        alignment: Alignment.topCenter,
        child: _SidebarToggle(expanded: expanded, onPressed: onToggleExpanded),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Expanded(child: _AuroraLogo(compact: false)),
        _SidebarToggle(expanded: expanded, onPressed: onToggleExpanded),
      ],
    );
  }
}

class _SidebarToggle extends StatelessWidget {
  const _SidebarToggle({required this.expanded, required this.onPressed});

  final bool expanded;
  final VoidCallback onPressed;

  /// Builds the sidebar expand or collapse button.
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: expanded ? 'Collapse sidebar' : 'Expand sidebar',
      child: IconButton(
        alignment: Alignment.topCenter,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        onPressed: onPressed,
        icon: Icon(
          expanded ? Icons.keyboard_double_arrow_left : Icons.menu,
          color: AuroraColors.muted,
          size: 20,
        ),
      ),
    );
  }
}

class _AuroraLogo extends StatelessWidget {
  const _AuroraLogo({required this.compact});

  final bool compact;

  /// Builds the Aurora mark and wordmark.
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: compact ? 'Aurora Personal Agent' : '',
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: <Widget>[
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xfffffbf1),
              border: Border.all(color: const Color(0xffb8a879)),
            ),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xff8c7a45),
                        width: 2,
                      ),
                    ),
                  ),
                  const Positioned(
                    right: -3,
                    top: 5,
                    child: _LogoDot(color: AuroraColors.coral),
                  ),
                  const Positioned(
                    left: -2,
                    bottom: 0,
                    child: _LogoDot(color: AuroraColors.green),
                  ),
                ],
              ),
            ),
          ),
          if (!compact) ...const <Widget>[
            SizedBox(width: 14),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'AURORA',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 5,
                    ),
                  ),
                  Text(
                    'PERSONAL AGENT',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: AuroraColors.muted,
                      letterSpacing: 2.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LogoDot extends StatelessWidget {
  const _LogoDot({required this.color});

  final Color color;

  /// Builds a small brand dot.
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(dimension: 10),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  /// Builds one navigation item.
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: compact ? label : '',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 20,
            vertical: compact ? 13 : 15,
          ),
          decoration: BoxDecoration(
            color: selected ? AuroraColors.greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: selected ? AuroraColors.green : AuroraColors.muted,
              ),
              if (!compact) ...<Widget>[
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AuroraColors.ink
                          : const Color(0xff514b43),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.compact});

  final bool compact;

  /// Builds the focus status card.
  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: 'Focus: Deep work until 12:00 PM',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AuroraColors.panel,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.eco_outlined, color: AuroraColors.green),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AuroraColors.panel,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.eco_outlined, color: AuroraColors.green),
          const SizedBox(height: 18),
          const Text(
            'Focus',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 4),
          const Text(
            'Deep work until 12:00 PM',
            style: TextStyle(color: AuroraColors.muted),
          ),
          const SizedBox(height: 18),
          const LinearProgressIndicator(
            value: 0.66,
            color: AuroraColors.green,
            backgroundColor: Color(0xffe6e1d8),
            minHeight: 7,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile();

  /// Builds the user account tile.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff0eadf),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: <Widget>[
          CircleAvatar(backgroundColor: Color(0xffd69b88)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Doug', style: TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  'Local pilot',
                  style: TextStyle(color: AuroraColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AuroraColors.muted),
        ],
      ),
    );
  }
}

class _CommandBar extends StatelessWidget {
  const _CommandBar({
    required this.controller,
    required this.onSubmit,
    required this.onNewChat,
    required this.onOpenSettings,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onNewChat;
  final VoidCallback onOpenSettings;

  /// Builds the global command bar.
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
      decoration: const BoxDecoration(
        color: AuroraColors.surface,
        border: Border(bottom: BorderSide(color: AuroraColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xfffffcf8),
                border: Border.all(color: AuroraColors.border),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x11453421),
                    blurRadius: 30,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.search, color: AuroraColors.muted),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Ask anything or give Aurora a command...',
                      ),
                      onSubmitted: (_) => onSubmit(),
                    ),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AuroraColors.coral,
                      foregroundColor: Colors.white,
                      fixedSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: onSubmit,
                    icon: const Icon(Icons.arrow_upward),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          _IconFrame(icon: Icons.add, tooltip: 'New chat', onTap: onNewChat),
          const SizedBox(width: 12),
          _IconFrame(
            icon: Icons.tune,
            tooltip: 'Settings',
            onTap: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class _IconFrame extends StatelessWidget {
  const _IconFrame({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Builds a framed icon button.
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 58,
          width: 58,
          decoration: BoxDecoration(
            border: Border.all(color: AuroraColors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: AuroraColors.muted),
        ),
      ),
    );
  }
}

class _HomeWorkspace extends StatelessWidget {
  const _HomeWorkspace({required this.controller});

  final AuroraAppController controller;

  /// Builds the Today assistant workspace.
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(36, 36, 36, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Eyebrow('TODAY', color: AuroraColors.coral),
          const SizedBox(height: 22),
          Text(
            'Live Workspace',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 10),
          Text(
            controller.statusMessage,
            style: const TextStyle(color: AuroraColors.muted, fontSize: 17),
          ),
          const SizedBox(height: 38),
          LayoutBuilder(
            builder: (context, constraints) {
              final hasTasks = controller.executionSteps.isNotEmpty;
              final chatColumn = controller.messages.isEmpty
                  ? const _MemoryEmptyBlock(label: 'No live chat messages')
                  : Column(
                      children: <Widget>[
                        for (final message in controller.messages)
                          _ChatRow(message: message),
                      ],
                    );
              if (!hasTasks) {
                return chatColumn;
              }
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ExecutionPlan(tasks: controller.executionSteps),
                    const SizedBox(height: 32),
                    chatColumn,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 300,
                    child: _ExecutionPlan(tasks: controller.executionSteps),
                  ),
                  const SizedBox(width: 36),
                  Expanded(child: chatColumn),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {this.color = AuroraColors.green});

  final String text;
  final Color color;

  /// Builds a small uppercase label.
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
      ),
    );
  }
}

class _ExecutionPlan extends StatelessWidget {
  const _ExecutionPlan({required this.tasks});

  final List<WorkspaceTask> tasks;

  /// Builds the active objective task plan.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Icon(Icons.circle, size: 10, color: AuroraColors.green),
            SizedBox(width: 12),
            _Eyebrow('EXECUTION PLAN'),
          ],
        ),
        const SizedBox(height: 24),
        for (final task in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _TaskLine(task: task),
          ),
      ],
    );
  }
}

class _TaskLine extends StatelessWidget {
  const _TaskLine({required this.task, this.onComplete});

  final WorkspaceTask task;
  final VoidCallback? onComplete;

  /// Builds one plan or task row.
  @override
  Widget build(BuildContext context) {
    final mark = task.done
        ? const Icon(Icons.check, size: 16, color: AuroraColors.green)
        : task.active
        ? const Icon(Icons.circle, size: 13, color: AuroraColors.green)
        : const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onComplete,
          child: Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.done ? const Color(0xffeef5e9) : Colors.transparent,
              border: Border.all(
                color: task.done || task.active
                    ? AuroraColors.green
                    : AuroraColors.border,
              ),
            ),
            child: Center(child: mark),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                task.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                task.detail,
                style: const TextStyle(color: AuroraColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.message});

  final ChatMessage message;

  /// Builds one chat timeline row.
  @override
  Widget build(BuildContext context) {
    if (message.role == ChatRole.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          constraints: const BoxConstraints(maxWidth: 640),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AuroraColors.panel,
            borderRadius: BorderRadius.circular(36),
          ),
          child: _MessageText(message: message),
        ),
      );
    }
    if (message.role == ChatRole.tool) {
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xfffffcf8),
          border: Border.all(color: AuroraColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.extension_outlined, color: AuroraColors.green),
            const SizedBox(width: 12),
            Expanded(child: _MessageText(message: message)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CircleAvatar(
            radius: 25,
            backgroundColor: AuroraColors.green,
            child: Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(child: _MessageText(message: message)),
        ],
      ),
    );
  }
}

class _MessageText extends StatelessWidget {
  const _MessageText({required this.message});

  final ChatMessage message;

  /// Builds message author and text.
  @override
  Widget build(BuildContext context) {
    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: message.author,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AuroraColors.ink,
                ),
              ),
              TextSpan(
                text: '  $time',
                style: const TextStyle(color: AuroraColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          message.text,
          style: const TextStyle(fontSize: 16, height: 1.55),
        ),
      ],
    );
  }
}

class _ChatCommandPanel extends StatelessWidget {
  const _ChatCommandPanel({required this.controller});

  final AuroraAppController controller;

  /// Builds the dedicated chat command panel with conversation and chat areas.
  @override
  Widget build(BuildContext context) {
    return SwitcherPanel(
      areas: <SwitcherPanelArea>[
        SwitcherPanelArea(
          title: 'Conversation',
          icon: Icons.forum_outlined,
          builder: _buildConversationContent,
        ),
        SwitcherPanelArea(
          title: 'Chats',
          icon: Icons.history,
          builder: _buildChatListContent,
        ),
      ],
    );
  }

  Widget _buildConversationContent(String query) {
    final messages = controller.messages.where((message) {
      return _matchesFuzzyQuery('${message.author} ${message.text}', query);
    }).toList();
    return ChatPanel(
      empty: PanelEmptyState(query: query),
      children: <Widget>[
        for (final message in messages) _ChatRow(message: message),
        if (controller.sending)
          const _ChatRuntimeNotice(
            icon: Icons.sync,
            label: 'Aurora is responding',
          ),
      ],
    );
  }

  Widget _buildChatListContent(String query) {
    final sessions = controller.sessions.where((session) {
      return _matchesFuzzyQuery('${session.title} ${session.id}', query);
    }).toList();
    if (sessions.isEmpty) {
      return PanelEmptyState(query: query);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      children: <Widget>[
        for (final session in sessions)
          _ChatSessionTile(
            session: session,
            selected: session.id == controller.selectedSessionId,
            onTap: () => unawaited(controller.selectSession(session.id)),
          ),
      ],
    );
  }
}

class _ChatUtilitiesPanel extends StatelessWidget {
  const _ChatUtilitiesPanel({required this.controller});

  final AuroraAppController controller;

  /// Builds live chat utilities for context, chats, and runtime state.
  @override
  Widget build(BuildContext context) {
    return SwitcherPanel(
      areas: <SwitcherPanelArea>[
        SwitcherPanelArea(
          title: 'Context',
          icon: Icons.account_tree_outlined,
          builder: _buildContextContent,
        ),
        SwitcherPanelArea(
          title: 'Chats',
          icon: Icons.history,
          builder: _buildChatListContent,
        ),
        SwitcherPanelArea(
          title: 'Runtime',
          icon: Icons.bolt_outlined,
          builder: _buildRuntimeContent,
        ),
      ],
    );
  }

  Widget _buildContextContent(String query) {
    final memories = controller.workspace.memoryRecords.where((record) {
      return _matchesFuzzyQuery(
        '${record.title} ${record.summary} ${record.topics.join(' ')}',
        query,
      );
    }).toList();
    final tasks = controller.workspace.tasks.where((task) {
      return _matchesFuzzyQuery('${task.title} ${task.detail}', query);
    }).toList();
    if (memories.isEmpty && tasks.isEmpty) {
      return PanelEmptyState(query: query);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: <Widget>[
        if (controller.selectedSessionId != null)
          _MemorySectionBlock(
            child: _MemoryMetadataRow(
              label: 'Chat',
              value: controller.selectedSessionId!,
            ),
          ),
        if (memories.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          const _MemoryPanelLabel('Memory in scope'),
          const SizedBox(height: 10),
          for (final record in memories.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChatMemoryContextTile(record: record),
            ),
        ],
        if (tasks.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          const _MemoryPanelLabel('Associated tasks'),
          const SizedBox(height: 10),
          for (final task in tasks.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChatTaskContextTile(task: task),
            ),
        ],
      ],
    );
  }

  Widget _buildChatListContent(String query) {
    final sessions = controller.sessions.where((session) {
      return _matchesFuzzyQuery('${session.title} ${session.id}', query);
    }).toList();
    if (sessions.isEmpty) {
      return PanelEmptyState(query: query);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: <Widget>[
        for (final session in sessions)
          _ChatSessionTile(
            session: session,
            selected: session.id == controller.selectedSessionId,
            onTap: () => unawaited(controller.selectSession(session.id)),
          ),
      ],
    );
  }

  Widget _buildRuntimeContent(String query) {
    final endpointStatuses = controller.endpointStatuses.where((status) {
      return _matchesFuzzyQuery(
        '${status.name} ${status.url} ${status.message}',
        query,
      );
    }).toList();
    final localStatuses = controller.localProcessStatuses.where((status) {
      return _matchesFuzzyQuery(
        '${status.name} ${status.url} ${status.message}',
        query,
      );
    }).toList();
    if (endpointStatuses.isEmpty &&
        localStatuses.isEmpty &&
        controller.pendingConfirmation == null) {
      return PanelEmptyState(query: query);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: <Widget>[
        if (controller.pendingConfirmation != null)
          _ChatConfirmationUtility(
            confirmation: controller.pendingConfirmation!,
            onAnswer: (option) =>
                unawaited(controller.answerConfirmation(option)),
          ),
        if (localStatuses.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          const _MemoryPanelLabel('Local processes'),
          const SizedBox(height: 10),
          for (final status in localStatuses)
            _ChatStatusTile(
              name: status.name,
              detail: status.url,
              state: status.state,
              message: status.message,
            ),
        ],
        if (endpointStatuses.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          const _MemoryPanelLabel('Service endpoints'),
          const SizedBox(height: 10),
          for (final status in endpointStatuses)
            _ChatStatusTile(
              name: status.name,
              detail: status.url,
              state: status.state,
              message: status.message,
            ),
        ],
      ],
    );
  }
}

class _ChatRuntimeNotice extends StatelessWidget {
  const _ChatRuntimeNotice({required this.icon, required this.label});

  final IconData icon;
  final String label;

  /// Builds a compact live runtime notice in the chat stream.
  @override
  Widget build(BuildContext context) {
    return _MemorySectionBlock(
      child: Row(
        children: <Widget>[
          Icon(icon, color: AuroraColors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatSessionTile extends StatelessWidget {
  const _ChatSessionTile({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  final ChatSession session;
  final bool selected;
  final VoidCallback onTap;

  /// Builds one selectable real chat row.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: _MemorySectionBlock(
          child: Row(
            children: <Widget>[
              Icon(
                selected ? Icons.check_circle : Icons.chat_bubble_outline,
                color: selected ? AuroraColors.green : AuroraColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      session.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _chatTimestamp(session.updatedAt),
                      style: const TextStyle(color: AuroraColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMemoryContextTile extends StatelessWidget {
  const _ChatMemoryContextTile({required this.record});

  final MemoryRecord record;

  /// Builds one memory context tile for chat utilities.
  @override
  Widget build(BuildContext context) {
    return _MemorySectionBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            record.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          if (record.summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              record.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AuroraColors.muted),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _MemoryBadge(label: record.kind),
              _MemoryBadge(label: record.sensitivity),
              if (record.sourceLabel.isNotEmpty)
                _MemoryBadge(label: record.sourceLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatTaskContextTile extends StatelessWidget {
  const _ChatTaskContextTile({required this.task});

  final WorkspaceTask task;

  /// Builds one associated task tile for the chat context panel.
  @override
  Widget build(BuildContext context) {
    return _MemorySectionBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TaskLine(task: task),
          if (task.sourceLabel.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _MemoryBadge(label: task.sourceLabel),
          ],
        ],
      ),
    );
  }
}

class _ChatStatusTile extends StatelessWidget {
  const _ChatStatusTile({
    required this.name,
    required this.detail,
    required this.state,
    required this.message,
  });

  final String name;
  final String detail;
  final ConnectionStateKind state;
  final String message;

  /// Builds one runtime status tile for chat utilities.
  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      ConnectionStateKind.connected => AuroraColors.green,
      ConnectionStateKind.disconnected => AuroraColors.coral,
      ConnectionStateKind.unknown => AuroraColors.muted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _MemorySectionBlock(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.circle, size: 12, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AuroraColors.muted),
                  ),
                  if (message.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(message, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatConfirmationUtility extends StatelessWidget {
  const _ChatConfirmationUtility({
    required this.confirmation,
    required this.onAnswer,
  });

  final ConfirmationRequest confirmation;
  final ValueChanged<ConfirmationOption> onAnswer;

  /// Builds the pending approval utility for chat tool calls.
  @override
  Widget build(BuildContext context) {
    return _MemorySectionBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _MemoryPanelLabel('Pending approval'),
          const SizedBox(height: 8),
          Text(confirmation.hint),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final option in confirmation.options)
                OutlinedButton(
                  onPressed: () => onAnswer(option),
                  child: Text(option.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkflowCommandPanel extends StatelessWidget {
  const _WorkflowCommandPanel({
    required this.controller,
    required this.onBackHome,
  });

  final AuroraAppController controller;
  final VoidCallback onBackHome;

  /// Builds the workflow command panel with switchable dense content areas.
  @override
  Widget build(BuildContext context) {
    return SwitcherPanel(
      areas: <SwitcherPanelArea>[
        SwitcherPanelArea(
          title: controller.workspace.title,
          icon: Icons.auto_awesome,
          builder: (query) => _buildOverviewContent(context, query),
        ),
        SwitcherPanelArea(
          title: 'Research Plan',
          icon: Icons.checklist,
          builder: _buildPlanContent,
        ),
      ],
    );
  }

  Widget _buildOverviewContent(BuildContext context, String query) {
    final filteredMessages = controller.messages.where((message) {
      return _matchesFuzzyQuery('${message.author} ${message.text}', query);
    }).toList();
    final hasResults = filteredMessages.isNotEmpty;
    if (!hasResults) {
      return PanelEmptyState(query: query);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: TextButton.icon(
                  onPressed: onBackHome,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text(
                    'Back to Home',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            controller.workspace.title,
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 10),
          Text(
            controller.workspace.subtitle,
            style: const TextStyle(color: AuroraColors.muted, fontSize: 17),
          ),
          for (final message in filteredMessages) _ChatRow(message: message),
        ],
      ),
    );
  }

  Widget _buildPlanContent(String query) {
    final filteredTasks = controller.workspace.tasks.where((task) {
      return _matchesFuzzyQuery('${task.title} ${task.detail}', query);
    }).toList();
    if (filteredTasks.isEmpty) {
      return PanelEmptyState(query: query);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      child: _ResearchPlanCard(controller: controller, tasks: filteredTasks),
    );
  }
}

class _ResearchPlanCard extends StatelessWidget {
  const _ResearchPlanCard({required this.controller, this.tasks});

  final AuroraAppController controller;
  final List<WorkspaceTask>? tasks;

  /// Builds the workspace task card with confirmable actions.
  @override
  Widget build(BuildContext context) {
    final visibleTasks = tasks ?? controller.workspace.tasks;
    final done = visibleTasks.where((task) => task.done).length;
    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xfffffcf8),
        border: Border.all(color: AuroraColors.border),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Research Plan',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
              Flexible(
                child: Text(
                  'In progress - $done/${visibleTasks.length}',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: AuroraColors.muted),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(
                tooltip: 'Add task',
                onPressed: () => _confirmCreateTask(context, controller),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final task in visibleTasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _TaskLine(
                task: task,
                onComplete: task.done
                    ? null
                    : () => _confirmCompleteTask(context, controller, task),
              ),
            ),
        ],
      ),
    );
  }
}

const List<String> _memoryKinds = <String>[
  'conversation',
  'document',
  'tool_output',
  'artifact',
  'summary',
  'entity_page',
  'timeline',
  'profile_fact',
];

const List<String> _memoryScopes = <String>[
  'session',
  'user',
  'household',
  'tenant',
  'project',
  'global',
];

const List<String> _memoryTrustLevels = <String>[
  'source_original',
  'user_asserted',
  'model_extracted',
  'model_synthesized',
  'externally_verified',
];

const List<String> _memorySensitivities = <String>[
  'public',
  'internal',
  'private',
  'restricted',
];

const List<String> _memoryStatuses = <String>[
  'active',
  'superseded',
  'deprecated',
  'archived',
];

class _MemoryLibraryPanel extends StatelessWidget {
  const _MemoryLibraryPanel({required this.controller});

  final AuroraAppController controller;

  /// Builds the memory discovery command panel.
  @override
  Widget build(BuildContext context) {
    return SwitcherPanel(
      areas: <SwitcherPanelArea>[
        SwitcherPanelArea(
          title: 'Search',
          icon: Icons.manage_search,
          builder: (query) =>
              _MemorySearchContent(controller: controller, query: query),
        ),
        SwitcherPanelArea(
          title: 'Browse',
          icon: Icons.filter_alt_outlined,
          builder: (query) =>
              _MemoryBrowseContent(controller: controller, query: query),
        ),
        SwitcherPanelArea(
          title: 'Review',
          icon: Icons.rule_folder_outlined,
          builder: (query) =>
              _MemoryReviewContent(controller: controller, query: query),
        ),
        SwitcherPanelArea(
          title: 'Map',
          icon: Icons.account_tree_outlined,
          builder: (query) =>
              _MemoryMapContent(controller: controller, query: query),
        ),
        SwitcherPanelArea(
          title: 'Capture',
          icon: Icons.add_box_outlined,
          builder: (query) =>
              _MemoryCaptureContent(controller: controller, query: query),
        ),
      ],
    );
  }
}

class _MemorySearchContent extends StatelessWidget {
  const _MemorySearchContent({required this.controller, required this.query});

  final AuroraAppController controller;
  final String query;

  /// Builds catalog search results and retrieval filters.
  @override
  Widget build(BuildContext context) {
    final records = controller.filteredMemoryRecords.where((record) {
      return _matchesMemoryRecord(record, query);
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MemoryFilterBar(controller: controller, query: query),
          const SizedBox(height: 14),
          _MemoryStatusStrip(controller: controller),
          const SizedBox(height: 14),
          if (records.isEmpty)
            _MemoryEmptyBlock(label: 'No catalog records')
          else
            for (final record in records)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MemoryRecordTile(
                  record: record,
                  selected: controller.selectedMemory?.id == record.id,
                  onTap: () => unawaited(controller.selectMemory(record.id)),
                ),
              ),
        ],
      ),
    );
  }
}

class _MemoryFilterBar extends StatelessWidget {
  const _MemoryFilterBar({required this.controller, required this.query});

  final AuroraAppController controller;
  final String query;

  /// Builds scope, sensitivity, and service-search controls.
  @override
  Widget build(BuildContext context) {
    final filters = controller.memoryFilters;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AuroraColors.surface,
        border: Border.all(color: AuroraColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _MemoryDropdown(
                  value: filters.scope,
                  values: _memoryScopes,
                  tooltip: 'Scope',
                  onChanged: (value) {
                    unawaited(
                      controller.applyMemoryFilters(
                        filters.copyWith(scope: value),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Search service',
                child: IconButton.outlined(
                  onPressed: () {
                    unawaited(
                      controller.applyMemoryFilters(
                        filters.copyWith(text: query.trim()),
                      ),
                    );
                  },
                  icon: const Icon(Icons.travel_explore),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Refresh',
                child: IconButton.outlined(
                  onPressed: () =>
                      unawaited(controller.applyMemoryFilters(filters)),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final sensitivity in _memorySensitivities)
                FilterChip(
                  label: Text(_memoryLabel(sensitivity)),
                  selected: filters.allowedSensitivities.contains(sensitivity),
                  onSelected: (_) {
                    unawaited(
                      controller.applyMemoryFilters(
                        filters.copyWith(
                          allowedSensitivities: _toggleString(
                            filters.allowedSensitivities,
                            sensitivity,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          if (filters.text.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _MemoryActiveFilter(
              label: 'Search: ${filters.text}',
              onClear: () {
                unawaited(
                  controller.applyMemoryFilters(filters.copyWith(text: '')),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _MemoryStatusStrip extends StatelessWidget {
  const _MemoryStatusStrip({required this.controller});

  final AuroraAppController controller;

  /// Builds a compact memory operation status strip.
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (controller.memoryBusy)
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Icon(Icons.circle, size: 10, color: AuroraColors.green),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            controller.memoryMessage,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AuroraColors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _MemoryRecordTile extends StatelessWidget {
  const _MemoryRecordTile({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  final MemoryRecord record;
  final bool selected;
  final VoidCallback onTap;

  /// Builds one selectable memory catalog result.
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AuroraColors.greenSoft : AuroraColors.surface,
          border: Border.all(
            color: selected ? AuroraColors.green : AuroraColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    record.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _MemoryBadge(label: _memoryLabel(record.kind)),
              ],
            ),
            if (record.summary.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                record.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AuroraColors.muted),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                _MemoryBadge(label: record.scope),
                _MemoryBadge(label: record.sensitivity),
                _MemoryBadge(label: _memoryLabel(record.trustLevel)),
                if (record.status != 'active')
                  _MemoryBadge(label: record.status),
                for (final topic in record.topics.take(3))
                  _MemoryBadge(label: topic),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              record.sourceLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AuroraColors.green),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryBrowseContent extends StatelessWidget {
  const _MemoryBrowseContent({required this.controller, required this.query});

  final AuroraAppController controller;
  final String query;

  /// Builds facet-based discovery paths into memory.
  @override
  Widget build(BuildContext context) {
    final records = controller.filteredMemoryRecords;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MemoryFacetGroup(
            title: 'Kinds',
            values: _counts(records.map((record) => record.kind)),
            query: query,
            onSelected: (value) =>
                _applySingleFacet(controller, kinds: <String>[value]),
          ),
          _MemoryFacetGroup(
            title: 'Topics',
            values: _counts(records.expand((record) => record.topics)),
            query: query,
            onSelected: (value) =>
                _applySingleFacet(controller, topics: <String>[value]),
          ),
          _MemoryFacetGroup(
            title: 'Entities',
            values: _counts(records.expand((record) => record.entityNames)),
            query: query,
            onSelected: (value) => _selectFirstEntity(controller, value),
          ),
          _MemoryFacetGroup(
            title: 'Sensitivity',
            values: _counts(records.map((record) => record.sensitivity)),
            query: query,
            onSelected: (value) => _applySingleFacet(
              controller,
              allowedSensitivities: <String>[value],
            ),
          ),
          _MemoryFacetGroup(
            title: 'Trust',
            values: _counts(records.map((record) => record.trustLevel)),
            query: query,
            onSelected: (value) {
              unawaited(
                controller.applyMemoryFilters(
                  controller.memoryFilters.copyWith(localTrustLevel: value),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MemoryReviewContent extends StatelessWidget {
  const _MemoryReviewContent({required this.controller, required this.query});

  final AuroraAppController controller;
  final String query;

  /// Builds the cross-cutting memory review queue.
  @override
  Widget build(BuildContext context) {
    final records = controller.filteredMemoryRecords.where((record) {
      return _memoryReviewReasons(record).isNotEmpty &&
          _matchesMemoryRecord(record, query);
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MemoryStatusStrip(controller: controller),
          const SizedBox(height: 14),
          if (records.isEmpty)
            const _MemoryEmptyBlock(label: 'No records need review')
          else
            for (final record in records)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MemorySectionBlock(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _MemoryRecordTile(
                        record: record,
                        selected: controller.selectedMemory?.id == record.id,
                        onTap: () =>
                            unawaited(controller.selectMemory(record.id)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final reason in _memoryReviewReasons(record))
                            _MemoryBadge(label: reason),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _MemoryFacetGroup extends StatelessWidget {
  const _MemoryFacetGroup({
    required this.title,
    required this.values,
    required this.query,
    required this.onSelected,
  });

  final String title;
  final Map<String, int> values;
  final String query;
  final ValueChanged<String> onSelected;

  /// Builds one group of browse facets.
  @override
  Widget build(BuildContext context) {
    final entries = values.entries.where((entry) {
      return _matchesFuzzyQuery('${entry.key} $title', query);
    }).toList();
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _MemoryPanelLabel(title),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final entry in entries)
                ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: AuroraColors.greenSoft,
                    child: Text(
                      '${entry.value}',
                      style: const TextStyle(
                        color: AuroraColors.green,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  label: Text(_memoryLabel(entry.key)),
                  onPressed: () => onSelected(entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoryMapContent extends StatelessWidget {
  const _MemoryMapContent({required this.controller, required this.query});

  final AuroraAppController controller;
  final String query;

  /// Builds relationship and discovery-path context for the selected memory.
  @override
  Widget build(BuildContext context) {
    final memory = controller.selectedMemory;
    if (memory == null) {
      return const _MemorySelectionEmpty();
    }
    final related = controller.workspace.memoryRecords
        .where((record) {
          return memory.relationships.any((rel) => rel.toId == record.id) ||
              record.relationships.any((rel) => rel.toId == memory.id);
        })
        .where((record) {
          return _matchesMemoryRecord(record, query);
        })
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MemorySectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MemoryPanelLabel('Selected Memory'),
                const SizedBox(height: 10),
                Text(
                  memory.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _MemoryBadge(label: memory.sourceLabel),
                    _MemoryBadge(label: memory.scope),
                    _MemoryBadge(label: _memoryLabel(memory.kind)),
                    for (final topic in memory.topics)
                      _MemoryBadge(label: topic),
                    for (final entity in memory.entityNames)
                      _MemoryBadge(label: entity),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MemorySectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MemoryPanelLabel('Relationships'),
                const SizedBox(height: 10),
                if (memory.relationships.isEmpty)
                  const Text(
                    'No relationship edges',
                    style: TextStyle(color: AuroraColors.muted),
                  )
                else
                  for (final relationship in memory.relationships)
                    _MemoryRelationshipLine(relationship: relationship),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MemorySectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MemoryPanelLabel('Related Records'),
                const SizedBox(height: 10),
                if (related.isEmpty)
                  const Text(
                    'No related records in the current result set',
                    style: TextStyle(color: AuroraColors.muted),
                  )
                else
                  for (final record in related)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MemoryRecordTile(
                        record: record,
                        selected: false,
                        onTap: () =>
                            unawaited(controller.selectMemory(record.id)),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryCaptureContent extends StatefulWidget {
  const _MemoryCaptureContent({required this.controller, required this.query});

  final AuroraAppController controller;
  final String query;

  @override
  State<_MemoryCaptureContent> createState() => _MemoryCaptureContentState();
}

class _MemoryCaptureContentState extends State<_MemoryCaptureContent> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  final TextEditingController _sourceSystem = TextEditingController(
    text: 'aurora-ui',
  );
  final TextEditingController _sourceId = TextEditingController();
  final TextEditingController _subjects = TextEditingController();
  final TextEditingController _topics = TextEditingController();
  final TextEditingController _entities = TextEditingController();
  String _kind = 'document';
  String _scope = 'user';
  String _trust = 'source_original';
  String _sensitivity = 'private';

  /// Initializes live duplicate hint refresh.
  @override
  void initState() {
    super.initState();
    _title.addListener(_refreshDuplicateHints);
    _content.addListener(_refreshDuplicateHints);
  }

  /// Cleans up capture form controllers.
  @override
  void dispose() {
    _title.removeListener(_refreshDuplicateHints);
    _content.removeListener(_refreshDuplicateHints);
    _title.dispose();
    _content.dispose();
    _sourceSystem.dispose();
    _sourceId.dispose();
    _subjects.dispose();
    _topics.dispose();
    _entities.dispose();
    super.dispose();
  }

  /// Builds the careful memory accession form.
  @override
  Widget build(BuildContext context) {
    final duplicates = widget.controller.filteredMemoryRecords
        .where((record) {
          final probe = '${_title.text} ${_content.text} ${widget.query}';
          return probe.trim().isNotEmpty && _matchesMemoryRecord(record, probe);
        })
        .take(4)
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MemorySectionBlock(
            child: Column(
              children: <Widget>[
                _MemoryTextField(controller: _title, label: 'Title'),
                const SizedBox(height: 10),
                _MemoryTextField(
                  controller: _content,
                  label: 'Source content',
                  maxLines: 8,
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MemoryTextField(
                        controller: _sourceSystem,
                        label: 'Source system',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MemoryTextField(
                        controller: _sourceId,
                        label: 'Source id',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MemoryDropdown(
                        value: _kind,
                        values: _memoryKinds,
                        tooltip: 'Kind',
                        onChanged: (value) => setState(() => _kind = value),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MemoryDropdown(
                        value: _scope,
                        values: _memoryScopes,
                        tooltip: 'Scope',
                        onChanged: (value) => setState(() => _scope = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MemoryDropdown(
                        value: _trust,
                        values: _memoryTrustLevels,
                        tooltip: 'Trust',
                        onChanged: (value) => setState(() => _trust = value),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MemoryDropdown(
                        value: _sensitivity,
                        values: _memorySensitivities,
                        tooltip: 'Sensitivity',
                        onChanged: (value) =>
                            setState(() => _sensitivity = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MemoryTextField(controller: _subjects, label: 'Subjects'),
                const SizedBox(height: 10),
                _MemoryTextField(controller: _topics, label: 'Topics'),
                const SizedBox(height: 10),
                _MemoryTextField(controller: _entities, label: 'Entities'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MemorySectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MemoryPanelLabel('Nearby Records'),
                const SizedBox(height: 10),
                if (duplicates.isEmpty)
                  const Text(
                    'No nearby records',
                    style: TextStyle(color: AuroraColors.muted),
                  )
                else
                  for (final record in duplicates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MemoryRecordTile(
                        record: record,
                        selected: false,
                        onTap: () => unawaited(
                          widget.controller.selectMemory(record.id),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: widget.controller.memoryBusy ? null : _save,
            icon: const Icon(Icons.library_add_check_outlined),
            label: const Text('Save Reviewed Memory'),
          ),
        ],
      ),
    );
  }

  /// Confirms and saves the drafted source-backed memory.
  Future<void> _save() async {
    final draft = MemoryCaptureDraft(
      content: _content.text.trim(),
      title: _title.text.trim(),
      kind: _kind,
      scope: _scope,
      trustLevel: _trust,
      sensitivity: _sensitivity,
      sourceSystem: _sourceSystem.text.trim(),
      sourceId: _sourceId.text.trim(),
      subjects: _splitList(_subjects.text),
      topics: _splitList(_topics.text),
      entityNames: _splitList(_entities.text),
    );
    if (draft.content.isEmpty) {
      return;
    }
    final approved = await _confirmWrite(
      context,
      'Save "${draft.title.isEmpty ? 'Untitled memory' : draft.title}"?',
    );
    if (!approved || !mounted) {
      return;
    }
    await widget.controller.saveMemoryCandidateFromUi(draft);
    if (!mounted) {
      return;
    }
    _content.clear();
    _title.clear();
    _sourceId.clear();
  }

  /// Refreshes nearby-record hints while accession fields change.
  void _refreshDuplicateHints() {
    if (mounted) {
      setState(() {});
    }
  }
}

class _MemoryStewardshipPanel extends StatelessWidget {
  const _MemoryStewardshipPanel({required this.controller});

  final AuroraAppController controller;

  /// Builds the selected-memory stewardship command panel.
  @override
  Widget build(BuildContext context) {
    return SwitcherPanel(
      areas: <SwitcherPanelArea>[
        SwitcherPanelArea(
          title: 'Overview',
          icon: Icons.info_outline,
          builder: (query) =>
              _MemoryOverviewContent(controller: controller, query: query),
        ),
        SwitcherPanelArea(
          title: 'Source',
          icon: Icons.article_outlined,
          builder: (query) =>
              _MemorySourceContent(controller: controller, query: query),
        ),
        SwitcherPanelArea(
          title: 'Relations',
          icon: Icons.hub_outlined,
          builder: (query) =>
              _MemoryRelationsContent(controller: controller, query: query),
        ),
        SwitcherPanelArea(
          title: 'Cataloging',
          icon: Icons.edit_note,
          builder: (query) =>
              _MemoryCatalogingContent(controller: controller, query: query),
        ),
        SwitcherPanelArea(
          title: 'Corrections',
          icon: Icons.fact_check_outlined,
          builder: (query) =>
              _MemoryCorrectionsContent(controller: controller, query: query),
        ),
        SwitcherPanelArea(
          title: 'Pages',
          icon: Icons.view_timeline_outlined,
          builder: (query) =>
              _MemoryPagesContent(controller: controller, query: query),
        ),
      ],
    );
  }
}

class _MemoryOverviewContent extends StatelessWidget {
  const _MemoryOverviewContent({required this.controller, required this.query});

  final AuroraAppController controller;
  final String query;

  /// Builds selected memory metadata and stewardship posture.
  @override
  Widget build(BuildContext context) {
    final memory = controller.selectedMemory;
    if (memory == null) {
      return const _MemorySelectionEmpty();
    }
    if (!_matchesMemoryRecord(memory, query)) {
      return PanelEmptyState(query: query);
    }
    final contradictionCount = memory.relationships
        .where((relationship) => relationship.type == 'contradicts')
        .length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MemorySectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        memory.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    if (contradictionCount > 0)
                      _MemoryBadge(label: '$contradictionCount conflicts'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  memory.summary,
                  style: const TextStyle(color: AuroraColors.muted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _MemoryBadge(label: _memoryLabel(memory.kind)),
                    _MemoryBadge(label: memory.scope),
                    _MemoryBadge(label: memory.sensitivity),
                    _MemoryBadge(label: _memoryLabel(memory.trustLevel)),
                    _MemoryBadge(label: memory.status),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MemorySectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MemoryPanelLabel('Catalog'),
                const SizedBox(height: 10),
                _MemoryMetadataRow(label: 'Catalog id', value: memory.id),
                _MemoryMetadataRow(
                  label: 'Evidence id',
                  value: memory.evidenceId,
                ),
                _MemoryMetadataRow(label: 'Source', value: memory.sourceLabel),
                _MemoryMetadataRow(
                  label: 'Created',
                  value: _formatDate(memory.createdAt),
                ),
                _MemoryMetadataRow(
                  label: 'Updated',
                  value: _formatDate(memory.updatedAt),
                ),
                _MemoryMetadataRow(
                  label: 'Event',
                  value: _formatDate(memory.eventTime),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MemorySectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MemoryPanelLabel('Access Paths'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final subject in memory.subjects)
                      _MemoryBadge(label: subject),
                    for (final topic in memory.topics)
                      _MemoryBadge(label: topic),
                    for (final entity in memory.entityNames)
                      _MemoryBadge(label: entity),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemorySourceContent extends StatelessWidget {
  const _MemorySourceContent({required this.controller, required this.query});

  final AuroraAppController controller;
  final String query;

  /// Builds immutable raw evidence preview for the selected memory.
  @override
  Widget build(BuildContext context) {
    final memory = controller.selectedMemory;
    if (memory == null) {
      return const _MemorySelectionEmpty();
    }
    if (!_matchesFuzzyQuery(
      '${memory.rawContent} ${memory.rawPath} ${memory.rawChecksum}',
      query,
    )) {
      return PanelEmptyState(query: query);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MemorySectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MemoryPanelLabel('Evidence'),
                const SizedBox(height: 10),
                _MemoryMetadataRow(
                  label: 'Evidence id',
                  value: memory.evidenceId,
                ),
                _MemoryMetadataRow(label: 'Path', value: memory.rawPath),
                _MemoryMetadataRow(
                  label: 'Checksum',
                  value: memory.rawChecksum,
                ),
                _MemoryMetadataRow(
                  label: 'Media type',
                  value: memory.rawMediaType,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: controller.memoryBusy
                      ? null
                      : () =>
                            unawaited(controller.hydrateSelectedMemorySource()),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Load Source'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            constraints: const BoxConstraints(minHeight: 260),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xfffffcf8),
              border: Border.all(color: AuroraColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              memory.rawContent.isEmpty
                  ? 'Source not loaded'
                  : memory.rawContent,
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryRelationsContent extends StatelessWidget {
  const _MemoryRelationsContent({
    required this.controller,
    required this.query,
  });

  final AuroraAppController controller;
  final String query;

  /// Builds relationship review for the selected memory.
  @override
  Widget build(BuildContext context) {
    final memory = controller.selectedMemory;
    if (memory == null) {
      return const _MemorySelectionEmpty();
    }
    final relationships = memory.relationships.where((relationship) {
      return _matchesFuzzyQuery(
        '${relationship.type} ${relationship.toId} ${relationship.sourceId}',
        query,
      );
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MemorySectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MemoryPanelLabel('Outgoing Edges'),
                const SizedBox(height: 10),
                if (relationships.isEmpty)
                  const Text(
                    'No matching relationship edges',
                    style: TextStyle(color: AuroraColors.muted),
                  )
                else
                  for (final relationship in relationships)
                    _MemoryRelationshipLine(relationship: relationship),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MemorySectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MemoryPanelLabel('Incoming Edges'),
                const SizedBox(height: 10),
                for (final record in controller.workspace.memoryRecords)
                  for (final relationship in record.relationships.where(
                    (rel) => rel.toId == memory.id,
                  ))
                    _MemoryRelationshipLine(relationship: relationship),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryCatalogingContent extends StatefulWidget {
  const _MemoryCatalogingContent({
    required this.controller,
    required this.query,
  });

  final AuroraAppController controller;
  final String query;

  @override
  State<_MemoryCatalogingContent> createState() =>
      _MemoryCatalogingContentState();
}

class _MemoryCatalogingContentState extends State<_MemoryCatalogingContent> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _summary = TextEditingController();
  final TextEditingController _subjects = TextEditingController();
  final TextEditingController _topics = TextEditingController();
  final TextEditingController _entities = TextEditingController();
  String _recordId = '';
  String _kind = 'document';
  String _sensitivity = 'private';
  String _status = 'active';

  /// Initializes form state.
  @override
  void initState() {
    super.initState();
    _syncFromSelected();
  }

  /// Keeps form state aligned when the selected memory changes.
  @override
  void didUpdateWidget(covariant _MemoryCatalogingContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.selectedMemory?.id !=
        widget.controller.selectedMemory?.id) {
      _syncFromSelected();
    }
  }

  /// Cleans up cataloging form controllers.
  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _subjects.dispose();
    _topics.dispose();
    _entities.dispose();
    super.dispose();
  }

  /// Builds explicit metadata repair controls.
  @override
  Widget build(BuildContext context) {
    final memory = widget.controller.selectedMemory;
    if (memory == null) {
      return const _MemorySelectionEmpty();
    }
    if (!_matchesMemoryRecord(memory, widget.query)) {
      return PanelEmptyState(query: widget.query);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MemorySectionBlock(
            child: Column(
              children: <Widget>[
                _MemoryTextField(controller: _title, label: 'Title'),
                const SizedBox(height: 10),
                _MemoryTextField(
                  controller: _summary,
                  label: 'Summary',
                  maxLines: 4,
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MemoryDropdown(
                        value: _kind,
                        values: _memoryKinds,
                        tooltip: 'Kind',
                        onChanged: (value) => setState(() => _kind = value),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MemoryDropdown(
                        value: _sensitivity,
                        values: _memorySensitivities,
                        tooltip: 'Sensitivity',
                        onChanged: (value) =>
                            setState(() => _sensitivity = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MemoryDropdown(
                  value: _status,
                  values: _memoryStatuses,
                  tooltip: 'Status',
                  onChanged: (value) => setState(() => _status = value),
                ),
                const SizedBox(height: 10),
                _MemoryTextField(controller: _subjects, label: 'Subjects'),
                const SizedBox(height: 10),
                _MemoryTextField(controller: _topics, label: 'Topics'),
                const SizedBox(height: 10),
                _MemoryTextField(controller: _entities, label: 'Entities'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: widget.controller.memoryBusy ? null : _repair,
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Repair Catalog Metadata'),
          ),
        ],
      ),
    );
  }

  /// Copies selected catalog metadata into the repair form.
  void _syncFromSelected() {
    final memory = widget.controller.selectedMemory;
    if (memory == null || memory.id == _recordId) {
      return;
    }
    _recordId = memory.id;
    _title.text = memory.title;
    _summary.text = memory.summary;
    _subjects.text = memory.subjects.join(', ');
    _topics.text = memory.topics.join(', ');
    _entities.text = memory.entityNames.join(', ');
    _kind = _coerceDropdownValue(_memoryKinds, memory.kind, 'document');
    _sensitivity = _coerceDropdownValue(
      _memorySensitivities,
      memory.sensitivity,
      'private',
    );
    _status = _coerceDropdownValue(_memoryStatuses, memory.status, 'active');
  }

  /// Confirms and submits catalog metadata repairs.
  Future<void> _repair() async {
    final memory = widget.controller.selectedMemory;
    if (memory == null) {
      return;
    }
    final approved = await _confirmWrite(
      context,
      'Repair catalog metadata for "${memory.title}"?',
    );
    if (!approved || !mounted) {
      return;
    }
    await widget.controller.repairMemoryFromUi(
      MemoryRepairDraft(
        catalogId: memory.id,
        title: _title.text.trim(),
        summary: _summary.text.trim(),
        kind: _kind,
        sensitivity: _sensitivity,
        status: _status,
        subjects: _splitList(_subjects.text),
        topics: _splitList(_topics.text),
        entityNames: _splitList(_entities.text),
      ),
    );
  }
}

class _MemoryCorrectionsContent extends StatefulWidget {
  const _MemoryCorrectionsContent({
    required this.controller,
    required this.query,
  });

  final AuroraAppController controller;
  final String query;

  @override
  State<_MemoryCorrectionsContent> createState() =>
      _MemoryCorrectionsContentState();
}

class _MemoryCorrectionsContentState extends State<_MemoryCorrectionsContent> {
  final TextEditingController _correction = TextEditingController();

  /// Cleans up correction form state.
  @override
  void dispose() {
    _correction.dispose();
    super.dispose();
  }

  /// Builds correction capture controls.
  @override
  Widget build(BuildContext context) {
    final memory = widget.controller.selectedMemory;
    if (memory == null) {
      return const _MemorySelectionEmpty();
    }
    if (!_matchesMemoryRecord(memory, widget.query)) {
      return PanelEmptyState(query: widget.query);
    }
    final corrections = widget.controller.workspace.memoryRecords.where((
      record,
    ) {
      return record.sourceSystem == 'memory_correction' &&
          record.sourceId == memory.id;
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MemorySectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MemoryPanelLabel('New Correction'),
                const SizedBox(height: 10),
                _MemoryTextField(
                  controller: _correction,
                  label: 'Correction text',
                  maxLines: 6,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: widget.controller.memoryBusy ? null : _submit,
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Submit Correction'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MemorySectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MemoryPanelLabel('Existing Corrections'),
                const SizedBox(height: 10),
                if (corrections.isEmpty)
                  const Text(
                    'No corrections in current results',
                    style: TextStyle(color: AuroraColors.muted),
                  )
                else
                  for (final correction in corrections)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MemoryRecordTile(
                        record: correction,
                        selected: false,
                        onTap: () => unawaited(
                          widget.controller.selectMemory(correction.id),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Confirms and submits a source-backed correction.
  Future<void> _submit() async {
    final memory = widget.controller.selectedMemory;
    final text = _correction.text.trim();
    if (memory == null || text.isEmpty) {
      return;
    }
    final approved = await _confirmWrite(
      context,
      'Submit correction for "${memory.title}"?',
    );
    if (!approved || !mounted) {
      return;
    }
    await widget.controller.submitMemoryCorrectionFromUi(text);
    if (mounted) {
      _correction.clear();
    }
  }
}

class _MemoryPagesContent extends StatelessWidget {
  const _MemoryPagesContent({required this.controller, required this.query});

  final AuroraAppController controller;
  final String query;

  /// Builds entity page and timeline controls for the selected memory.
  @override
  Widget build(BuildContext context) {
    final memory = controller.selectedMemory;
    final page = controller.selectedMemoryPage;
    if (memory == null) {
      return const _MemorySelectionEmpty();
    }
    if (!_matchesMemoryRecord(memory, query) &&
        !_matchesFuzzyQuery(
          '${page?.title ?? ''} ${page?.content ?? ''}',
          query,
        )) {
      return PanelEmptyState(query: query);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MemorySectionBlock(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: controller.memoryBusy
                      ? null
                      : () =>
                            unawaited(controller.loadEntityPageFromUi(memory)),
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('Entity Page'),
                ),
                for (final topic in memory.topics.take(3))
                  OutlinedButton.icon(
                    onPressed: controller.memoryBusy
                        ? null
                        : () => unawaited(controller.loadTimelineFromUi(topic)),
                    icon: const Icon(Icons.timeline_outlined),
                    label: Text(topic),
                  ),
                if (page != null)
                  OutlinedButton.icon(
                    onPressed: controller.memoryBusy
                        ? null
                        : () => unawaited(
                            controller.refreshSelectedMemoryPageFromUi(),
                          ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Page'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (page == null)
            const _MemoryEmptyBlock(label: 'No compiled page loaded')
          else
            _MemorySectionBlock(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    page.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MemoryBadge(label: page.kind),
                      _MemoryBadge(label: page.scope),
                      _MemoryBadge(label: '${page.sourceIds.length} sources'),
                      if (page.stale) const _MemoryBadge(label: 'stale'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SelectableText(page.content),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MemorySectionBlock extends StatelessWidget {
  const _MemorySectionBlock({required this.child});

  final Widget child;

  /// Builds a compact bordered memory work surface.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffffcf8),
        border: Border.all(color: AuroraColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _MemoryPanelLabel extends StatelessWidget {
  const _MemoryPanelLabel(this.label);

  final String label;

  /// Builds an uppercase memory panel label.
  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AuroraColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.4,
      ),
    );
  }
}

class _MemoryBadge extends StatelessWidget {
  const _MemoryBadge({required this.label});

  final String label;

  /// Builds a dense metadata badge.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AuroraColors.panel,
        border: Border.all(color: AuroraColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _memoryLabel(label),
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AuroraColors.green,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MemoryActiveFilter extends StatelessWidget {
  const _MemoryActiveFilter({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  /// Builds a removable active filter chip.
  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      onDeleted: onClear,
      deleteIcon: const Icon(Icons.close, size: 16),
    );
  }
}

class _MemoryDropdown extends StatelessWidget {
  const _MemoryDropdown({
    required this.value,
    required this.values,
    required this.tooltip,
    required this.onChanged,
  });

  final String value;
  final List<String> values;
  final String tooltip;
  final ValueChanged<String> onChanged;

  /// Builds a compact dropdown for controlled memory vocabulary.
  @override
  Widget build(BuildContext context) {
    final dropdownValue = _coerceDropdownValue(values, value, values.first);
    return Tooltip(
      message: tooltip,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AuroraColors.surface,
          border: Border.all(color: AuroraColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: dropdownValue,
            isDense: true,
            isExpanded: true,
            icon: const Icon(Icons.expand_more, size: 18),
            items: <DropdownMenuItem<String>>[
              for (final item in values)
                DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    _memoryLabel(item),
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

class _MemoryTextField extends StatelessWidget {
  const _MemoryTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;

  /// Builds a compact text field for memory forms.
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: maxLines == 1 ? 1 : 3,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AuroraColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AuroraColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AuroraColors.border),
        ),
      ),
    );
  }
}

class _MemoryMetadataRow extends StatelessWidget {
  const _MemoryMetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  /// Builds one key/value metadata row.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AuroraColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryRelationshipLine extends StatelessWidget {
  const _MemoryRelationshipLine({required this.relationship});

  final MemoryRelationship relationship;

  /// Builds one relationship review row.
  @override
  Widget build(BuildContext context) {
    final isConflict = relationship.type == 'contradicts';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConflict ? const Color(0xffffefed) : AuroraColors.surface,
        border: Border.all(
          color: isConflict ? AuroraColors.coral : AuroraColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isConflict ? Icons.warning_amber : Icons.link,
                size: 18,
                color: isConflict ? AuroraColors.coral : AuroraColors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _memoryLabel(relationship.type),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _MemoryBadge(label: _memoryLabel(relationship.trustLevel)),
            ],
          ),
          const SizedBox(height: 8),
          _MemoryMetadataRow(label: 'From', value: relationship.fromId),
          _MemoryMetadataRow(label: 'To', value: relationship.toId),
          _MemoryMetadataRow(label: 'Source', value: relationship.sourceId),
        ],
      ),
    );
  }
}

class _MemoryEmptyBlock extends StatelessWidget {
  const _MemoryEmptyBlock({required this.label});

  final String label;

  /// Builds a compact empty block.
  @override
  Widget build(BuildContext context) {
    return _MemorySectionBlock(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(label, style: const TextStyle(color: AuroraColors.muted)),
        ),
      ),
    );
  }
}

class _MemorySelectionEmpty extends StatelessWidget {
  const _MemorySelectionEmpty();

  /// Builds the no-selection state for the stewardship panel.
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Select a memory',
        style: TextStyle(color: AuroraColors.muted),
      ),
    );
  }
}

class _MemoryEntityRow {
  const _MemoryEntityRow({
    required this.name,
    required this.primary,
    required this.count,
    required this.topics,
  });

  final String name;
  final MemoryRecord primary;
  final int count;
  final List<String> topics;
}

class _MemoryTopicRow {
  const _MemoryTopicRow({required this.name, required this.count});

  final String name;
  final int count;
}

/// Groups memory records into entity rows for the People route.
List<_MemoryEntityRow> _memoryEntityRows(List<MemoryRecord> records) {
  final grouped = <String, List<MemoryRecord>>{};
  for (final record in records) {
    for (final entity in record.entityNames) {
      if (entity.trim().isEmpty) {
        continue;
      }
      grouped.putIfAbsent(entity, () => <MemoryRecord>[]).add(record);
    }
  }
  final rows =
      grouped.entries.map((entry) {
        final topics = _counts(
          entry.value.expand((record) => record.topics),
        ).keys.toList();
        return _MemoryEntityRow(
          name: entry.key,
          primary: entry.value.first,
          count: entry.value.length,
          topics: topics,
        );
      }).toList()..sort((a, b) {
        final countCompare = b.count.compareTo(a.count);
        return countCompare == 0 ? a.name.compareTo(b.name) : countCompare;
      });
  return rows;
}

/// Groups memory records into topic timeline rows.
List<_MemoryTopicRow> _memoryTopicRows(List<MemoryRecord> records) {
  return _counts(records.expand((record) => record.topics)).entries
      .map((entry) => _MemoryTopicRow(name: entry.key, count: entry.value))
      .toList();
}

/// Returns whether a memory record matches a command filter query.
bool _matchesMemoryRecord(MemoryRecord record, String query) {
  return _matchesFuzzyQuery(
    '${record.title} ${record.summary} ${record.kind} ${record.scope} '
    '${record.trustLevel} ${record.sensitivity} ${record.status} '
    '${record.sourceLabel} ${record.subjects.join(' ')} '
    '${record.topics.join(' ')} ${record.entityNames.join(' ')}',
    query,
  );
}

/// Returns cross-cutting stewardship reasons for a record.
List<String> _memoryReviewReasons(MemoryRecord record) {
  final reasons = <String>[];
  if (record.sensitivity == 'restricted') {
    reasons.add('restricted');
  }
  if (record.status != 'active') {
    reasons.add(record.status);
  }
  if (record.trustLevel == 'model_extracted' ||
      record.trustLevel == 'model_synthesized') {
    reasons.add(record.trustLevel);
  }
  if (record.topics.isEmpty) {
    reasons.add('missing topics');
  }
  if (record.entityIds.isEmpty && record.entityNames.isEmpty) {
    reasons.add('missing entities');
  }
  if (record.relationships.any((rel) => rel.type == 'contradicts')) {
    reasons.add('contradiction');
  }
  return reasons;
}

/// Counts non-empty facet values.
Map<String, int> _counts(Iterable<String> values) {
  final counts = <String, int>{};
  for (final value in values) {
    if (value.trim().isEmpty) {
      continue;
    }
    counts[value] = (counts[value] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final countCompare = b.value.compareTo(a.value);
      return countCompare == 0 ? a.key.compareTo(b.key) : countCompare;
    });
  return Map<String, int>.fromEntries(entries);
}

/// Applies one server-supported memory facet.
void _applySingleFacet(
  AuroraAppController controller, {
  List<String>? kinds,
  List<String>? topics,
  List<String>? allowedSensitivities,
}) {
  unawaited(
    controller.applyMemoryFilters(
      controller.memoryFilters.copyWith(
        kinds: kinds ?? const <String>[],
        topics: topics ?? const <String>[],
        allowedSensitivities:
            allowedSensitivities ??
            controller.memoryFilters.allowedSensitivities,
      ),
    ),
  );
}

/// Selects the first record with the requested entity label.
void _selectFirstEntity(AuroraAppController controller, String entity) {
  final matches = controller.workspace.memoryRecords.where((record) {
    return record.entityNames.contains(entity);
  });
  if (matches.isNotEmpty) {
    unawaited(controller.selectMemory(matches.first.id));
  }
}

/// Toggles a value in a string list.
List<String> _toggleString(List<String> values, String value) {
  if (values.contains(value)) {
    if (values.length == 1) {
      return values;
    }
    return values.where((item) => item != value).toList();
  }
  return <String>[...values, value];
}

/// Splits comma-delimited user input into normalized labels.
List<String> _splitList(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

/// Coerces a dropdown value to a valid controlled value.
String _coerceDropdownValue(
  List<String> values,
  String value,
  String fallback,
) {
  return values.contains(value) ? value : fallback;
}

/// Formats a nullable timestamp for compact display.
String _formatDate(DateTime? value) {
  if (value == null) {
    return '';
  }
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// Converts controlled vocabulary to readable labels.
String _memoryLabel(String value) {
  if (value.isEmpty) {
    return '';
  }
  return value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

class _MemoryCommandPanel extends StatelessWidget {
  const _MemoryCommandPanel({required this.controller});

  final AuroraAppController controller;

  /// Builds the memory command panel with switchable dense content areas.
  @override
  Widget build(BuildContext context) {
    return SwitcherPanel(
      areas: <SwitcherPanelArea>[
        SwitcherPanelArea(
          title: 'Memory & Context',
          icon: Icons.account_tree_outlined,
          builder: _buildKnowledgeContent,
        ),
        SwitcherPanelArea(
          title: 'Tasks',
          icon: Icons.check_circle_outline,
          builder: _buildTasksContent,
        ),
        SwitcherPanelArea(
          title: 'Stewardship',
          icon: Icons.bolt_outlined,
          builder: _buildStewardshipContent,
        ),
      ],
    );
  }

  Widget _buildKnowledgeContent(String query) {
    final filteredRecords = controller.filteredMemoryRecords.where((record) {
      return _matchesMemoryRecord(record, query);
    }).toList();
    if (filteredRecords.isEmpty) {
      return PanelEmptyState(query: query);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final record in filteredRecords)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MemoryRecordTile(
                record: record,
                selected: controller.selectedMemory?.id == record.id,
                onTap: () => unawaited(controller.selectMemory(record.id)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTasksContent(String query) {
    final filteredTasks = controller.workspace.tasks.where((task) {
      return _matchesFuzzyQuery('${task.title} ${task.detail}', query);
    }).toList();
    if (filteredTasks.isEmpty) {
      return PanelEmptyState(query: query);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      child: Column(
        children: <Widget>[
          for (final task in filteredTasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: _TaskLine(task: task),
            ),
        ],
      ),
    );
  }

  Widget _buildStewardshipContent(String query) {
    final memory = controller.selectedMemory;
    if (memory == null) {
      return const _MemorySelectionEmpty();
    }
    if (!_matchesMemoryRecord(memory, query)) {
      return PanelEmptyState(query: query);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _MemoryPanelLabel('Selected Memory'),
          const SizedBox(height: 10),
          Text(
            memory.title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: controller.memoryBusy
                    ? null
                    : () => unawaited(controller.hydrateSelectedMemorySource()),
                icon: const Icon(Icons.article_outlined),
                label: const Text('Load Source'),
              ),
              OutlinedButton.icon(
                onPressed: controller.memoryBusy
                    ? null
                    : () => unawaited(controller.loadEntityPageFromUi(memory)),
                icon: const Icon(Icons.person_search_outlined),
                label: const Text('Entity Page'),
              ),
              for (final topic in memory.topics.take(2))
                OutlinedButton.icon(
                  onPressed: controller.memoryBusy
                      ? null
                      : () => unawaited(controller.loadTimelineFromUi(topic)),
                  icon: const Icon(Icons.timeline_outlined),
                  label: Text(topic),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final reason in _memoryReviewReasons(memory))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MemoryBadge(label: reason),
            ),
        ],
      ),
    );
  }
}

class _MemoryPeopleRoute extends StatelessWidget {
  const _MemoryPeopleRoute({required this.controller});

  final AuroraAppController controller;

  /// Builds the entity page route from live memory catalog records.
  @override
  Widget build(BuildContext context) {
    final entityRows = _memoryEntityRows(controller.workspace.memoryRecords);
    return _PaddedRoute(
      title: 'People',
      subtitle: 'Entity pages compiled from source-backed memory.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _MemoryStatusStrip(controller: controller),
          const SizedBox(height: 18),
          if (entityRows.isEmpty)
            const _MemoryEmptyBlock(label: 'No entities in memory catalog')
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: <Widget>[
                for (final entity in entityRows)
                  SizedBox(
                    width: 360,
                    child: _MemorySectionBlock(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            entity.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${entity.count} source-backed records',
                            style: const TextStyle(color: AuroraColors.muted),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              for (final topic in entity.topics.take(4))
                                _MemoryBadge(label: topic),
                            ],
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: controller.memoryBusy
                                ? null
                                : () => unawaited(
                                    controller.loadEntityPageFromUi(
                                      entity.primary,
                                    ),
                                  ),
                            icon: const Icon(Icons.person_search_outlined),
                            label: const Text('Load Entity Page'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          if (controller.selectedMemoryPage != null) ...<Widget>[
            const SizedBox(height: 28),
            _CompiledPagePreview(page: controller.selectedMemoryPage!),
          ],
        ],
      ),
    );
  }
}

class _MemoryTimelineRoute extends StatelessWidget {
  const _MemoryTimelineRoute({required this.controller});

  final AuroraAppController controller;

  /// Builds topic and event timelines from live memory records.
  @override
  Widget build(BuildContext context) {
    final topicRows = _memoryTopicRows(controller.workspace.memoryRecords);
    final datedRecords =
        controller.workspace.memoryRecords
            .where(
              (record) => record.eventTime != null || record.createdAt != null,
            )
            .toList()
          ..sort((a, b) {
            final left =
                a.eventTime ??
                a.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final right =
                b.eventTime ??
                b.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
    return _PaddedRoute(
      title: 'Calendar',
      subtitle: 'Source-backed memory timelines by topic and event time.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _MemoryStatusStrip(controller: controller),
          const SizedBox(height: 18),
          _MemoryPanelLabel('Topic Timelines'),
          const SizedBox(height: 12),
          if (topicRows.isEmpty)
            const _MemoryEmptyBlock(label: 'No topics in memory catalog')
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (final topic in topicRows)
                  ActionChip(
                    avatar: CircleAvatar(
                      backgroundColor: AuroraColors.greenSoft,
                      child: Text(
                        '${topic.count}',
                        style: const TextStyle(
                          color: AuroraColors.green,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    label: Text(topic.name),
                    onPressed: controller.memoryBusy
                        ? null
                        : () => unawaited(
                            controller.loadTimelineFromUi(topic.name),
                          ),
                  ),
              ],
            ),
          const SizedBox(height: 28),
          _MemoryPanelLabel('Dated Records'),
          const SizedBox(height: 12),
          if (datedRecords.isEmpty)
            const _MemoryEmptyBlock(label: 'No dated memory records')
          else
            Column(
              children: <Widget>[
                for (final record in datedRecords)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MemorySectionBlock(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 142,
                            child: Text(
                              _formatDate(record.eventTime ?? record.createdAt),
                              style: const TextStyle(
                                color: AuroraColors.muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  record.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  record.summary,
                                  style: const TextStyle(
                                    color: AuroraColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          if (controller.selectedMemoryPage != null) ...<Widget>[
            const SizedBox(height: 28),
            _CompiledPagePreview(page: controller.selectedMemoryPage!),
          ],
        ],
      ),
    );
  }
}

class _CompiledPagePreview extends StatelessWidget {
  const _CompiledPagePreview({required this.page});

  final CompiledMemoryPage page;

  /// Builds a source-backed compiled page preview.
  @override
  Widget build(BuildContext context) {
    return _MemorySectionBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            page.title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MemoryBadge(label: page.kind),
              _MemoryBadge(label: page.scope),
              _MemoryBadge(label: '${page.sourceIds.length} sources'),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(page.content),
        ],
      ),
    );
  }
}

class _SourcesPage extends StatelessWidget {
  const _SourcesPage({required this.workspace});

  final ProjectWorkspace workspace;

  /// Builds the sources and files route.
  @override
  Widget build(BuildContext context) {
    final records = workspace.memoryRecords;
    return _PaddedRoute(
      title: 'Files',
      subtitle: 'Immutable evidence and source material from memory.',
      child: records.isEmpty
          ? const _MemoryEmptyBlock(label: 'No source evidence loaded')
          : Wrap(
              spacing: 16,
              runSpacing: 16,
              children: records.map((record) {
                return SizedBox(
                  width: 360,
                  child: _MemorySectionBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          record.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _MemoryMetadataRow(
                          label: 'Evidence',
                          value: record.evidenceId,
                        ),
                        _MemoryMetadataRow(
                          label: 'Source',
                          value: record.sourceLabel,
                        ),
                        _MemoryMetadataRow(
                          label: 'Path',
                          value: record.rawPath,
                        ),
                        _MemoryMetadataRow(
                          label: 'Media',
                          value: record.rawMediaType,
                        ),
                        _MemoryMetadataRow(
                          label: 'Checksum',
                          value: record.rawChecksum,
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

const List<({String label, IconData icon, String detail})> _settingsSections =
    <({String label, IconData icon, String detail})>[
      (
        label: 'Profiles',
        icon: Icons.person_outline,
        detail: 'Runtime topology and active profile.',
      ),
      (
        label: 'Models',
        icon: Icons.memory_outlined,
        detail: 'Model config and harness runtime.',
      ),
      (
        label: 'Agent',
        icon: Icons.psychology_outlined,
        detail: 'Agent config and prompt policy.',
      ),
      (
        label: 'Memory',
        icon: Icons.account_tree_outlined,
        detail: 'Memory MCP bindings.',
      ),
      (label: 'Tasks', icon: Icons.checklist, detail: 'Task MCP bindings.'),
      (
        label: 'Tools',
        icon: Icons.tune,
        detail: 'Tool configuration and policy.',
      ),
      (
        label: 'Runtime',
        icon: Icons.bolt_outlined,
        detail: 'Processes and endpoint health.',
      ),
    ];

class _SettingsMenuPanel extends StatelessWidget {
  const _SettingsMenuPanel({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  /// Builds the settings sub-menu picker.
  @override
  Widget build(BuildContext context) {
    return MenuPanel(
      title: 'Settings',
      subtitle: 'Profiles, models, memory, tasks, tools, and runtime.',
      selectedKey: selected,
      onSelected: onSelected,
      items: <MenuPanelItem>[
        for (final section in _settingsSections)
          MenuPanelItem(
            key: section.label,
            label: section.label,
            icon: section.icon,
            detail: section.detail,
          ),
      ],
    );
  }
}

class _SettingsDetailsPanel extends StatelessWidget {
  const _SettingsDetailsPanel({
    required this.controller,
    required this.section,
  });

  final AuroraAppController controller;
  final String section;

  /// Builds the selected settings CRUD/details panel.
  @override
  Widget build(BuildContext context) {
    final profile = controller.runtimeProfile;
    if (profile != null &&
        (section == 'Profiles' || section == 'Models' || section == 'Agent')) {
      return _buildSection(profile);
    }
    return DetailPanel(
      title: section,
      subtitle: _settingsSectionSubtitle(section),
      child: profile == null
          ? _RuntimeProfileMissing(message: controller.statusMessage)
          : _buildSection(profile),
    );
  }

  Widget _buildSection(RuntimeProfile profile) {
    return switch (section) {
      'Profiles' => _SettingsProfilesCollection(
        controller: controller,
        profile: profile,
        profilePath: controller.runtimeProfilePath,
      ),
      'Models' => _SettingsConfigFileCollection(
        controller: controller,
        title: 'Models',
        emptyLabel: 'No model configs configured',
        icon: Icons.memory_outlined,
        kind: ConfigFileKind.model,
        entries: controller.availableModelConfigs,
        assignedPath: profile.harness.modelConfigPath,
      ),
      'Agent' => _SettingsConfigFileCollection(
        controller: controller,
        title: 'Agents',
        emptyLabel: 'No agent configs configured',
        icon: Icons.psychology_outlined,
        kind: ConfigFileKind.agent,
        entries: controller.availableAgentConfigs,
        assignedPath: profile.harness.agentConfigPath,
      ),
      'Memory' => _SettingsServerContent(
        profile: profile,
        controller: controller,
        title: 'Memory bindings',
        servers: profile.memoryServers,
      ),
      'Tasks' => _SettingsServerContent(
        profile: profile,
        controller: controller,
        title: 'Task bindings',
        servers: profile.taskServers,
      ),
      'Tools' => _SettingsConfigFileCollection(
        controller: controller,
        title: 'Tools',
        emptyLabel: 'No tool configs configured',
        icon: Icons.tune,
        kind: ConfigFileKind.tool,
        entries: controller.availableToolConfigs,
        assignedPath: profile.harness.toolConfigPath,
      ),
      'Runtime' => _SettingsRuntimeContent(
        statuses: controller.endpointStatuses,
        localStatuses: controller.localProcessStatuses,
      ),
      _ => _SettingsProfilesCollection(
        controller: controller,
        profile: profile,
        profilePath: controller.runtimeProfilePath,
      ),
    };
  }
}

class _RuntimeProfileMissing extends StatelessWidget {
  const _RuntimeProfileMissing({required this.message});

  final String message;

  /// Builds the profile configuration error state.
  @override
  Widget build(BuildContext context) {
    return Center(
      child: _MemorySectionBlock(
        child: Text(message, style: const TextStyle(color: AuroraColors.coral)),
      ),
    );
  }
}

class _SettingsProfilesCollection extends StatefulWidget {
  const _SettingsProfilesCollection({
    required this.controller,
    required this.profile,
    required this.profilePath,
  });

  final AuroraAppController controller;
  final RuntimeProfile profile;
  final String profilePath;

  @override
  State<_SettingsProfilesCollection> createState() =>
      _SettingsProfilesCollectionState();
}

class _SettingsProfilesCollectionState
    extends State<_SettingsProfilesCollection> {
  String _message = '';

  /// Builds a file-backed runtime profile collection panel.
  @override
  Widget build(BuildContext context) {
    final profiles = widget.controller.availableProfiles.isEmpty
        ? <RuntimeProfileFileEntry>[
            RuntimeProfileFileEntry(
              path: widget.profilePath,
              id: widget.profile.id,
              label: widget.profile.label,
              active: true,
            ),
          ]
        : widget.controller.availableProfiles;
    return CollectionSwitcherPanel<RuntimeProfileFileEntry>(
      title: 'Profiles',
      selectedId: widget.profilePath,
      emptyLabel: 'No profiles configured',
      items: <CollectionPanelItem<RuntimeProfileFileEntry>>[
        for (final entry in profiles)
          CollectionPanelItem<RuntimeProfileFileEntry>(
            id: entry.path,
            label: entry.label,
            detail: entry.path,
            icon: Icons.person_outline,
            badge: entry.path == widget.profilePath ? 'Active' : '',
            value: entry,
          ),
      ],
      onSelect: (path) => unawaited(_load(path)),
      onCreate: () => unawaited(_create()),
      onDuplicate: (_) => unawaited(_duplicate()),
      onDelete: (_) => unawaited(_delete()),
      builder: (entry, query) {
        return _SettingsProfileEditor(
          controller: widget.controller,
          profile: widget.profile,
          profilePath: entry.path,
          message: _message,
          query: query,
        );
      },
    );
  }

  Future<void> _load(String path) async {
    try {
      await widget.controller.loadRuntimeProfileFromPath(path);
      if (!mounted) {
        return;
      }
      setState(() => _message = 'Loaded ${_settingsFileLabel(path)}');
    } catch (error) {
      setState(() => _message = error.toString());
    }
  }

  Future<void> _create() async {
    try {
      await widget.controller.createRuntimeProfileFile();
      if (!mounted) {
        return;
      }
      setState(() => _message = 'Created profile');
    } catch (error) {
      setState(() => _message = error.toString());
    }
  }

  Future<void> _duplicate() async {
    try {
      await widget.controller.duplicateRuntimeProfileFile();
      if (!mounted) {
        return;
      }
      setState(() => _message = 'Duplicated profile');
    } catch (error) {
      setState(() => _message = error.toString());
    }
  }

  Future<void> _delete() async {
    final confirmed = await _confirmSettingsDelete(
      context,
      label: _settingsFileLabel(widget.profilePath),
    );
    if (!confirmed) {
      return;
    }
    try {
      await widget.controller.deleteActiveRuntimeProfileFile();
      if (!mounted) {
        return;
      }
      setState(() => _message = 'Deleted profile');
    } catch (error) {
      setState(() => _message = error.toString());
    }
  }
}

class _SettingsProfileEditor extends StatefulWidget {
  const _SettingsProfileEditor({
    required this.controller,
    required this.profile,
    required this.profilePath,
    required this.message,
    required this.query,
  });

  final AuroraAppController controller;
  final RuntimeProfile profile;
  final String profilePath;
  final String message;
  final String query;

  @override
  State<_SettingsProfileEditor> createState() => _SettingsProfileEditorState();
}

class _SettingsProfileEditorState extends State<_SettingsProfileEditor> {
  late final TextEditingController _label = TextEditingController(
    text: widget.profile.label,
  );
  String _savedLabel = '';
  String _localMessage = '';

  /// Initializes profile editor state.
  @override
  void initState() {
    super.initState();
    _savedLabel = widget.profile.label;
  }

  /// Cleans up profile form controllers.
  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  /// Synchronizes controllers when a different profile is loaded.
  @override
  void didUpdateWidget(covariant _SettingsProfileEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.label != widget.profile.label) {
      _label.text = widget.profile.label;
      _savedLabel = widget.profile.label;
    }
  }

  /// Builds active profile details from the loaded JSON profile.
  @override
  Widget build(BuildContext context) {
    if (!_settingsMatchesQuery(widget.query, <String>[
      widget.profile.label,
      widget.profilePath,
    ])) {
      return PanelEmptyState(query: widget.query);
    }
    return FormPanel(
      children: <Widget>[
        _SettingsSectionCard(
          title: 'Details',
          children: <Widget>[
            _SettingsAutoSaveTextField(
              label: 'Name',
              controller: _label,
              initialSavedValue: _savedLabel,
              onSave: _saveLabel,
            ),
            _SettingsReadOnlyField(
              label: 'JSON source',
              value: widget.profilePath,
            ),
            _SettingsMessageText(
              message: _localMessage.isEmpty ? widget.message : _localMessage,
            ),
          ],
        ),
        _SettingsSectionCard(
          title: 'Assignments',
          children: <Widget>[
            _SettingsConfigDropdown(
              label: 'Model',
              entries: widget.controller.availableModelConfigs,
              selectedPath: widget.profile.harness.modelConfigPath,
              onChanged: _assignConfig,
            ),
            _SettingsConfigDropdown(
              label: 'Agent',
              entries: widget.controller.availableAgentConfigs,
              selectedPath: widget.profile.harness.agentConfigPath,
              onChanged: _assignConfig,
            ),
            _SettingsConfigDropdown(
              label: 'Tools',
              entries: widget.controller.availableToolConfigs,
              selectedPath: widget.profile.harness.toolConfigPath,
              onChanged: _assignConfig,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveLabel(String value) async {
    final next = widget.profile.copyWith(label: value.trim());
    try {
      await widget.controller.saveRuntimeProfile(next);
      if (!mounted) {
        return;
      }
      setState(() {
        _savedLabel = value.trim();
        _localMessage = 'Saved profile';
      });
    } catch (error) {
      setState(() {
        _localMessage = error.toString();
      });
    }
  }

  /// Assigns a selected config file to this profile.
  Future<void> _assignConfig(ConfigFileEntry entry) async {
    try {
      await widget.controller.assignConfigFile(entry);
      if (!mounted) {
        return;
      }
      setState(() {
        _localMessage = 'Assigned ${entry.label}';
      });
    } catch (error) {
      setState(() {
        _localMessage = error.toString();
      });
    }
  }
}

class _SettingsConfigFileCollection extends StatefulWidget {
  const _SettingsConfigFileCollection({
    required this.controller,
    required this.title,
    required this.emptyLabel,
    required this.icon,
    required this.kind,
    required this.entries,
    required this.assignedPath,
  });

  final AuroraAppController controller;
  final String title;
  final String emptyLabel;
  final IconData icon;
  final ConfigFileKind kind;
  final List<ConfigFileEntry> entries;
  final String assignedPath;

  @override
  State<_SettingsConfigFileCollection> createState() =>
      _SettingsConfigFileCollectionState();
}

class _SettingsConfigFileCollectionState
    extends State<_SettingsConfigFileCollection> {
  String? _selectedPath;
  String _message = '';

  /// Initializes selected config file state.
  @override
  void initState() {
    super.initState();
    _selectedPath = _initialSelectedPath();
  }

  /// Keeps selected config file state valid after collection updates.
  @override
  void didUpdateWidget(covariant _SettingsConfigFileCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedPath == null ||
        !widget.entries.any((entry) => entry.path == _selectedPath)) {
      _selectedPath = _initialSelectedPath();
    }
  }

  /// Builds a collection switcher for model or agent config files.
  @override
  Widget build(BuildContext context) {
    return CollectionSwitcherPanel<ConfigFileEntry>(
      title: widget.title,
      selectedId: _selectedPath,
      emptyLabel: widget.emptyLabel,
      items: <CollectionPanelItem<ConfigFileEntry>>[
        for (final entry in widget.entries)
          CollectionPanelItem<ConfigFileEntry>(
            id: entry.id,
            label: entry.label,
            detail: entry.path,
            icon: widget.icon,
            badge: entry.assigned ? 'Active' : '',
            value: entry,
          ),
      ],
      onSelect: (id) => setState(() => _selectedPath = id),
      onCreate: () => unawaited(_create()),
      onDuplicate: (entry) => unawaited(_duplicate(entry)),
      onDelete: (entry) => unawaited(_delete(entry)),
      builder: (entry, query) {
        return _SettingsConfigFileEditor(
          controller: widget.controller,
          entry: entry,
          title: '${_settingsKindLabel(entry.kind)} config file',
          message: _message,
          query: query,
          onRenamed: (path) => setState(() => _selectedPath = path),
        );
      },
    );
  }

  String? _initialSelectedPath() {
    if (widget.assignedPath.isNotEmpty &&
        widget.entries.any((entry) => entry.path == widget.assignedPath)) {
      return widget.assignedPath;
    }
    if (widget.entries.isEmpty) {
      return null;
    }
    return widget.entries.first.path;
  }

  Future<void> _create() async {
    try {
      final path = await widget.controller.createConfigFile(widget.kind);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedPath = path;
        _message = 'Created ${_settingsFileLabel(path)}';
      });
    } catch (error) {
      setState(() => _message = error.toString());
    }
  }

  Future<void> _duplicate(ConfigFileEntry entry) async {
    try {
      final path = await widget.controller.duplicateConfigFile(entry);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedPath = path;
        _message = 'Duplicated ${entry.label}';
      });
    } catch (error) {
      setState(() => _message = error.toString());
    }
  }

  Future<void> _delete(ConfigFileEntry entry) async {
    final confirmed = await _confirmSettingsDelete(context, label: entry.label);
    if (!confirmed) {
      return;
    }
    try {
      await widget.controller.deleteConfigFile(entry);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedPath = _initialSelectedPath();
        _message = 'Deleted ${entry.label}';
      });
    } catch (error) {
      setState(() => _message = error.toString());
    }
  }
}

class _SettingsConfigFileEditor extends StatefulWidget {
  const _SettingsConfigFileEditor({
    required this.controller,
    required this.entry,
    required this.title,
    required this.message,
    required this.query,
    required this.onRenamed,
  });

  final AuroraAppController controller;
  final ConfigFileEntry entry;
  final String title;
  final String message;
  final String query;
  final ValueChanged<String> onRenamed;

  @override
  State<_SettingsConfigFileEditor> createState() =>
      _SettingsConfigFileEditorState();
}

class _SettingsConfigFileEditorState extends State<_SettingsConfigFileEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.entry.label,
  );
  late String _savedName = widget.entry.label;
  String _assignmentMessage = '';

  /// Cleans up config editor controllers.
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Keeps the editable name synchronized with the selected file.
  @override
  void didUpdateWidget(covariant _SettingsConfigFileEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.path != widget.entry.path) {
      _name.text = widget.entry.label;
      _savedName = widget.entry.label;
      _assignmentMessage = '';
    }
  }

  /// Builds the selected model or agent config editor.
  @override
  Widget build(BuildContext context) {
    if (!_settingsMatchesQuery(widget.query, <String>[
      widget.entry.label,
      widget.entry.path,
    ])) {
      return PanelEmptyState(query: widget.query);
    }
    return FormPanel(
      children: <Widget>[
        _SettingsSectionCard(
          title: 'Details',
          children: <Widget>[
            _SettingsAutoSaveTextField(
              label: 'Name',
              controller: _name,
              initialSavedValue: _savedName,
              onSave: _rename,
            ),
            _SettingsReadOnlyField(label: 'Path', value: widget.entry.path),
            _SettingsActionRow(
              message: _assignmentMessage.isEmpty
                  ? widget.message
                  : _assignmentMessage,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: widget.entry.assigned
                      ? null
                      : () => unawaited(_assign()),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    widget.entry.assigned ? 'Assigned' : 'Use for profile',
                  ),
                ),
              ],
            ),
          ],
        ),
        _SettingsTextFileEditor(
          controller: widget.controller,
          title: widget.title,
          path: widget.entry.path,
        ),
      ],
    );
  }

  Future<void> _assign() async {
    try {
      await widget.controller.assignConfigFile(widget.entry);
      if (!mounted) {
        return;
      }
      setState(() {
        _assignmentMessage = 'Assigned ${widget.entry.label}';
      });
    } catch (error) {
      setState(() {
        _assignmentMessage = error.toString();
      });
    }
  }

  Future<void> _rename(String value) async {
    try {
      final path = await widget.controller.renameConfigFile(
        widget.entry,
        value,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _savedName = value.trim();
        _assignmentMessage = 'Renamed to ${_settingsFileLabel(path)}';
      });
      widget.onRenamed(path);
    } catch (error) {
      setState(() {
        _assignmentMessage = error.toString();
      });
    }
  }
}

class _SettingsServerContent extends StatelessWidget {
  const _SettingsServerContent({
    required this.profile,
    required this.controller,
    required this.title,
    required this.servers,
  });

  final RuntimeProfile profile;
  final AuroraAppController controller;
  final String title;
  final List<McpServerRuntime> servers;

  /// Builds MCP server binding details for one server kind.
  @override
  Widget build(BuildContext context) {
    return FormPanel(
      children: <Widget>[
        _SettingsSectionCard(
          title: title,
          children: servers.isEmpty
              ? const <Widget>[
                  _MemoryEmptyBlock(label: 'No servers configured'),
                ]
              : <Widget>[
                  for (final server in servers)
                    _SettingsServerTile(
                      profile: profile,
                      controller: controller,
                      server: server,
                    ),
                ],
        ),
      ],
    );
  }
}

class _SettingsRuntimeContent extends StatelessWidget {
  const _SettingsRuntimeContent({
    required this.statuses,
    required this.localStatuses,
  });

  final List<EndpointStatus> statuses;
  final List<ServiceProcessStatus> localStatuses;

  /// Builds runtime process and endpoint status details.
  @override
  Widget build(BuildContext context) {
    return FormPanel(
      children: <Widget>[
        if (localStatuses.isNotEmpty)
          _SettingsSectionCard(
            title: 'Local processes',
            children: <Widget>[
              for (final status in localStatuses)
                _ServiceProcessRow(status: status),
            ],
          ),
        _SettingsSectionCard(
          title: 'Service endpoints',
          children: <Widget>[
            for (final status in statuses) _EndpointRow(status: status),
          ],
        ),
      ],
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  /// Builds one settings detail group.
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xfffffcf8),
        border: Border.all(color: AuroraColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _MemoryPanelLabel(title),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsReadOnlyField extends StatelessWidget {
  const _SettingsReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  /// Builds a read-only settings field.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AuroraColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AuroraColors.border),
          ),
        ),
      ),
    );
  }
}

class _SettingsAutoSaveTextField extends StatefulWidget {
  const _SettingsAutoSaveTextField({
    required this.label,
    required this.controller,
    required this.initialSavedValue,
    required this.onSave,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String initialSavedValue;
  final Future<void> Function(String value) onSave;
  final int minLines;
  final int maxLines;

  @override
  State<_SettingsAutoSaveTextField> createState() =>
      _SettingsAutoSaveTextFieldState();
}

class _SettingsAutoSaveTextFieldState
    extends State<_SettingsAutoSaveTextField> {
  late final FocusNode _focusNode = FocusNode();
  late String _savedValue = widget.initialSavedValue;

  /// Initializes focus tracking for blur autosave.
  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  /// Synchronizes saved value when the selected backing item changes.
  @override
  void didUpdateWidget(covariant _SettingsAutoSaveTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSavedValue != widget.initialSavedValue) {
      _savedValue = widget.initialSavedValue;
    }
  }

  /// Cleans up field focus state.
  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  /// Builds an editable field that saves when focus leaves it.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        focusNode: _focusNode,
        controller: widget.controller,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label,
          filled: true,
          fillColor: AuroraColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AuroraColors.border),
          ),
        ),
      ),
    );
  }

  /// Saves changed field content after focus leaves the field.
  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      return;
    }
    final next = widget.controller.text.trim();
    if (next == _savedValue.trim()) {
      return;
    }
    _savedValue = next;
    unawaited(widget.onSave(next));
  }
}

class _SettingsConfigDropdown extends StatelessWidget {
  const _SettingsConfigDropdown({
    required this.label,
    required this.entries,
    required this.selectedPath,
    required this.onChanged,
  });

  final String label;
  final List<ConfigFileEntry> entries;
  final String selectedPath;
  final ValueChanged<ConfigFileEntry> onChanged;

  /// Builds a profile assignment dropdown for config files.
  @override
  Widget build(BuildContext context) {
    final selected = entries.any((entry) => entry.path == selectedPath)
        ? selectedPath
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        items: <DropdownMenuItem<String>>[
          for (final entry in entries)
            DropdownMenuItem<String>(
              value: entry.path,
              child: Text(entry.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (path) {
          if (path == null) {
            return;
          }
          for (final entry in entries) {
            if (entry.path == path) {
              onChanged(entry);
              return;
            }
          }
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AuroraColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AuroraColors.border),
          ),
        ),
      ),
    );
  }
}

class _SettingsMessageText extends StatelessWidget {
  const _SettingsMessageText({required this.message});

  final String message;

  /// Builds a compact settings operation message.
  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AuroraColors.muted),
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({required this.children, required this.message});

  final List<Widget> children;
  final String message;

  /// Builds settings action buttons and the last operation message.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          ...children,
          if (message.isNotEmpty) ...<Widget>[
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AuroraColors.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Returns a compact file label for settings collection items.
String _settingsFileLabel(String path) {
  final filename = path.replaceAll('\\', '/').split('/').last;
  final dot = filename.lastIndexOf('.');
  if (dot <= 0) {
    return filename;
  }
  return filename.substring(0, dot);
}

/// Returns the display label for a managed config file kind.
String _settingsKindLabel(ConfigFileKind kind) {
  return switch (kind) {
    ConfigFileKind.model => 'Model',
    ConfigFileKind.agent => 'Agent',
    ConfigFileKind.tool => 'Tool',
  };
}

/// Returns whether settings values match a filter query.
bool _settingsMatchesQuery(String query, List<String> values) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  return values.any((value) => value.toLowerCase().contains(normalized));
}

/// Confirms a destructive settings deletion.
Future<bool> _confirmSettingsDelete(
  BuildContext context, {
  required String label,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete configuration'),
        content: Text('Delete "$label"? This cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

class _SettingsTextFileEditor extends StatefulWidget {
  const _SettingsTextFileEditor({
    required this.controller,
    required this.title,
    required this.path,
  });

  final AuroraAppController controller;
  final String title;
  final String path;

  @override
  State<_SettingsTextFileEditor> createState() =>
      _SettingsTextFileEditorState();
}

class _SettingsTextFileEditorState extends State<_SettingsTextFileEditor> {
  final TextEditingController _content = TextEditingController();
  final FocusNode _contentFocus = FocusNode();
  String _savedContent = '';
  String _message = '';
  bool _loading = true;

  /// Loads the file editor content.
  @override
  void initState() {
    super.initState();
    _contentFocus.addListener(_handleContentFocusChange);
    unawaited(_load());
  }

  /// Reloads editor content when the target file path changes.
  @override
  void didUpdateWidget(covariant _SettingsTextFileEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      unawaited(_load());
    }
  }

  /// Cleans up the text editor controller.
  @override
  void dispose() {
    _contentFocus.removeListener(_handleContentFocusChange);
    _contentFocus.dispose();
    _content.dispose();
    super.dispose();
  }

  /// Builds a raw editor for the referenced configuration file.
  @override
  Widget build(BuildContext context) {
    return _SettingsSectionCard(
      title: widget.title,
      children: <Widget>[
        _SettingsReadOnlyField(label: 'Path', value: widget.path),
        if (_loading)
          const LinearProgressIndicator(minHeight: 2)
        else
          TextFormField(
            focusNode: _contentFocus,
            controller: _content,
            minLines: 14,
            maxLines: 28,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AuroraColors.surface,
              alignLabelWithHint: true,
              labelText: 'File content',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AuroraColors.border),
              ),
            ),
          ),
        const SizedBox(height: 12),
        _SettingsActionRow(
          message: _message,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      _content.text = await widget.controller.readConfigurationFile(
        widget.path,
      );
      _savedContent = _content.text;
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Loaded file';
      });
    } catch (error) {
      _content.text = '';
      _savedContent = '';
      if (!mounted) {
        return;
      }
      setState(() {
        _message = '$error. Saving will create this file.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_content.text == _savedContent) {
      return;
    }
    try {
      await widget.controller.saveConfigurationFile(widget.path, _content.text);
      _savedContent = _content.text;
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Saved file';
      });
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    }
  }

  /// Saves changed file content after focus leaves the editor.
  void _handleContentFocusChange() {
    if (_contentFocus.hasFocus || _loading) {
      return;
    }
    unawaited(_save());
  }
}

class _SettingsServerTile extends StatefulWidget {
  const _SettingsServerTile({
    required this.profile,
    required this.controller,
    required this.server,
  });

  final RuntimeProfile profile;
  final AuroraAppController controller;
  final McpServerRuntime server;

  @override
  State<_SettingsServerTile> createState() => _SettingsServerTileState();
}

class _SettingsServerTileState extends State<_SettingsServerTile> {
  late final TextEditingController _id = TextEditingController(
    text: widget.server.id,
  );
  late final TextEditingController _label = TextEditingController(
    text: widget.server.label,
  );
  late final TextEditingController _endpoint = TextEditingController(
    text: widget.server.endpoint,
  );
  late final TextEditingController _healthUrl = TextEditingController(
    text: widget.server.healthUrl,
  );
  late final TextEditingController _workingDirectory = TextEditingController(
    text: widget.server.workingDirectory,
  );
  late final TextEditingController _packagePath = TextEditingController(
    text: widget.server.packagePath,
  );
  late final TextEditingController _arguments = TextEditingController(
    text: widget.server.arguments.join('\n'),
  );
  late bool _enabled = widget.server.enabled;
  late bool _autoStart = widget.server.autoStart;
  String _message = '';

  /// Cleans up MCP server form controllers.
  @override
  void dispose() {
    _id.dispose();
    _label.dispose();
    _endpoint.dispose();
    _healthUrl.dispose();
    _workingDirectory.dispose();
    _packagePath.dispose();
    _arguments.dispose();
    super.dispose();
  }

  /// Builds one MCP binding tile from the active profile.
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuroraColors.surface,
        border: Border.all(color: AuroraColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Switch(
                value: _enabled,
                onChanged: (value) {
                  setState(() => _enabled = value);
                  unawaited(_save());
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SettingsAutoSaveTextField(
                  label: 'Label',
                  controller: _label,
                  initialSavedValue: widget.server.label,
                  onSave: (_) => _save(),
                ),
              ),
              _MemoryBadge(label: _autoStart ? 'Managed' : 'External'),
            ],
          ),
          _SettingsAutoSaveTextField(
            label: 'Server ID',
            controller: _id,
            initialSavedValue: widget.server.id,
            onSave: (_) => _save(),
          ),
          _SettingsAutoSaveTextField(
            label: 'Endpoint',
            controller: _endpoint,
            initialSavedValue: widget.server.endpoint,
            onSave: (_) => _save(),
          ),
          _SettingsAutoSaveTextField(
            label: 'Health URL',
            controller: _healthUrl,
            initialSavedValue: widget.server.healthUrl,
            onSave: (_) => _save(),
          ),
          _SettingsAutoSaveTextField(
            label: 'Working directory',
            controller: _workingDirectory,
            initialSavedValue: widget.server.workingDirectory,
            onSave: (_) => _save(),
          ),
          _SettingsAutoSaveTextField(
            label: 'Package path',
            controller: _packagePath,
            initialSavedValue: widget.server.packagePath,
            onSave: (_) => _save(),
          ),
          _SettingsAutoSaveTextField(
            label: 'Arguments, one per line',
            controller: _arguments,
            initialSavedValue: widget.server.arguments.join('\n'),
            onSave: (_) => _save(),
            minLines: 3,
            maxLines: 8,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-start server'),
            value: _autoStart,
            onChanged: (value) {
              setState(() => _autoStart = value);
              unawaited(_save());
            },
          ),
          _SettingsMessageText(message: _message),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final replacement = widget.server.copyWith(
      id: _id.text.trim(),
      label: _label.text.trim(),
      endpoint: _endpoint.text.trim(),
      healthUrl: _healthUrl.text.trim(),
      workingDirectory: _workingDirectory.text.trim(),
      packagePath: _packagePath.text.trim(),
      arguments: _arguments.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(),
      autoStart: _autoStart,
      enabled: _enabled,
    );
    final servers = widget.profile.mcpServers.map((server) {
      return server.id == widget.server.id ? replacement : server;
    }).toList();
    try {
      await widget.controller.saveRuntimeProfile(
        widget.profile.copyWith(mcpServers: servers),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Saved binding';
      });
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    }
  }
}

String _settingsSectionSubtitle(String section) {
  return switch (section) {
    'Profiles' => 'Runtime profiles stored in the app config directory.',
    'Models' => 'Reusable model config files for profile assignment.',
    'Agent' => 'Reusable agent config files for profile assignment.',
    'Memory' => 'Memory MCP servers available to chat and memory surfaces.',
    'Tasks' => 'Task MCP servers available to chat and workflow surfaces.',
    'Tools' => 'Tool config assigned to the harness for this profile.',
    'Runtime' => 'Live process and endpoint state.',
    _ => 'Active profile and profile-level assignments.',
  };
}

class _ServiceProcessRow extends StatelessWidget {
  const _ServiceProcessRow({required this.status});

  final ServiceProcessStatus status;

  /// Builds one local process status row.
  @override
  Widget build(BuildContext context) {
    return StatusRow(
      name: status.name,
      url: status.url,
      state: status.state,
      message: status.message,
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({required this.status});

  final EndpointStatus status;

  /// Builds one service connection row.
  @override
  Widget build(BuildContext context) {
    return StatusRow(
      name: status.name,
      url: status.url,
      state: status.state,
      message: status.message,
    );
  }
}

class _PaddedRoute extends StatelessWidget {
  const _PaddedRoute({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// Builds a standard sidebar route layout.
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(color: AuroraColors.muted, fontSize: 17),
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}

Future<void> _confirmCreateTask(
  BuildContext context,
  AuroraAppController controller,
) async {
  final input = TextEditingController();
  final title = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Create Task'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Task title'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(input.text),
            child: const Text('Create'),
          ),
        ],
      );
    },
  );
  input.dispose();
  if (title == null || title.trim().isEmpty || !context.mounted) {
    return;
  }
  final approved = await _confirmWrite(context, 'Create task "$title"?');
  if (approved) {
    await controller.createTaskFromUi(title.trim());
  }
}

Future<void> _confirmCompleteTask(
  BuildContext context,
  AuroraAppController controller,
  WorkspaceTask task,
) async {
  final approved = await _confirmWrite(context, 'Complete "${task.title}"?');
  if (approved) {
    await controller.completeTaskFromUi(task.id);
  }
}

Future<bool> _confirmWrite(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Confirm Write'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Approve'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
