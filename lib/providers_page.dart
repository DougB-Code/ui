part of 'main.dart';

class _ProvidersPage extends StatefulWidget {
  const _ProvidersPage({
    required this.providerApi,
    required this.providerCatalogAvailable,
  });

  final ProviderCatalogApi providerApi;
  final bool providerCatalogAvailable;

  @override
  State<_ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<_ProvidersPage> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _configPath = '';
  List<ProviderConfig> _providers = <ProviderConfig>[];
  ProviderConfig _draft = ProviderConfig.empty();
  bool _isNew = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
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
  }

  void _startNewProvider() {
    setState(() {
      _draft = ProviderConfig.empty();
      _isNew = true;
    });
  }

  Future<void> _saveProvider() async {
    if (_draft.alias.trim().isEmpty) {
      _showMessage('Provider alias is required.');
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
    if (_isNew || _draft.alias.trim().isEmpty) {
      _showMessage('Save the provider before verification.');
      return;
    }
    setState(() => _busy = true);
    try {
      final report = await widget.providerApi.verifyProvider(_draft.alias);
      setState(() {
        _draft.verificationSummary = report.summary;
      });
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
    copy.models = copy.models
        .where((ProviderModelConfig model) => model.name.trim().isNotEmpty)
        .toList();
    return copy;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.providerCatalogAvailable) {
      return const _InfoPanel(
        title: 'Provider catalog unavailable',
        body:
            'This deployment mode disables local harness provider catalog management routes. Switch to local mode to manage providers.',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: () => _loadProviders());
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 1150;
        final listPane = _Panel(
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
              ? const _EmptyState(
                  title: 'No providers configured',
                  body:
                      'Create a provider here to manage the harness provider catalog through the control plane.',
                )
              : ListView.separated(
                  itemCount: _providers.length,
                  separatorBuilder: (_, _) => const Divider(color: _border),
                  itemBuilder: (BuildContext context, int index) {
                    final provider = _providers[index];
                    final selected =
                        !_isNew && provider.alias == _draft.persistedAlias;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(provider.alias),
                      subtitle: Text(
                        provider.adapter.isEmpty
                            ? 'adapter not set'
                            : provider.adapter,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (provider.isDefault)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: _StatusPill(
                                label: 'default',
                                color: _info,
                              ),
                            ),
                          _StatusPill(
                            label: provider.enabled ? 'enabled' : 'disabled',
                            color: provider.enabled ? _success : _warning,
                          ),
                          if (selected)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.check_circle, color: _accent),
                            ),
                        ],
                      ),
                      onTap: () => _selectProvider(provider),
                    );
                  },
                ),
        );

        final editorPane = _ProviderEditorPane(
          draft: _draft,
          isNew: _isNew,
          busy: _busy,
          configPath: _configPath,
          onChanged: () => setState(() {}),
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
    required this.configPath,
    required this.onChanged,
    required this.onSave,
    required this.onVerify,
    required this.onDelete,
  });

  final ProviderConfig draft;
  final bool isNew;
  final bool busy;
  final String configPath;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;
  final Future<void> Function() onVerify;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return _Panel(
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
          OutlinedButton(
            onPressed: busy || isNew ? null : onVerify,
            child: const Text('Verify'),
          ),
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
              child: _InfoPanel(title: 'Catalog path', body: configPath),
            ),
          _SubsectionTitle('General'),
          const SizedBox(height: 8),
          _FieldLabel('Alias'),
          TextFormField(
            initialValue: draft.alias,
            key: ValueKey<String>(
              'provider-alias-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.alias = value,
          ),
          const SizedBox(height: 12),
          _FieldLabel('Adapter'),
          TextFormField(
            initialValue: draft.adapter,
            key: ValueKey<String>(
              'provider-adapter-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.adapter = value,
          ),
          const SizedBox(height: 12),
          _FieldLabel('Base URL'),
          TextFormField(
            initialValue: draft.endpoint,
            key: ValueKey<String>(
              'provider-url-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.endpoint = value,
          ),
          const SizedBox(height: 12),
          _FieldLabel('API key environment variable'),
          TextFormField(
            initialValue: draft.apiKeyEnv,
            key: ValueKey<String>(
              'provider-key-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.apiKeyEnv = value,
          ),
          const SizedBox(height: 12),
          _FieldLabel('Allowed hosts (comma separated)'),
          TextFormField(
            initialValue: draft.allowedHosts.join(', '),
            key: ValueKey<String>(
              'provider-hosts-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) {
              draft.allowedHosts = value
                  .split(',')
                  .map((String host) => host.trim())
                  .where((String host) => host.isNotEmpty)
                  .toList();
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: draft.enabled,
            onChanged: (bool value) {
              draft.enabled = value;
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
              onChanged();
            },
            title: const Text('Default provider'),
            subtitle: const Text('Mark this provider as the catalog default.'),
          ),
          SwitchListTile(
            value: draft.local,
            onChanged: (bool value) {
              draft.local = value;
              onChanged();
            },
            title: const Text('Local endpoint'),
            subtitle: const Text('Allow loopback or local provider access.'),
          ),
          SwitchListTile(
            value: draft.accessVerified,
            onChanged: (bool value) {
              draft.accessVerified = value;
              onChanged();
            },
            title: const Text('Access verified'),
            subtitle: const Text('Persist provider-level verification state.'),
          ),
          const SizedBox(height: 12),
          _FieldLabel('Timeout seconds'),
          TextFormField(
            initialValue: draft.timeoutSecs == 0 ? '' : '${draft.timeoutSecs}',
            key: ValueKey<String>(
              'provider-timeout-${draft.persistedAlias}-${isNew.toString()}',
            ),
            keyboardType: TextInputType.number,
            onChanged: (String value) {
              draft.timeoutSecs = int.tryParse(value.trim()) ?? 0;
            },
          ),
          const SizedBox(height: 12),
          _FieldLabel('API version'),
          TextFormField(
            initialValue: draft.apiVersion,
            key: ValueKey<String>(
              'provider-version-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.apiVersion = value,
          ),
          const SizedBox(height: 12),
          _FieldLabel('Account ID'),
          TextFormField(
            initialValue: draft.accountId,
            key: ValueKey<String>(
              'provider-account-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.accountId = value,
          ),
          const SizedBox(height: 12),
          _FieldLabel('Gateway ID'),
          TextFormField(
            initialValue: draft.gatewayId,
            key: ValueKey<String>(
              'provider-gateway-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.gatewayId = value,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: _SubsectionTitle('Models')),
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
            const _InfoPanel(title: 'Models', body: 'No models configured yet.')
          else
            ...List<Widget>.generate(draft.models.length, (int index) {
              final model = draft.models[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _panelAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
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
                              onChanged: (String value) => model.name = value,
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
                      SwitchListTile(
                        value: model.accessVerified,
                        onChanged: (bool value) {
                          model.accessVerified = value;
                          onChanged();
                        },
                        title: const Text('Access verified'),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 18),
          _InfoPanel(title: 'Verification', body: draft.verificationSummary),
          const SizedBox(height: 18),
          _SubsectionTitle('YAML preview'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _panelAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: SelectableText(
              draft.alias.trim().isEmpty
                  ? 'Set an alias to preview YAML.'
                  : draft.toYamlSnippet(),
              style: const TextStyle(
                fontFamily: 'monospace',
                color: _textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
