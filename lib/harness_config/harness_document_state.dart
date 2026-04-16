import 'package:flutter/material.dart';
import 'package:ui/harness_config/harness_config_api.dart';
import 'package:ui/shared/ui.dart';

abstract class HarnessDocumentPageState<T extends StatefulWidget, TCatalog>
    extends State<T> {
  final TextEditingController controller = TextEditingController();

  bool loading = true;
  bool busy = false;
  String? error;
  TCatalog? catalog;
  HarnessConfigValidationReport? validation;

  String get emptyTitle;
  String get emptyBody;
  String get savedMessage;
  ScreenHeaderActionsController? get headerActionsController => null;
  bool get headerActionsEnabled => true;

  Future<TCatalog> fetchCatalog();
  Future<TCatalog> saveCatalog(String yaml);
  Future<HarnessConfigValidationReport> validateCatalog(String yaml);
  String catalogYaml(TCatalog catalog);

  String _headerActionsSignature = '';

  @override
  void initState() {
    super.initState();
    loadDocument();
  }

  @override
  void dispose() {
    controller.dispose();
    headerActionsController?.clear();
    super.dispose();
  }

  @protected
  void onCatalogLoaded(TCatalog loadedCatalog) {}

  @protected
  void onCatalogSaved(TCatalog savedCatalog) {}

  @protected
  Future<void> loadDocument() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loadedCatalog = await fetchCatalog();
      controller.text = catalogYaml(loadedCatalog);
      onCatalogLoaded(loadedCatalog);
      setState(() {
        catalog = loadedCatalog;
        validation = null;
        loading = false;
      });
    } catch (loadError) {
      setState(() {
        error = loadError.toString();
        loading = false;
      });
    }
  }

  @protected
  Future<void> validateDocument() async {
    setState(() => busy = true);
    try {
      final report = await validateCatalog(controller.text);
      if (!mounted) {
        return;
      }
      setState(() => validation = report);
      showAppMessage(context, report.summary);
    } catch (validationError) {
      if (!mounted) {
        return;
      }
      showAppMessage(context, validationError.toString());
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @protected
  Future<void> saveDocumentState() async {
    setState(() => busy = true);
    try {
      final savedCatalog = await saveCatalog(controller.text);
      if (!mounted) {
        return;
      }
      controller.text = catalogYaml(savedCatalog);
      onCatalogSaved(savedCatalog);
      setState(() {
        catalog = savedCatalog;
        validation = null;
      });
      showAppMessage(context, savedMessage);
    } catch (saveError) {
      if (!mounted) {
        return;
      }
      showAppMessage(context, saveError.toString());
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void _syncHeaderActions() {
    final controller = headerActionsController;
    if (controller == null) {
      return;
    }
    final signature = <Object>[
      headerActionsEnabled,
      loading,
      busy,
      error != null,
      catalog != null,
    ].join('|');
    if (signature == _headerActionsSignature) {
      return;
    }
    _headerActionsSignature = signature;
    final actions = !headerActionsEnabled
        ? const <Widget>[]
        : <Widget>[
            OutlinedButton.icon(
              key: const ValueKey<String>('harness-header-reload'),
              onPressed: busy || loading ? null : loadDocument,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reload'),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('harness-header-validate'),
              onPressed: busy || loading ? null : validateDocument,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Validate'),
            ),
            FilledButton.icon(
              key: const ValueKey<String>('harness-header-save'),
              onPressed: busy || loading ? null : saveDocumentState,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      controller.setActions(actions);
    });
  }

  @protected
  Widget buildDocumentUnavailable({
    required bool available,
    required String unavailableTitle,
    required String unavailableBody,
    required Widget Function(TCatalog catalog) builder,
  }) {
    _syncHeaderActions();
    if (!available) {
      return InfoPanel(title: unavailableTitle, body: unavailableBody);
    }
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return ErrorState(message: error!, onRetry: loadDocument);
    }
    final currentCatalog = catalog;
    if (currentCatalog == null) {
      return EmptyState(title: emptyTitle, body: emptyBody);
    }
    return builder(currentCatalog);
  }
}
