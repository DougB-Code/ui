/// Implements the Aurora assistant workspace shell and feature surfaces.
library;

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/theme.dart';
import '../domain/models.dart';

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
              panels: _buildPanels(context),
            ),
          ),
        );
      },
    );
  }

  _ShellPanels _buildPanels(BuildContext context) {
    switch (_section) {
      case 'Workflows':
        return _ShellPanels(
          center: _WorkspaceCenter(
            controller: widget.controller,
            onBackHome: () => _selectSection('Today'),
          ),
          right: _MemoryContextPanel(workspace: widget.controller.workspace),
          showCommandBar: false,
        );
      case 'Memory':
        return _ShellPanels(
          center: _MemoryPage(workspace: widget.controller.workspace),
        );
      case 'Files':
        return _ShellPanels(
          center: _SourcesPage(workspace: widget.controller.workspace),
        );
      case 'Settings':
        return _ShellPanels(
          center: _SettingsPage(
            statuses: widget.controller.endpointStatuses,
            statusMessage: widget.controller.statusMessage,
          ),
        );
      case 'Calendar':
      case 'People':
        return _ShellPanels(center: _EmptyRoute(title: _section));
      default:
        return _ShellPanels(
          center: _HomeWorkspace(controller: widget.controller),
        );
    }
  }

  void _selectSection(String section) {
    setState(() {
      _section = section;
    });
    if (section == 'Workflows') {
      widget.controller.openWorkspace();
    } else if (section == 'Today') {
      widget.controller.openHome();
    }
  }

  void _submitCommand() {
    final value = _commandController.text;
    _commandController.clear();
    widget.controller.sendUserMessage(value);
  }

  void _toggleSidebar() {
    setState(() {
      _sidebarExpanded = !_sidebarExpanded;
    });
  }
}

class _ShellPanels {
  const _ShellPanels({
    required this.center,
    this.right,
    this.showCommandBar = true,
  });

  final Widget center;
  final Widget? right;
  final bool showCommandBar;
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
    required this.panels,
  });

  final String selectedSection;
  final AuroraAppController controller;
  final TextEditingController commandController;
  final bool sidebarExpanded;
  final ValueChanged<String> onSelected;
  final VoidCallback onToggleSidebar;
  final VoidCallback onSubmit;
  final VoidCallback onOpenSettings;
  final _ShellPanels panels;

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
              if (panels.showCommandBar)
                _CommandBar(
                  controller: commandController,
                  onSubmit: onSubmit,
                  onNewChat: controller.createChat,
                  onOpenSettings: onOpenSettings,
                ),
              Expanded(child: _PanelBody(panels: panels)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({required this.panels});

  final _ShellPanels panels;

  /// Places the active center panel and optional right context panel.
  @override
  Widget build(BuildContext context) {
    final right = panels.right;
    if (right == null) {
      return panels.center;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 940) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: constraints.maxHeight, child: panels.center),
                right,
              ],
            ),
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: panels.center),
            right,
          ],
        );
      },
    );
  }
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
        (label: 'Workflows', icon: Icons.radio_button_unchecked),
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
    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(36, 36, 36, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _Eyebrow('ACTIVE OBJECTIVE', color: AuroraColors.coral),
                const SizedBox(height: 22),
                Text(
                  'Prepare investor meeting brief',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Maple Ventures Series B update - Tomorrow 10:00 AM',
                  style: TextStyle(color: AuroraColors.muted, fontSize: 17),
                ),
                const SizedBox(height: 38),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final chatColumn = Column(
                      children: <Widget>[
                        for (final message in controller.messages)
                          _ChatRow(message: message),
                        const SizedBox(height: 18),
                        const _DraftCard(
                          title: 'Maple Ventures Series B Update',
                          compact: true,
                        ),
                      ],
                    );
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
                          child: _ExecutionPlan(
                            tasks: controller.executionSteps,
                          ),
                        ),
                        const SizedBox(width: 36),
                        Expanded(child: chatColumn),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const _DayStrip(),
      ],
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
        const SizedBox(height: 32),
        TextButton.icon(
          onPressed: () {},
          icon: const Text('View all steps'),
          label: const Icon(Icons.chevron_right),
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
        Text(message.text, style: const TextStyle(fontSize: 16, height: 1.55)),
      ],
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.title, this.compact = false});

  final String title;
  final bool compact;

  /// Builds the generated draft preview.
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xfffffcf8),
        border: Border.all(color: AuroraColors.border),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x17453421),
            blurRadius: 60,
            offset: Offset(0, 26),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                'Draft v1',
                style: TextStyle(color: AuroraColors.muted),
              ),
              const Spacer(),
              _MiniTool(label: 'B'),
              _MiniTool(label: 'I'),
              const Icon(Icons.format_list_bulleted, size: 18),
              const Icon(Icons.north_east, size: 18),
            ],
          ),
          const Divider(height: 32),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: compact ? 30 : 36,
              color: AuroraColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Research Brief - May 20, 2025',
            style: TextStyle(color: AuroraColors.muted),
          ),
          const SizedBox(height: 28),
          const Text(
            'Executive Summary',
            style: TextStyle(
              color: AuroraColors.coral,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'The market continues to mature with a strong emphasis on efficiency, AI enablement, and vertical specialization.',
          ),
          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            '1. Market Overview',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 24),
          ),
          const SizedBox(height: 12),
          const Text(
            'Efficient growth has overtaken raw expansion as the dominant operating narrative.',
          ),
          const Text(
            'Buyers increasingly prefer platforms that reduce operational fragmentation.',
          ),
          const Text(
            'Vertical SaaS continues to outperform in workflow-heavy domains.',
          ),
        ],
      ),
    );
  }
}

class _MiniTool extends StatelessWidget {
  const _MiniTool({required this.label});

  final String label;

  /// Builds a compact editor control.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip();

  /// Builds the bottom day timeline.
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      padding: const EdgeInsets.fromLTRB(34, 22, 34, 24),
      decoration: const BoxDecoration(
        color: AuroraColors.surface,
        border: Border(top: BorderSide(color: AuroraColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 820,
          child: Row(
            children: <Widget>[
              const SizedBox(width: 130, child: _DaySummary()),
              Expanded(
                child: Column(
                  children: <Widget>[
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('8 AM'),
                        Text('9 AM'),
                        Text('10 AM'),
                        Text('11 AM'),
                        Text('12 PM'),
                        Text('1 PM'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          const _CalendarPill(label: 'Sprint Review\n8:30 AM'),
                          const Spacer(),
                          const _CalendarPill(
                            label: 'Investor Meeting\n10:00 AM',
                            accent: true,
                          ),
                          const Spacer(flex: 2),
                          const _CalendarPill(label: 'Strategy Sync\n1:00 PM'),
                          const Spacer(),
                        ],
                      ),
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

class _DaySummary extends StatelessWidget {
  const _DaySummary();

  /// Builds a date summary that scales within the fixed day strip height.
  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 130,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Eyebrow('YOUR DAY', color: AuroraColors.muted),
              SizedBox(height: 6),
              Text(
                'May 20',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 32),
              ),
              Text(
                'Tuesday',
                style: TextStyle(color: AuroraColors.muted, letterSpacing: 1.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarPill extends StatelessWidget {
  const _CalendarPill({required this.label, this.accent = false});

  final String label;
  final bool accent;

  /// Builds a compact calendar block.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent ? AuroraColors.coral : AuroraColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: accent ? null : Border.all(color: AuroraColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent ? Colors.white : AuroraColors.ink,
          fontWeight: accent ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _WorkspaceCenter extends StatelessWidget {
  const _WorkspaceCenter({required this.controller, required this.onBackHome});

  final AuroraAppController controller;
  final VoidCallback onBackHome;

  /// Builds the center panel for the focused project workspace.
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(38, 32, 38, 44),
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
              const Spacer(),
              OutlinedButton(
                onPressed: controller.createChat,
                child: const Text('New chat'),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz),
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
          const SizedBox(height: 28),
          const _WorkspaceTabs(),
          const SizedBox(height: 26),
          for (final message in controller.messages) _ChatRow(message: message),
          _ResearchPlanCard(controller: controller),
          const SizedBox(height: 22),
          const _DraftCard(title: 'SaaS Market Trends 2025'),
        ],
      ),
    );
  }
}

class _WorkspaceTabs extends StatelessWidget {
  const _WorkspaceTabs();

  /// Builds project tabs.
  @override
  Widget build(BuildContext context) {
    const tabs = <String>['Chat', 'Draft', 'Plan', 'Sources (6)', 'Files'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AuroraColors.border)),
      ),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < tabs.length; index++)
            Padding(
              padding: const EdgeInsets.only(right: 30),
              child: Container(
                padding: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: index == 0
                      ? const Border(
                          bottom: BorderSide(
                            color: AuroraColors.green,
                            width: 2,
                          ),
                        )
                      : null,
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    fontWeight: index == 0 ? FontWeight.w900 : FontWeight.w500,
                    color: index == 0 ? AuroraColors.green : AuroraColors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResearchPlanCard extends StatelessWidget {
  const _ResearchPlanCard({required this.controller});

  final AuroraAppController controller;

  /// Builds the workspace task card with confirmable actions.
  @override
  Widget build(BuildContext context) {
    final done = controller.workspace.tasks.where((task) => task.done).length;
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
              const Text(
                'Research Plan',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const Spacer(),
              Text(
                'In progress - $done/${controller.workspace.tasks.length}',
                style: const TextStyle(color: AuroraColors.muted),
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
          for (final task in controller.workspace.tasks)
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

class _MemoryContextPanel extends StatelessWidget {
  const _MemoryContextPanel({required this.workspace});

  final ProjectWorkspace workspace;

  /// Builds the memory and context side panel.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 390,
      padding: const EdgeInsets.fromLTRB(32, 34, 32, 44),
      decoration: const BoxDecoration(
        color: AuroraColors.surface,
        border: Border(left: BorderSide(color: AuroraColors.border)),
      ),
      child: SingleChildScrollView(
        child: _MemoryContextContent(workspace: workspace),
      ),
    );
  }
}

class _MemoryContextContent extends StatelessWidget {
  const _MemoryContextContent({required this.workspace});

  final ProjectWorkspace workspace;

  /// Builds memory context panel contents.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            _Eyebrow('MEMORY & CONTEXT', color: AuroraColors.muted),
            Spacer(),
            Icon(Icons.more_horiz, color: AuroraColors.muted),
          ],
        ),
        const SizedBox(height: 28),
        const Row(
          children: <Widget>[
            Text(
              'Knowledge Map',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AuroraColors.green,
              ),
            ),
            SizedBox(width: 30),
            Text('Preferences', style: TextStyle(color: AuroraColors.muted)),
          ],
        ),
        const SizedBox(height: 28),
        const _KnowledgeMap(),
        const SizedBox(height: 28),
        const _Eyebrow('TASKS', color: AuroraColors.muted),
        const SizedBox(height: 14),
        for (final task in workspace.tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: _TaskLine(task: task),
          ),
        const SizedBox(height: 28),
        const _Eyebrow('ACTIONS', color: AuroraColors.muted),
        const SizedBox(height: 14),
        for (final action in <String>[
          'Add file or link',
          'Save to project',
          'Share',
          'Export brief',
        ])
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.description_outlined),
            label: Text(action),
          ),
      ],
    );
  }
}

class _KnowledgeMap extends StatelessWidget {
  const _KnowledgeMap();

  /// Builds the radial memory map.
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            height: 210,
            width: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xffc6bfae)),
            ),
          ),
          const _MemoryNode(label: 'SaaS\nTrends\n2025', center: true),
          const Positioned(
            top: 5,
            child: _MemoryNode(label: 'Market\nReports'),
          ),
          const Positioned(
            right: 14,
            top: 88,
            child: _MemoryNode(label: 'Industry\nSignals'),
          ),
          const Positioned(
            right: 38,
            bottom: 10,
            child: _MemoryNode(label: 'Customer\nInterviews'),
          ),
          const Positioned(
            left: 12,
            bottom: 28,
            child: _MemoryNode(label: 'Competitor\nUpdates'),
          ),
          const Positioned(
            left: 8,
            top: 76,
            child: _MemoryNode(label: 'Expert\nInsights'),
          ),
        ],
      ),
    );
  }
}

class _MemoryNode extends StatelessWidget {
  const _MemoryNode({required this.label, this.center = false});

  final String label;
  final bool center;

  /// Builds one node in the memory map.
  @override
  Widget build(BuildContext context) {
    return Container(
      height: center ? 96 : 86,
      width: center ? 96 : 86,
      decoration: BoxDecoration(
        color: center ? AuroraColors.green : AuroraColors.panel,
        shape: BoxShape.circle,
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x11453421), blurRadius: 10),
        ],
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: center ? Colors.white : AuroraColors.ink,
            fontWeight: FontWeight.w900,
            height: 1.2,
            fontSize: center ? 16 : 12,
          ),
        ),
      ),
    );
  }
}

class _MemoryPage extends StatelessWidget {
  const _MemoryPage({required this.workspace});

  final ProjectWorkspace workspace;

  /// Builds the full memory route.
  @override
  Widget build(BuildContext context) {
    return _PaddedRoute(
      title: 'Memory',
      subtitle: 'Durable context Aurora can use across chats.',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: workspace.memoryRecords.map((record) {
          return _InfoCard(
            title: record.title,
            detail: record.summary,
            footer: '${record.kind} - ${record.sourceLabel}',
          );
        }).toList(),
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
    return _PaddedRoute(
      title: 'Files',
      subtitle:
          'Source material and generated artifacts for the active workspace.',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: workspace.sources.map((source) {
          return _InfoCard(
            title: source.title,
            detail: source.detail,
            footer: source.id,
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.statuses, required this.statusMessage});

  final List<EndpointStatus> statuses;
  final String statusMessage;

  /// Builds the settings and connection route.
  @override
  Widget build(BuildContext context) {
    return _PaddedRoute(
      title: 'Settings',
      subtitle: statusMessage,
      child: Column(
        children: statuses
            .map((status) => _EndpointRow(status: status))
            .toList(),
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({required this.status});

  final EndpointStatus status;

  /// Builds one service connection row.
  @override
  Widget build(BuildContext context) {
    final color = switch (status.state) {
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 14),
          SizedBox(
            width: 120,
            child: Text(
              status.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(child: Text(status.url, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              status.message,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AuroraColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.detail,
    required this.footer,
  });

  final String title;
  final String detail;
  final String footer;

  /// Builds a reusable information card.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xfffffcf8),
        border: Border.all(color: AuroraColors.border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text(detail, style: const TextStyle(color: AuroraColors.muted)),
          const SizedBox(height: 18),
          Text(
            footer,
            style: const TextStyle(fontSize: 12, color: AuroraColors.green),
          ),
        ],
      ),
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

class _EmptyRoute extends StatelessWidget {
  const _EmptyRoute({required this.title});

  final String title;

  /// Builds a concise empty state route.
  @override
  Widget build(BuildContext context) {
    return _PaddedRoute(
      title: title,
      subtitle: 'This area is ready for the next connected surface.',
      child: const _InfoCard(
        title: 'Coming next',
        detail: 'Aurora will use the same connected workspace patterns here.',
        footer: 'v1 scope placeholder',
      ),
    );
  }
}

Future<void> _confirmCreateTask(
  BuildContext context,
  AuroraAppController controller,
) async {
  final input = TextEditingController(text: 'Follow up on SaaS benchmark data');
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
