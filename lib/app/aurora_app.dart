/// Builds the top-level Aurora Flutter application.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../ui/aurora_shell.dart';
import 'app_config.dart';
import 'app_controller.dart';
import 'theme.dart';

/// AuroraApp owns app lifetime, theme, and controller creation.
class AuroraApp extends StatefulWidget {
  /// Creates the Aurora app.
  const AuroraApp({super.key, required this.config});

  /// Runtime service configuration.
  final AppConfig config;

  @override
  State<AuroraApp> createState() => _AuroraAppState();
}

class _AuroraAppState extends State<AuroraApp> {
  late final AuroraAppController controller;
  late final _ExitObserver _exitObserver;
  ConfirmationRequest? _shownConfirmation;
  StreamSubscription<ProcessSignal>? _sigIntSubscription;
  StreamSubscription<ProcessSignal>? _sigTermSubscription;
  Future<void>? _closeFuture;

  /// Initializes the app controller.
  @override
  void initState() {
    super.initState();
    controller = AuroraAppController(config: widget.config);
    controller.addListener(_watchConfirmation);
    _exitObserver = _ExitObserver(onExit: _close);
    WidgetsBinding.instance.addObserver(_exitObserver);
    _sigIntSubscription = _watchSignal(ProcessSignal.sigint);
    if (!Platform.isWindows) {
      _sigTermSubscription = _watchSignal(ProcessSignal.sigterm);
    }
    unawaited(controller.initialize());
  }

  /// Cleans up the controller listener.
  @override
  void dispose() {
    unawaited(_sigIntSubscription?.cancel());
    unawaited(_sigTermSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(_exitObserver);
    unawaited(_close());
    super.dispose();
  }

  /// Builds the Material application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aurora',
      theme: buildAuroraTheme(),
      home: AuroraShell(controller: controller),
    );
  }

  void _watchConfirmation() {
    final confirmation = controller.pendingConfirmation;
    if (confirmation == null || identical(confirmation, _shownConfirmation)) {
      return;
    }
    _shownConfirmation = confirmation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Approve Tool Call'),
            content: Text(confirmation.hint),
            actions: confirmation.options.map((option) {
              return TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(controller.answerConfirmation(option));
                },
                child: Text(option.label),
              );
            }).toList(),
          );
        },
      ).then((_) {
        _shownConfirmation = null;
      });
    });
  }

  /// Registers one process-signal cleanup handler.
  StreamSubscription<ProcessSignal>? _watchSignal(ProcessSignal signal) {
    try {
      return signal.watch().listen((_) {
        unawaited(_handleProcessSignal(signal));
      });
    } on UnsupportedError {
      return null;
    }
  }

  /// Stops managed services before exiting from a terminal signal.
  Future<void> _handleProcessSignal(ProcessSignal signal) async {
    try {
      await _close();
    } finally {
      exit(signal == ProcessSignal.sigint ? 130 : 143);
    }
  }

  /// Closes controller-owned clients and local services once.
  Future<void> _close() {
    return _closeFuture ??= () async {
      controller.removeListener(_watchConfirmation);
      await controller.close();
    }();
  }
}

/// ExitObserver waits for async service shutdown before window close exits.
class _ExitObserver extends WidgetsBindingObserver {
  /// Creates an app-exit observer.
  _ExitObserver({required this.onExit});

  /// Cleanup callback invoked before the platform exits.
  final Future<void> Function() onExit;

  /// Handles desktop app-exit requests.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await onExit();
    return AppExitResponse.exit;
  }
}
