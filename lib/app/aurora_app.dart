/// Builds the top-level Aurora Flutter application.
library;

import 'dart:async';

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
  ConfirmationRequest? _shownConfirmation;

  /// Initializes the app controller.
  @override
  void initState() {
    super.initState();
    controller = AuroraAppController(config: widget.config);
    controller.addListener(_watchConfirmation);
    unawaited(controller.initialize());
  }

  /// Cleans up the controller listener.
  @override
  void dispose() {
    controller.removeListener(_watchConfirmation);
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
}
