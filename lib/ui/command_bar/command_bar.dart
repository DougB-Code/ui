/// Provides the global command bar and quick-access menu for Aurora.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/theme.dart';
import 'quick_access_menu.dart';

/// CommandBar renders the app-wide chat command field and shortcut actions.
class CommandBar extends StatefulWidget {
  /// Creates a command bar bound to the app shell and controller.
  const CommandBar({
    super.key,
    required this.commandController,
    required this.appController,
    required this.onSubmit,
    required this.onNewChat,
    required this.onStartChatWithProfile,
    required this.onSelectCatalogChat,
    required this.onOpenSection,
    required this.onOpenSettingsSection,
    required this.onOpenSettings,
  });

  /// Text controller for the global command input.
  final TextEditingController commandController;

  /// App state used to populate quick-access shortcuts.
  final AuroraAppController appController;

  /// Sends the current command input into a new chat.
  final Future<void> Function({String profilePath}) onSubmit;

  /// Starts a blank default-profile chat.
  final VoidCallback onNewChat;

  /// Starts a blank chat with a chosen runtime profile.
  final ValueChanged<String> onStartChatWithProfile;

  /// Opens an existing catalog chat.
  final ValueChanged<String> onSelectCatalogChat;

  /// Opens a top-level workspace section.
  final ValueChanged<String> onOpenSection;

  /// Opens a specific settings section.
  final ValueChanged<String> onOpenSettingsSection;

  /// Opens the settings workspace.
  final VoidCallback onOpenSettings;

  @override
  State<CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends State<CommandBar> {
  static const double _height = 118;

  final FocusNode _focusNode = FocusNode();
  final GlobalKey _fieldKey = GlobalKey();
  final LayerLink _fieldLink = LayerLink();
  OverlayEntry? _quickAccessEntry;
  String _profilePathForNextChat = '';

  /// Cleans up quick-access overlay and text focus resources.
  @override
  void dispose() {
    _removeQuickAccess();
    _focusNode.dispose();
    super.dispose();
  }

  /// Refreshes quick-access content when controller state changes upstream.
  @override
  void didUpdateWidget(covariant CommandBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _quickAccessEntry?.markNeedsBuild();
  }

  /// Builds the global command bar.
  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
      decoration: const BoxDecoration(
        color: AuroraColors.surface,
        border: Border(bottom: BorderSide(color: AuroraColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: CompositedTransformTarget(
              link: _fieldLink,
              child: GestureDetector(
                key: _fieldKey,
                behavior: HitTestBehavior.opaque,
                onTap: _showQuickAccessIfIdle,
                child: _CommandInputFrame(
                  controller: widget.commandController,
                  focusNode: _focusNode,
                  onTap: _showQuickAccessIfIdle,
                  onChanged: _handleCommandTextChanged,
                  onSubmit: () => unawaited(_handleSubmit()),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _CommandIconButton(
            icon: Icons.add,
            tooltip: 'New chat',
            onTap: _handleNewChat,
          ),
          const SizedBox(width: 12),
          _CommandIconButton(
            icon: Icons.tune,
            tooltip: 'Settings',
            onTap: _handleOpenSettings,
          ),
        ],
      ),
    );
  }

  /// Starts a chat from the global input and closes transient navigation.
  Future<void> _handleSubmit() async {
    _removeQuickAccess();
    final profilePath = _consumeProfilePathForNextChat();
    await widget.onSubmit(profilePath: profilePath);
  }

  /// Starts an empty chat from the global bar.
  void _handleNewChat() {
    _removeQuickAccess();
    final profilePath = _consumeProfilePathForNextChat();
    if (profilePath.isEmpty) {
      widget.onNewChat();
      return;
    }
    widget.onStartChatWithProfile(profilePath);
  }

  /// Opens settings from the global bar.
  void _handleOpenSettings() {
    _clearProfilePathForNextChat();
    _removeQuickAccess();
    widget.onOpenSettings();
  }

  /// Opens quick access while the command input is not carrying a message.
  void _showQuickAccessIfIdle() {
    if (widget.commandController.text.trim().isEmpty) {
      _showQuickAccess();
    }
  }

  /// Hides quick access once the user starts composing a new chat message.
  void _handleCommandTextChanged(String value) {
    if (value.trim().isEmpty) {
      _showQuickAccess();
    } else {
      _removeQuickAccess();
    }
  }

  /// Inserts the quick-access dropdown under the global command field.
  void _showQuickAccess() {
    if (_quickAccessEntry != null) {
      _quickAccessEntry?.markNeedsBuild();
      return;
    }
    _quickAccessEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              top: _height,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeQuickAccess,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _fieldLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 76),
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  width: _quickAccessWidth(),
                  child: QuickAccessMenu(
                    groups: _quickAccessGroups(),
                    onViewSettings: () {
                      _clearProfilePathForNextChat();
                      _removeQuickAccess();
                      widget.onOpenSettings();
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_quickAccessEntry!);
  }

  /// Removes the quick-access dropdown if it is visible.
  void _removeQuickAccess() {
    _quickAccessEntry?.remove();
    _quickAccessEntry = null;
  }

  /// Returns the dropdown width matched to the command field.
  double _quickAccessWidth() {
    final renderObject = _fieldKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size.width;
    }
    return 720;
  }

  /// Builds grouped quick-access actions from live app state.
  List<QuickAccessGroup> _quickAccessGroups() {
    return <QuickAccessGroup>[
      QuickAccessGroup(
        title: 'Profiles',
        icon: Icons.manage_accounts_outlined,
        emptyLabel: 'No profiles configured',
        actions: _profileActions(),
      ),
      QuickAccessGroup(
        title: 'Recent chats',
        icon: Icons.chat_bubble_outline,
        emptyLabel: 'No recent chats',
        actions: _chatActions(),
      ),
      QuickAccessGroup(
        title: 'Workspaces',
        icon: Icons.dashboard_customize_outlined,
        emptyLabel: '',
        actions: _workspaceActions(),
      ),
      QuickAccessGroup(
        title: 'Settings',
        icon: Icons.tune,
        emptyLabel: '',
        actions: _settingsActions(),
      ),
    ];
  }

  /// Builds new-chat actions for configured runtime profiles.
  List<QuickAccessAction> _profileActions() {
    final profiles = _profileEntries();
    return <QuickAccessAction>[
      for (final profile in profiles)
        QuickAccessAction(
          label: profile.label,
          detail: _profileDetail(profile),
          icon: profile.path == _profilePathForNextChat || profile.active
              ? Icons.check_circle_outline
              : Icons.person_outline,
          onTap: () => _selectProfileForNextChat(profile.path),
        ),
    ];
  }

  /// Selects a profile for the next top-bar chat without closing quick access.
  void _selectProfileForNextChat(String profilePath) {
    setState(() {
      _profilePathForNextChat = profilePath;
    });
    _quickAccessEntry?.markNeedsBuild();
    _focusCommandInput();
  }

  /// Focuses the global chat input after selecting a profile.
  void _focusCommandInput() {
    if (!mounted) {
      return;
    }
    FocusScope.of(context).requestFocus(_focusNode);
  }

  /// Returns and clears the selected profile for the next top-bar chat.
  String _consumeProfilePathForNextChat() {
    final profilePath = _profilePathForNextChat;
    _clearProfilePathForNextChat();
    return profilePath;
  }

  /// Clears a staged profile when the next action is not a new chat.
  void _clearProfilePathForNextChat() {
    if (_profilePathForNextChat.isNotEmpty && mounted) {
      setState(() {
        _profilePathForNextChat = '';
      });
    }
  }

  /// Returns profile choices, including the loaded profile when needed.
  List<RuntimeProfileFileEntry> _profileEntries() {
    if (widget.appController.availableProfiles.isNotEmpty) {
      return widget.appController.availableProfiles;
    }
    final profile = widget.appController.runtimeProfile;
    if (profile == null || widget.appController.runtimeProfilePath.isEmpty) {
      return const <RuntimeProfileFileEntry>[];
    }
    return <RuntimeProfileFileEntry>[
      RuntimeProfileFileEntry(
        path: widget.appController.runtimeProfilePath,
        id: profile.id,
        label: profile.label,
        active: true,
      ),
    ];
  }

  /// Labels profile rows with default and active state.
  String _profileDetail(RuntimeProfileFileEntry profile) {
    if (profile.path == _profilePathForNextChat) {
      return 'Selected for new chat';
    }
    if (profile.path == widget.appController.defaultChatProfilePath) {
      return 'Default profile';
    }
    if (profile.active) {
      return 'Active profile';
    }
    return profile.id;
  }

  /// Builds recent chat actions from the app catalog or active sessions.
  List<QuickAccessAction> _chatActions() {
    if (widget.appController.chatCatalog.isNotEmpty) {
      return <QuickAccessAction>[
        for (final chat in widget.appController.chatCatalog.take(4))
          QuickAccessAction(
            label: chat.title,
            detail:
                '${chat.profileLabel} • ${_commandBarTimestamp(chat.updatedAt)}',
            icon: chat.key == widget.appController.selectedChatKey
                ? Icons.check_circle_outline
                : Icons.chat_bubble_outline,
            onTap: () {
              _clearProfilePathForNextChat();
              _removeQuickAccess();
              widget.onSelectCatalogChat(chat.key);
            },
          ),
      ];
    }
    if (widget.appController.runtimeProfilePath.isEmpty) {
      return const <QuickAccessAction>[];
    }
    return <QuickAccessAction>[
      for (final session in widget.appController.sessions.take(4))
        QuickAccessAction(
          label: session.title,
          detail: _commandBarTimestamp(session.updatedAt),
          icon: session.id == widget.appController.selectedSessionId
              ? Icons.check_circle_outline
              : Icons.chat_bubble_outline,
          onTap: () {
            _clearProfilePathForNextChat();
            _removeQuickAccess();
            widget.onSelectCatalogChat(
              '${widget.appController.runtimeProfilePath}::${session.id}',
            );
          },
        ),
    ];
  }

  /// Builds quick workspace navigation actions.
  List<QuickAccessAction> _workspaceActions() {
    return <QuickAccessAction>[
      _workspaceAction('Chat', Icons.forum_outlined),
      _workspaceAction('Tasks', Icons.task_alt_outlined),
      _workspaceAction('Memory', Icons.chat_bubble_outline),
      _workspaceAction('Workflows', Icons.radio_button_unchecked),
    ];
  }

  /// Builds one workspace navigation action.
  QuickAccessAction _workspaceAction(String section, IconData icon) {
    return QuickAccessAction(
      label: section,
      detail: '',
      icon: icon,
      onTap: () {
        _clearProfilePathForNextChat();
        _removeQuickAccess();
        widget.onOpenSection(section);
      },
    );
  }

  /// Builds app settings navigation actions.
  List<QuickAccessAction> _settingsActions() {
    return <QuickAccessAction>[
      _settingsAction('App', Icons.app_settings_alt_outlined),
      _settingsAction('Profiles', Icons.manage_accounts_outlined),
      _settingsAction('Models', Icons.memory_outlined),
      _settingsAction('Tools', Icons.extension_outlined),
    ];
  }

  /// Builds one settings navigation action.
  QuickAccessAction _settingsAction(String section, IconData icon) {
    return QuickAccessAction(
      label: section,
      detail: '',
      icon: icon,
      onTap: () {
        _clearProfilePathForNextChat();
        _removeQuickAccess();
        widget.onOpenSettingsSection(section);
      },
    );
  }
}

class _CommandInputFrame extends StatelessWidget {
  const _CommandInputFrame({
    required this.controller,
    required this.focusNode,
    required this.onTap,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  /// Builds the framed command input field.
  @override
  Widget build(BuildContext context) {
    return Container(
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
              key: const ValueKey<String>('global-command-input'),
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Start a new chat or give Aurora a command...',
              ),
              onTap: onTap,
              onChanged: onChanged,
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
            tooltip: 'Start chat',
          ),
        ],
      ),
    );
  }
}

class _CommandIconButton extends StatelessWidget {
  const _CommandIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Builds a framed command bar icon button.
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

/// Formats a chat timestamp for dense command bar rows.
String _commandBarTimestamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}
