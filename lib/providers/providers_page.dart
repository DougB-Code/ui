import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ui/providers/provider_catalog_api.dart';
import 'package:ui/shared/ui.dart';

class ProvidersPage extends StatefulWidget {
  const ProvidersPage({
    super.key,
    required this.providerApi,
    required this.providerCatalogAvailable,
  });

  final ProviderCatalogApi providerApi;
  final bool providerCatalogAvailable;

  @override
  State<ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<ProvidersPage> {
  static const List<String> _supportedAdapters = <String>[
    'anthropic',
    'cloudflare',
    'google',
    'huggingface',
    'openai',
    'openai_compatible',
    'xai',
  ];

  bool _loading = true;
  bool _busy = false;
  bool _previewLoading = false;
  String? _error;
  String? _previewError;
  String _configPath = '';
  String _yamlPreview = '';
  List<ProviderConfig> _providers = <ProviderConfig>[];
  ProviderConfig _draft = ProviderConfig.empty();
  bool _isNew = true;
  Timer? _previewDebounce;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadProviders({String? selectAlias}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await widget.providerApi.listProviders();
      final providers = catalog.providers;
      ProviderConfig draft = ProviderConfig.empty();
      var isNew = true;
      if (providers.isNotEmpty) {
        final selected = selectAlias == null
            ? providers.first
            : providers.firstWhere(
                (ProviderConfig provider) => provider.alias == selectAlias,
                orElse: () => providers.first,
              );
        draft = selected.copy();
        isNew = false;
      }
      setState(() {
        _configPath = catalog.configPath;
        _providers = providers;
        _draft = draft;
        _isNew = isNew;
        _loading = false;
      });
      _schedulePreview(immediate: true);
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _selectProvider(ProviderConfig provider) {
    setState(() {
      _draft = provider.copy();
      _isNew = false;
    });
    _schedulePreview(immediate: true);
  }

  void _startNewProvider() {
    setState(() {
      _draft = ProviderConfig.empty();
      _isNew = true;
    });
    _schedulePreview(immediate: true);
  }

  Future<void> _saveProvider() async {
    if (_draft.alias.trim().isEmpty) {
      _showMessage('Provider name is required.');
      return;
    }

    setState(() => _busy = true);
    try {
      final payload = _normalizedDraft();
      final result = _isNew
          ? await widget.providerApi.createProvider(payload)
          : await widget.providerApi.updateProvider(
              _draft.persistedAlias,
              payload,
            );
      await _loadProviders(selectAlias: result.provider.alias);
      _showMessage(_isNew ? 'Provider created.' : 'Provider settings saved.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _verifyProvider() async {
    if (_isNew || _draft.persistedAlias.trim().isEmpty) {
      _showMessage('Save the provider before verification.');
      return;
    }
    setState(() => _busy = true);
    try {
      final alias = _draft.persistedAlias;
      final report = await widget.providerApi.verifyProvider(alias);
      await _loadProviders(selectAlias: alias);
      if (mounted) {
        setState(() {
          _draft.verificationSummary = report.summary;
        });
      }
      _showMessage(report.summary);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteProvider() async {
    if (_isNew || _draft.persistedAlias.trim().isEmpty) {
      _showMessage('Nothing to delete.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.providerApi.deleteProvider(_draft.persistedAlias);
      await _loadProviders();
      _showMessage('Provider deleted.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  ProviderConfig _normalizedDraft() {
    final copy = _draft.copy();
    if (copy.isDefault) {
      copy.enabled = true;
    }
    copy.models = copy.models
        .where((ProviderModelConfig model) => model.name.trim().isNotEmpty)
        .toList();
    return copy;
  }

  void _onDraftChanged() {
    setState(() {});
    _schedulePreview();
  }

  void _schedulePreview({bool immediate = false}) {
    _previewDebounce?.cancel();
    if (_draft.alias.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _previewLoading = false;
          _previewError = null;
          _yamlPreview = '';
        });
      }
      return;
    }

    if (immediate) {
      _refreshPreview();
      return;
    }
    _previewDebounce = Timer(
      const Duration(milliseconds: 300),
      _refreshPreview,
    );
  }

  Future<void> _refreshPreview() async {
    final snapshot = _normalizedDraft();
    if (mounted) {
      setState(() {
        _previewLoading = true;
        _previewError = null;
      });
    }
    try {
      final preview = await widget.providerApi.previewProvider(snapshot);
      if (!mounted || _draft.alias.trim() != snapshot.alias.trim()) {
        return;
      }
      setState(() {
        _yamlPreview = preview.yamlPreview;
        _previewLoading = false;
      });
    } catch (error) {
      if (!mounted || _draft.alias.trim() != snapshot.alias.trim()) {
        return;
      }
      setState(() {
        _previewError = error.toString();
        _previewLoading = false;
      });
    }
  }

  void _showMessage(String message) {
    showAppMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.providerCatalogAvailable) {
      return const InfoPanel(
        title: 'Provider catalog unavailable',
        body:
            'This deployment mode disables local harness provider catalog management routes. Switch to local mode to manage providers.',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: () => _loadProviders());
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 1150;
        final listPane = PanelCard(
          title: 'Providers',
          fill: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _startNewProvider,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _busy ? null : () => _loadProviders(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
          child: _providers.isEmpty
              ? const EmptyState(
                  title: 'No providers configured',
                  body:
                      'Create a provider here to manage the harness provider catalog through the control plane.',
                )
              : ListView.separated(
                  itemCount: _providers.length,
                  separatorBuilder: (_, _) => const Divider(color: borderColor),
                  itemBuilder: (BuildContext context, int index) {
                    final provider = _providers[index];
                    final selected =
                        !_isNew && provider.alias == _draft.persistedAlias;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(provider.alias),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (provider.isDefault)
                                const StatusPill(
                                  label: 'default',
                                  color: infoColor,
                                ),
                              StatusPill(
                                label: provider.enabled
                                    ? 'enabled'
                                    : 'disabled',
                                color: provider.enabled
                                    ? successColor
                                    : warningColor,
                              ),
                              if (provider.accessVerified)
                                const StatusPill(
                                  label: 'verified',
                                  color: successColor,
                                ),
                            ],
                          ),
                        ],
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: accentColor)
                          : null,
                      onTap: () => _selectProvider(provider),
                    );
                  },
                ),
        );

        final editorPane = _ProviderEditorPane(
          draft: _draft,
          isNew: _isNew,
          busy: _busy,
          previewLoading: _previewLoading,
          previewError: _previewError,
          yamlPreview: _yamlPreview,
          supportedAdapters: _supportedAdapters,
          configPath: _configPath,
          onChanged: _onDraftChanged,
          onSave: _saveProvider,
          onVerify: _verifyProvider,
          onDelete: _deleteProvider,
        );

        if (stacked) {
          return Column(
            children: [
              SizedBox(height: 300, child: listPane),
              const SizedBox(height: 14),
              Expanded(child: editorPane),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 360, child: listPane),
            const SizedBox(width: 14),
            Expanded(child: editorPane),
          ],
        );
      },
    );
  }
}

class _ProviderEditorPane extends StatelessWidget {
  const _ProviderEditorPane({
    required this.draft,
    required this.isNew,
    required this.busy,
    required this.previewLoading,
    required this.previewError,
    required this.yamlPreview,
    required this.supportedAdapters,
    required this.configPath,
    required this.onChanged,
    required this.onSave,
    required this.onVerify,
    required this.onDelete,
  });

  final ProviderConfig draft;
  final bool isNew;
  final bool busy;
  final bool previewLoading;
  final String? previewError;
  final String yamlPreview;
  final List<String> supportedAdapters;
  final String configPath;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;
  final Future<void> Function() onVerify;
  final Future<void> Function() onDelete;

  Widget _verificationActionButton() {
    final verified = draft.accessVerified;
    final color = verified ? successColor : dangerColor;
    return FilledButton(
      onPressed: busy || isNew ? null : onVerify,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textPrimaryColor,
      ),
      child: Text(verified ? 'Verified' : 'Verify'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: isNew ? 'New provider' : 'Provider editor',
      fill: true,
      trailing: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton(
            onPressed: busy ? null : onSave,
            child: Text(isNew ? 'Create' : 'Save'),
          ),
          _verificationActionButton(),
          OutlinedButton(
            onPressed: busy || isNew ? null : onDelete,
            child: const Text('Delete'),
          ),
        ],
      ),
      child: ListView(
        children: [
          if (configPath.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InfoPanel(title: 'Catalog path', body: configPath),
            ),
          SubsectionTitle('General'),
          const SizedBox(height: 8),
          FieldLabel('Name'),
          TextFormField(
            initialValue: draft.alias,
            key: ValueKey<String>(
              'provider-alias-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) {
              draft.alias = value;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          FieldLabel('Adapter'),
          DropdownButtonFormField<String>(
            initialValue: supportedAdapters.contains(draft.adapter)
                ? draft.adapter
                : null,
            key: ValueKey<String>(
              'provider-adapter-${draft.persistedAlias}-${isNew.toString()}',
            ),
            items: supportedAdapters
                .map(
                  (String adapter) => DropdownMenuItem<String>(
                    value: adapter,
                    child: Text(adapter),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              draft.adapter = value ?? '';
              onChanged();
            },
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 12),
          FieldLabel('Base URL'),
          TextFormField(
            initialValue: draft.endpoint,
            key: ValueKey<String>(
              'provider-url-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) {
              draft.endpoint = value;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          FieldLabel('API key environment variable'),
          TextFormField(
            initialValue: draft.apiKeyEnv,
            key: ValueKey<String>(
              'provider-key-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) {
              draft.apiKeyEnv = value;
              onChanged();
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: draft.enabled,
            onChanged: (bool value) {
              draft.enabled = value;
              if (!value) {
                draft.isDefault = false;
              }
              onChanged();
            },
            title: const Text('Enabled'),
            subtitle: const Text(
              'Expose this provider to the harness catalog.',
            ),
          ),
          SwitchListTile(
            value: draft.isDefault,
            onChanged: (bool value) {
              draft.isDefault = value;
              if (value) {
                draft.enabled = true;
              }
              onChanged();
            },
            title: const Text('Default provider'),
            subtitle: const Text('Mark this provider as the catalog default.'),
          ),
          SwitchListTile(
            value: draft.secure,
            onChanged: (bool value) {
              draft.secure = value;
              onChanged();
            },
            title: const Text('Secure connection'),
            subtitle: const Text(
              'Require HTTPS. Disable only for local HTTP endpoints.',
            ),
          ),
          const SizedBox(height: 12),
          FieldLabel('Timeout seconds'),
          TextFormField(
            initialValue: draft.timeoutSecs == 0 ? '' : '${draft.timeoutSecs}',
            key: ValueKey<String>(
              'provider-timeout-${draft.persistedAlias}-${isNew.toString()}',
            ),
            keyboardType: TextInputType.number,
            onChanged: (String value) {
              draft.timeoutSecs = int.tryParse(value.trim()) ?? 0;
              onChanged();
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: SubsectionTitle('Models')),
              FilledButton.icon(
                onPressed: () {
                  draft.models.add(
                    ProviderModelConfig(
                      name: '',
                      enabled: false,
                      accessVerified: false,
                    ),
                  );
                  onChanged();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add model'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (draft.models.isEmpty)
            const InfoPanel(title: 'Models', body: 'No models configured yet.')
          else
            ...List<Widget>.generate(draft.models.length, (int index) {
              final model = draft.models[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: panelAltColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: model.name,
                              key: ValueKey<String>(
                                'provider-model-${draft.persistedAlias}-$index-${model.name}',
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Model name',
                              ),
                              onChanged: (String value) {
                                model.name = value;
                                onChanged();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () {
                              draft.models.removeAt(index);
                              onChanged();
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        value: model.enabled,
                        onChanged: (bool value) {
                          model.enabled = value;
                          onChanged();
                        },
                        title: const Text('Enabled'),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 18),
          if (previewError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InfoPanel(
                title: 'Preview error',
                body: previewError!,
                tone: dangerColor,
              ),
            ),
          SubsectionTitle('YAML preview'),
          const SizedBox(height: 8),
          SelectionArea(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: panelAltColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                draft.alias.trim().isEmpty
                    ? 'Set a name to preview YAML.'
                    : previewLoading
                    ? 'Refreshing preview...'
                    : yamlPreview.trim().isEmpty
                    ? 'Preview unavailable.'
                    : yamlPreview,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: textPrimaryColor,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
