import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ui/providers/provider_catalog_api.dart';
import 'package:ui/shared/ui.dart';

enum _ProviderStatusFilter { all, enabled, disabled }

enum _ProviderSortMode { name, adapter, status }

enum _ProviderDetailTab { general, connection, models, advanced }

enum _ProviderRowAction { verify, delete }

extension on _ProviderStatusFilter {
  String get label {
    return switch (this) {
      _ProviderStatusFilter.all => 'All',
      _ProviderStatusFilter.enabled => 'Enabled',
      _ProviderStatusFilter.disabled => 'Disabled',
    };
  }

  String toolbarLabel(int count) {
    return 'Status: $label ($count)';
  }
}

extension on _ProviderSortMode {
  String get label {
    return switch (this) {
      _ProviderSortMode.name => 'Sort: Name',
      _ProviderSortMode.adapter => 'Sort: Adapter',
      _ProviderSortMode.status => 'Sort: Status',
    };
  }
}

extension on _ProviderDetailTab {
  String get label {
    return switch (this) {
      _ProviderDetailTab.general => 'General',
      _ProviderDetailTab.connection => 'Connection',
      _ProviderDetailTab.models => 'Models',
      _ProviderDetailTab.advanced => 'Advanced',
    };
  }
}

class ProvidersPage extends StatefulWidget {
  const ProvidersPage({
    super.key,
    required this.providerApi,
    required this.providerCatalogAvailable,
    required this.headerActionsController,
  });

  final ProviderCatalogApi providerApi;
  final bool providerCatalogAvailable;
  final ScreenHeaderActionsController headerActionsController;

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
  bool _mobileDetailVisible = false;
  String? _error;
  String? _previewError;
  String _previewValidationStatus = '';
  String _previewValidationSummary = '';
  String _configPath = '';
  String _yamlPreview = '';
  List<ProviderConfig> _providers = <ProviderConfig>[];
  ProviderConfig _draft = ProviderConfig.empty();
  bool _isNew = true;
  Timer? _previewDebounce;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _adapterFilter = '';
  _ProviderStatusFilter _statusFilter = _ProviderStatusFilter.all;
  _ProviderSortMode _sortMode = _ProviderSortMode.name;
  _ProviderDetailTab _detailTab = _ProviderDetailTab.general;
  String _headerActionsSignature = '';

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _searchController.dispose();
    widget.headerActionsController.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProvidersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.headerActionsController != widget.headerActionsController) {
      oldWidget.headerActionsController.clear();
      _headerActionsSignature = '';
    }
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
      if (_adapterFilter.isNotEmpty &&
          !providers.any(
            (ProviderConfig provider) => provider.adapter == _adapterFilter,
          )) {
        _adapterFilter = '';
      }
      setState(() {
        _configPath = catalog.configPath;
        _providers = providers;
        _draft = draft;
        _isNew = isNew;
        _loading = false;
        _previewValidationStatus = '';
        _previewValidationSummary = '';
        if (!isNew && selectAlias != null) {
          _mobileDetailVisible = true;
        }
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
      _detailTab = _ProviderDetailTab.general;
      _mobileDetailVisible = true;
    });
    _schedulePreview(immediate: true);
  }

  void _startNewProvider() {
    setState(() {
      _draft = ProviderConfig.empty();
      _isNew = true;
      _detailTab = _ProviderDetailTab.general;
      _mobileDetailVisible = true;
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
      final wasNew = _isNew;
      final payload = _normalizedDraft();
      final result = wasNew
          ? await widget.providerApi.createProvider(payload)
          : await widget.providerApi.updateProvider(
              _draft.persistedAlias,
              payload,
            );
      await _loadProviders(selectAlias: result.provider.alias);
      _showMessage(wasNew ? 'Provider created.' : 'Provider settings saved.');
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
    await _verifyProviderAlias(_draft.persistedAlias, announceResult: true);
  }

  Future<void> _verifyProviderAlias(
    String alias, {
    bool announceResult = false,
  }) async {
    setState(() => _busy = true);
    try {
      final report = await widget.providerApi.verifyProvider(alias);
      await _loadProviders(selectAlias: alias);
      if (mounted) {
        setState(() {
          _draft.verificationSummary = report.summary;
        });
      }
      if (announceResult) {
        _showMessage(report.summary);
      }
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _verifyAllProviders() async {
    if (_providers.isEmpty) {
      _showMessage('No providers are available to verify.');
      return;
    }

    final selectedAlias = !_isNew ? _draft.persistedAlias : null;
    var successCount = 0;
    final failures = <String>[];

    setState(() => _busy = true);
    try {
      for (final provider in _providers) {
        try {
          await widget.providerApi.verifyProvider(provider.persistedAlias);
          successCount += 1;
        } catch (error) {
          failures.add('${provider.alias}: $error');
        }
      }
      await _loadProviders(selectAlias: selectedAlias);
      if (!mounted) {
        return;
      }
      final summary = failures.isEmpty
          ? 'Verified $successCount provider${successCount == 1 ? '' : 's'}.'
          : 'Verified $successCount provider${successCount == 1 ? '' : 's'} with ${failures.length} failure${failures.length == 1 ? '' : 's'}.';
      _showMessage(summary);
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
    await _deleteProviderAlias(_draft.persistedAlias);
  }

  Future<void> _deleteProviderAlias(String alias) async {
    setState(() => _busy = true);
    try {
      final nextAlias = alias == _draft.persistedAlias
          ? null
          : _draft.persistedAlias;
      await widget.providerApi.deleteProvider(alias);
      if (mounted && nextAlias == null) {
        setState(() => _mobileDetailVisible = false);
      }
      await _loadProviders(selectAlias: nextAlias);
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
          _previewValidationStatus = '';
          _previewValidationSummary = '';
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
        _previewValidationStatus = preview.validationStatus;
        _previewValidationSummary = preview.validationSummary;
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

  void _copyCatalogPath() {
    if (_configPath.trim().isEmpty) {
      return;
    }
    Clipboard.setData(ClipboardData(text: _configPath.trim()));
    _showMessage('Catalog path copied.');
  }

  void _copyYamlPreview() {
    if (_yamlPreview.trim().isEmpty) {
      return;
    }
    Clipboard.setData(ClipboardData(text: _yamlPreview));
    _showMessage('YAML preview copied.');
  }

  List<String> get _availableAdapters {
    final adapters =
        _providers
            .map((ProviderConfig provider) => provider.adapter.trim())
            .where((String adapter) => adapter.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return adapters;
  }

  int _countForStatus(_ProviderStatusFilter filter) {
    return switch (filter) {
      _ProviderStatusFilter.all => _providers.length,
      _ProviderStatusFilter.enabled =>
        _providers.where((ProviderConfig provider) => provider.enabled).length,
      _ProviderStatusFilter.disabled =>
        _providers.where((ProviderConfig provider) => !provider.enabled).length,
    };
  }

  List<ProviderConfig> _filteredProviders() {
    final query = _searchQuery.trim().toLowerCase();
    final visible = _providers.where((ProviderConfig provider) {
      final matchesQuery =
          query.isEmpty ||
          provider.alias.toLowerCase().contains(query) ||
          provider.adapter.toLowerCase().contains(query) ||
          provider.endpoint.toLowerCase().contains(query);
      final matchesStatus = switch (_statusFilter) {
        _ProviderStatusFilter.all => true,
        _ProviderStatusFilter.enabled => provider.enabled,
        _ProviderStatusFilter.disabled => !provider.enabled,
      };
      final matchesAdapter =
          _adapterFilter.isEmpty || provider.adapter == _adapterFilter;
      return matchesQuery && matchesStatus && matchesAdapter;
    }).toList();

    visible.sort((ProviderConfig left, ProviderConfig right) {
      return switch (_sortMode) {
        _ProviderSortMode.name => left.alias.toLowerCase().compareTo(
          right.alias.toLowerCase(),
        ),
        _ProviderSortMode.adapter => _compareStrings(
          left.adapter,
          right.adapter,
          fallbackLeft: left.alias,
          fallbackRight: right.alias,
        ),
        _ProviderSortMode.status => _compareProviderStatus(left, right),
      };
    });
    return visible;
  }

  int _compareStrings(
    String left,
    String right, {
    required String fallbackLeft,
    required String fallbackRight,
  }) {
    final primary = left.toLowerCase().compareTo(right.toLowerCase());
    if (primary != 0) {
      return primary;
    }
    return fallbackLeft.toLowerCase().compareTo(fallbackRight.toLowerCase());
  }

  int _compareProviderStatus(ProviderConfig left, ProviderConfig right) {
    int rank(ProviderConfig provider) {
      if (provider.enabled && provider.accessVerified) {
        return 0;
      }
      if (provider.enabled) {
        return 1;
      }
      if (provider.isDefault) {
        return 2;
      }
      return 3;
    }

    final rankCompare = rank(left).compareTo(rank(right));
    if (rankCompare != 0) {
      return rankCompare;
    }
    return left.alias.toLowerCase().compareTo(right.alias.toLowerCase());
  }

  Color _statusTone(ProviderConfig provider) {
    if (provider.enabled && provider.accessVerified) {
      return successColor;
    }
    if (provider.enabled) {
      return infoColor;
    }
    return warningColor;
  }

  String _statusLabel(ProviderConfig provider) {
    if (provider.enabled) {
      return 'Enabled';
    }
    return 'Disabled';
  }

  String _verificationLabel(ProviderConfig provider) {
    if (provider.accessVerified) {
      return 'Verified';
    }
    return 'Unverified';
  }

  Color _verificationTone(ProviderConfig provider) {
    if (provider.accessVerified) {
      return successColor;
    }
    return warningColor;
  }

  void _syncHeaderActions() {
    final signature = <Object>[
      widget.providerCatalogAvailable,
      _loading,
      _busy,
      _providers.length,
    ].join('|');
    if (signature == _headerActionsSignature) {
      return;
    }
    _headerActionsSignature = signature;
    final actions = _buildHeaderActions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.headerActionsController.setActions(actions);
    });
  }

  List<Widget> _buildHeaderActions() {
    if (!widget.providerCatalogAvailable) {
      return const <Widget>[];
    }

    return <Widget>[
      OutlinedButton.icon(
        key: const ValueKey<String>('providers-header-verify-all'),
        onPressed: _busy || _loading || _providers.isEmpty
            ? null
            : _verifyAllProviders,
        icon: const Icon(Icons.verified_outlined),
        label: const Text('Verify all'),
      ),
      FilledButton.icon(
        key: const ValueKey<String>('providers-header-new-provider'),
        onPressed: _busy || _loading ? null : _startNewProvider,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New provider'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _syncHeaderActions();
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

    final filteredProviders = _filteredProviders();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 980;
        final compact = constraints.maxWidth < 1320;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x94101929),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: borderColor.withValues(alpha: 0.75),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: stacked
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeOutCubic,
                        child: _mobileDetailVisible
                            ? _ProviderDetailPane(
                                key: const ValueKey<String>(
                                  'provider-detail-mobile',
                                ),
                                draft: _draft,
                                isNew: _isNew,
                                busy: _busy,
                                previewLoading: _previewLoading,
                                previewError: _previewError,
                                previewValidationStatus:
                                    _previewValidationStatus,
                                previewValidationSummary:
                                    _previewValidationSummary,
                                yamlPreview: _yamlPreview,
                                supportedAdapters: _supportedAdapters,
                                configPath: _configPath,
                                activeTab: _detailTab,
                                onTabChanged: (_ProviderDetailTab value) {
                                  setState(() => _detailTab = value);
                                },
                                onChanged: _onDraftChanged,
                                onSave: _saveProvider,
                                onVerify: _verifyProvider,
                                onDelete: _deleteProvider,
                                onBack: () {
                                  setState(() => _mobileDetailVisible = false);
                                },
                                onCopyCatalogPath: _copyCatalogPath,
                                onCopyYamlPreview: _copyYamlPreview,
                                statusTone: _statusTone(_draft),
                                statusLabel: _statusLabel(_draft),
                              )
                            : _ProviderCollectionPane(
                                key: const ValueKey<String>(
                                  'provider-collection-mobile',
                                ),
                                providers: filteredProviders,
                                selectedAlias: !_isNew
                                    ? _draft.persistedAlias
                                    : null,
                                searchController: _searchController,
                                searchQuery: _searchQuery,
                                adapterFilter: _adapterFilter,
                                availableAdapters: _availableAdapters,
                                totalCount: _providers.length,
                                enabledCount: _countForStatus(
                                  _ProviderStatusFilter.enabled,
                                ),
                                disabledCount: _countForStatus(
                                  _ProviderStatusFilter.disabled,
                                ),
                                statusFilter: _statusFilter,
                                sortMode: _sortMode,
                                busy: _busy,
                                onSearchChanged: (String value) {
                                  setState(() => _searchQuery = value);
                                },
                                onClearSearch: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                onAdapterFilterChanged: (String value) {
                                  setState(() => _adapterFilter = value);
                                },
                                onSortModeChanged: (_ProviderSortMode value) {
                                  setState(() => _sortMode = value);
                                },
                                onStatusFilterChanged:
                                    (_ProviderStatusFilter value) {
                                      setState(() => _statusFilter = value);
                                    },
                                onSelectProvider: _selectProvider,
                                onVerifyProvider: (ProviderConfig provider) {
                                  _verifyProviderAlias(
                                    provider.persistedAlias,
                                    announceResult: true,
                                  );
                                },
                                onDeleteProvider: (ProviderConfig provider) {
                                  _deleteProviderAlias(provider.persistedAlias);
                                },
                                statusLabelForProvider: _statusLabel,
                                statusToneForProvider: _statusTone,
                                verificationLabelForProvider:
                                    _verificationLabel,
                                verificationToneForProvider: _verificationTone,
                                onNewProvider: _startNewProvider,
                              ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: compact ? 52 : 50,
                            child: _ProviderCollectionPane(
                              providers: filteredProviders,
                              selectedAlias: !_isNew
                                  ? _draft.persistedAlias
                                  : null,
                              searchController: _searchController,
                              searchQuery: _searchQuery,
                              adapterFilter: _adapterFilter,
                              availableAdapters: _availableAdapters,
                              totalCount: _providers.length,
                              enabledCount: _countForStatus(
                                _ProviderStatusFilter.enabled,
                              ),
                              disabledCount: _countForStatus(
                                _ProviderStatusFilter.disabled,
                              ),
                              statusFilter: _statusFilter,
                              sortMode: _sortMode,
                              busy: _busy,
                              onSearchChanged: (String value) {
                                setState(() => _searchQuery = value);
                              },
                              onClearSearch: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              onAdapterFilterChanged: (String value) {
                                setState(() => _adapterFilter = value);
                              },
                              onSortModeChanged: (_ProviderSortMode value) {
                                setState(() => _sortMode = value);
                              },
                              onStatusFilterChanged:
                                  (_ProviderStatusFilter value) {
                                    setState(() => _statusFilter = value);
                                  },
                              onSelectProvider: _selectProvider,
                              onVerifyProvider: (ProviderConfig provider) {
                                _verifyProviderAlias(
                                  provider.persistedAlias,
                                  announceResult: true,
                                );
                              },
                              onDeleteProvider: (ProviderConfig provider) {
                                _deleteProviderAlias(provider.persistedAlias);
                              },
                              statusLabelForProvider: _statusLabel,
                              statusToneForProvider: _statusTone,
                              verificationLabelForProvider: _verificationLabel,
                              verificationToneForProvider: _verificationTone,
                              onNewProvider: _startNewProvider,
                            ),
                          ),
                          Container(
                            width: 1,
                            color: borderColor.withValues(alpha: 0.85),
                          ),
                          Expanded(
                            flex: compact ? 48 : 50,
                            child: _ProviderDetailPane(
                              draft: _draft,
                              isNew: _isNew,
                              busy: _busy,
                              previewLoading: _previewLoading,
                              previewError: _previewError,
                              previewValidationStatus: _previewValidationStatus,
                              previewValidationSummary:
                                  _previewValidationSummary,
                              yamlPreview: _yamlPreview,
                              supportedAdapters: _supportedAdapters,
                              configPath: _configPath,
                              activeTab: _detailTab,
                              onTabChanged: (_ProviderDetailTab value) {
                                setState(() => _detailTab = value);
                              },
                              onChanged: _onDraftChanged,
                              onSave: _saveProvider,
                              onVerify: _verifyProvider,
                              onDelete: _deleteProvider,
                              onBack: null,
                              onCopyCatalogPath: _copyCatalogPath,
                              onCopyYamlPreview: _copyYamlPreview,
                              statusTone: _statusTone(_draft),
                              statusLabel: _statusLabel(_draft),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProviderCollectionPane extends StatelessWidget {
  const _ProviderCollectionPane({
    super.key,
    required this.providers,
    required this.selectedAlias,
    required this.searchController,
    required this.searchQuery,
    required this.adapterFilter,
    required this.availableAdapters,
    required this.totalCount,
    required this.enabledCount,
    required this.disabledCount,
    required this.statusFilter,
    required this.sortMode,
    required this.busy,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onAdapterFilterChanged,
    required this.onSortModeChanged,
    required this.onStatusFilterChanged,
    required this.onSelectProvider,
    required this.onVerifyProvider,
    required this.onDeleteProvider,
    required this.statusLabelForProvider,
    required this.statusToneForProvider,
    required this.verificationLabelForProvider,
    required this.verificationToneForProvider,
    required this.onNewProvider,
  });

  final List<ProviderConfig> providers;
  final String? selectedAlias;
  final TextEditingController searchController;
  final String searchQuery;
  final String adapterFilter;
  final List<String> availableAdapters;
  final int totalCount;
  final int enabledCount;
  final int disabledCount;
  final _ProviderStatusFilter statusFilter;
  final _ProviderSortMode sortMode;
  final bool busy;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onAdapterFilterChanged;
  final ValueChanged<_ProviderSortMode> onSortModeChanged;
  final ValueChanged<_ProviderStatusFilter> onStatusFilterChanged;
  final ValueChanged<ProviderConfig> onSelectProvider;
  final ValueChanged<ProviderConfig> onVerifyProvider;
  final ValueChanged<ProviderConfig> onDeleteProvider;
  final String Function(ProviderConfig provider) statusLabelForProvider;
  final Color Function(ProviderConfig provider) statusToneForProvider;
  final String Function(ProviderConfig provider) verificationLabelForProvider;
  final Color Function(ProviderConfig provider) verificationToneForProvider;
  final VoidCallback onNewProvider;

  @override
  Widget build(BuildContext context) {
    final hasSearch = searchQuery.trim().isNotEmpty;
    final hasFilter = adapterFilter.trim().isNotEmpty;
    final hasStatusFilter = statusFilter != _ProviderStatusFilter.all;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints paneConstraints) {
        final compactList = paneConstraints.maxWidth < 860;

        final searchField = TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search providers...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: hasSearch
                ? IconButton(
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
          ),
        );

        final toolbarButtons = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _PopupToolbarButton<String>(
              value: adapterFilter,
              label: hasFilter ? adapterFilter : 'Adapter',
              icon: Icons.tune_rounded,
              tooltip: 'Filter by adapter',
              items: <String>['', ...availableAdapters],
              itemLabel: (String value) {
                return value.isEmpty ? 'All adapters' : value;
              },
              onSelected: onAdapterFilterChanged,
            ),
            _PopupToolbarButton<_ProviderSortMode>(
              value: sortMode,
              label: sortMode.label,
              icon: Icons.swap_vert_rounded,
              tooltip: 'Sort providers',
              items: _ProviderSortMode.values,
              itemLabel: (_ProviderSortMode value) => value.label,
              onSelected: onSortModeChanged,
            ),
            _PopupToolbarButton<_ProviderStatusFilter>(
              value: statusFilter,
              label: statusFilter.toolbarLabel(switch (statusFilter) {
                _ProviderStatusFilter.all => totalCount,
                _ProviderStatusFilter.enabled => enabledCount,
                _ProviderStatusFilter.disabled => disabledCount,
              }),
              icon: Icons.filter_alt_outlined,
              tooltip: 'Filter by provider status',
              items: _ProviderStatusFilter.values,
              itemLabel: (_ProviderStatusFilter value) {
                final count = switch (value) {
                  _ProviderStatusFilter.all => totalCount,
                  _ProviderStatusFilter.enabled => enabledCount,
                  _ProviderStatusFilter.disabled => disabledCount,
                };
                return '${value.label} ($count)';
              },
              onSelected: onStatusFilterChanged,
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              searchField,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: toolbarButtons),
              const SizedBox(height: 18),
              if (!compactList) ...[
                const _ProviderListHeader(),
                const SizedBox(height: 10),
              ],
              Expanded(
                child: providers.isEmpty
                    ? EmptyState(
                        title: hasSearch || hasFilter || hasStatusFilter
                            ? 'No matching providers'
                            : 'No providers configured',
                        body: hasSearch || hasFilter || hasStatusFilter
                            ? 'Try a different search term or clear one of the collection filters.'
                            : 'Create a provider to start managing the harness catalog from this workspace.',
                      )
                    : Scrollbar(
                        thumbVisibility: providers.length > 4,
                        child: ListView.separated(
                          itemCount: providers.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            final provider = providers[index];
                            return _ProviderListRow(
                              provider: provider,
                              selected:
                                  provider.persistedAlias == selectedAlias,
                              statusLabel: statusLabelForProvider(provider),
                              statusTone: statusToneForProvider(provider),
                              verificationLabel: verificationLabelForProvider(
                                provider,
                              ),
                              verificationTone: verificationToneForProvider(
                                provider,
                              ),
                              compact: compactList,
                              onTap: () => onSelectProvider(provider),
                              onActionSelected: (_ProviderRowAction action) {
                                switch (action) {
                                  case _ProviderRowAction.verify:
                                    onVerifyProvider(provider);
                                    return;
                                  case _ProviderRowAction.delete:
                                    onDeleteProvider(provider);
                                    return;
                                }
                              },
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    '${providers.length} provider${providers.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: textSubtleColor),
                  ),
                  const Spacer(),
                  if (providers.isEmpty)
                    FilledButton.icon(
                      onPressed: busy ? null : onNewProvider,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create provider'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PopupToolbarButton<T> extends StatelessWidget {
  const _PopupToolbarButton({
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

class _ProviderListHeader extends StatelessWidget {
  const _ProviderListHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: textSubtleColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        child: Row(
          children: const [
            SizedBox(width: 28),
            Expanded(flex: 32, child: Text('Provider')),
            Expanded(flex: 16, child: Text('Adapter')),
            Expanded(flex: 14, child: Text('Status')),
            Expanded(flex: 12, child: Text('Default')),
            Expanded(flex: 16, child: Text('Last verified')),
            SizedBox(width: 28),
          ],
        ),
      ),
    );
  }
}

class _ProviderListRow extends StatelessWidget {
  const _ProviderListRow({
    required this.provider,
    required this.selected,
    required this.statusLabel,
    required this.statusTone,
    required this.verificationLabel,
    required this.verificationTone,
    required this.compact,
    required this.onTap,
    required this.onActionSelected,
  });

  final ProviderConfig provider;
  final bool selected;
  final String statusLabel;
  final Color statusTone;
  final String verificationLabel;
  final Color verificationTone;
  final bool compact;
  final VoidCallback onTap;
  final ValueChanged<_ProviderRowAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? const Color(0xE3213045) : const Color(0xB4182231),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? infoColor.withValues(alpha: 0.75) : borderColor,
        ),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: infoColor.withValues(alpha: 0.16),
              blurRadius: 24,
              spreadRadius: 1,
            ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: compact ? _buildCompactRow() : _buildStructuredRow(),
      ),
    );
  }

  Widget _buildStructuredRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        children: [
          _SelectionIndicator(selected: selected),
          const SizedBox(width: 14),
          Expanded(
            flex: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.alias,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textPrimaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 15,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _AdapterBadge(adapter: provider.adapter, compact: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 13,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StateBadge(
                label: statusLabel,
                color: statusTone,
                compact: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 12,
            child: provider.isDefault
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: _StateBadge(
                      label: 'Default',
                      color: infoColor,
                      compact: true,
                    ),
                  )
                : const Text('—', style: TextStyle(color: textSubtleColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _VerificationMeta(
                label: verificationLabel,
                color: verificationTone,
                compact: true,
              ),
            ),
          ),
          _ActionMenuButton(onSelected: onActionSelected),
        ],
      ),
    );
  }

  Widget _buildCompactRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _SelectionIndicator(selected: selected),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.alias,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textPrimaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ActionMenuButton(onSelected: onActionSelected),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AdapterBadge(adapter: provider.adapter, compact: true),
                    _StateBadge(
                      label: statusLabel,
                      color: statusTone,
                      compact: true,
                    ),
                    if (provider.isDefault)
                      const _StateBadge(
                        label: 'Default',
                        color: infoColor,
                        compact: true,
                      ),
                    _VerificationMeta(
                      label: verificationLabel,
                      color: verificationTone,
                      compact: true,
                    ),
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

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? infoColor : textSubtleColor.withValues(alpha: 0.8),
          width: selected ? 4 : 1.4,
        ),
        color: selected
            ? infoColor.withValues(alpha: 0.22)
            : Colors.transparent,
      ),
    );
  }
}

class _AdapterBadge extends StatelessWidget {
  const _AdapterBadge({required this.adapter, this.compact = false});

  final String adapter;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 11,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0x921E2B3E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor.withValues(alpha: 0.9)),
      ),
      child: Text(
        adapter.isEmpty ? 'unknown' : adapter,
        style: TextStyle(
          color: textPrimaryColor,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 11,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 8,
            height: compact ? 6 : 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationMeta extends StatelessWidget {
  const _VerificationMeta({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  IconData get _icon {
    return switch (label) {
      'Verified' => Icons.check_circle_outline_rounded,
      'Pending' => Icons.warning_amber_rounded,
      _ => Icons.remove_circle_outline_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 11,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: compact ? 14 : 16, color: color),
          SizedBox(width: compact ? 6 : 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionMenuButton extends StatelessWidget {
  const _ActionMenuButton({required this.onSelected});

  final ValueChanged<_ProviderRowAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ProviderRowAction>(
      tooltip: 'Provider actions',
      color: const Color(0xFF111B29),
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => const [
        PopupMenuItem<_ProviderRowAction>(
          value: _ProviderRowAction.verify,
          child: Text('Verify'),
        ),
        PopupMenuItem<_ProviderRowAction>(
          value: _ProviderRowAction.delete,
          child: Text('Delete'),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.more_horiz_rounded, color: textMutedColor),
      ),
    );
  }
}

class _ProviderDetailPane extends StatelessWidget {
  const _ProviderDetailPane({
    super.key,
    required this.draft,
    required this.isNew,
    required this.busy,
    required this.previewLoading,
    required this.previewError,
    required this.previewValidationStatus,
    required this.previewValidationSummary,
    required this.yamlPreview,
    required this.supportedAdapters,
    required this.configPath,
    required this.activeTab,
    required this.onTabChanged,
    required this.onChanged,
    required this.onSave,
    required this.onVerify,
    required this.onDelete,
    required this.onBack,
    required this.onCopyCatalogPath,
    required this.onCopyYamlPreview,
    required this.statusTone,
    required this.statusLabel,
  });

  final ProviderConfig draft;
  final bool isNew;
  final bool busy;
  final bool previewLoading;
  final String? previewError;
  final String previewValidationStatus;
  final String previewValidationSummary;
  final String yamlPreview;
  final List<String> supportedAdapters;
  final String configPath;
  final _ProviderDetailTab activeTab;
  final ValueChanged<_ProviderDetailTab> onTabChanged;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;
  final Future<void> Function() onVerify;
  final Future<void> Function() onDelete;
  final VoidCallback? onBack;
  final VoidCallback onCopyCatalogPath;
  final VoidCallback onCopyYamlPreview;
  final Color statusTone;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    if (!isNew && draft.persistedAlias.trim().isEmpty) {
      return const Center(
        child: EmptyState(
          title: 'Select a provider',
          body: 'Choose a provider from the collection to edit its settings.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
          decoration: BoxDecoration(
            color: const Color(0x74101825),
            border: Border(
              bottom: BorderSide(color: borderColor.withValues(alpha: 0.9)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final stacked = constraints.maxWidth < 760;
                  final headerBadges = Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _StateBadge(
                        label: isNew ? 'Draft' : statusLabel,
                        color: isNew ? infoColor : statusTone,
                      ),
                      if (!isNew && draft.isDefault)
                        const _StateBadge(label: 'Default', color: infoColor),
                      if (!isNew && draft.accessVerified)
                        const _StateBadge(
                          label: 'Verified',
                          color: successColor,
                        ),
                    ],
                  );

                  final actionRow = Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy || isNew ? null : onVerify,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Verify'),
                      ),
                      FilledButton.icon(
                        onPressed: busy ? null : onSave,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(isNew ? 'Create' : 'Save'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy || isNew ? null : onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: dangerColor,
                          side: BorderSide(
                            color: dangerColor.withValues(alpha: 0.45),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete'),
                      ),
                    ],
                  );

                  final titleRow = Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (onBack != null)
                        IconButton(
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isNew ? infoColor : statusTone,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        isNew ? 'New provider' : blankAsUnknown(draft.alias),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: textPrimaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      headerBadges,
                    ],
                  );

                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleRow,
                        const SizedBox(height: 14),
                        actionRow,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleRow),
                      const SizedBox(width: 16),
                      actionRow,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        _ProviderDetailTabs(activeTab: activeTab, onTabChanged: onTabChanged),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            children: _buildTabContent(context),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTabContent(BuildContext context) {
    return switch (activeTab) {
      _ProviderDetailTab.general => _buildGeneralTab(context),
      _ProviderDetailTab.connection => _buildConnectionTab(context),
      _ProviderDetailTab.models => _buildModelsTab(context),
      _ProviderDetailTab.advanced => _buildAdvancedTab(context),
    };
  }

  List<Widget> _buildGeneralTab(BuildContext context) {
    return [
      _DetailSectionCard(
        title: 'General',
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final stacked = constraints.maxWidth < 720;
            return Column(
              children: [
                if (stacked) ...[
                  _TextFieldBlock(
                    label: 'Name',
                    child: TextFormField(
                      initialValue: draft.alias,
                      key: ValueKey<String>(
                        'provider-general-name-${draft.persistedAlias}-$isNew',
                      ),
                      onChanged: (String value) {
                        draft.alias = value;
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TextFieldBlock(
                    label: 'Adapter',
                    child: DropdownButtonFormField<String>(
                      initialValue: supportedAdapters.contains(draft.adapter)
                          ? draft.adapter
                          : null,
                      key: ValueKey<String>(
                        'provider-general-adapter-${draft.persistedAlias}-$isNew',
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
                    ),
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _TextFieldBlock(
                          label: 'Name',
                          child: TextFormField(
                            initialValue: draft.alias,
                            key: ValueKey<String>(
                              'provider-general-name-${draft.persistedAlias}-$isNew',
                            ),
                            onChanged: (String value) {
                              draft.alias = value;
                              onChanged();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _TextFieldBlock(
                          label: 'Adapter',
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                supportedAdapters.contains(draft.adapter)
                                ? draft.adapter
                                : null,
                            key: ValueKey<String>(
                              'provider-general-adapter-${draft.persistedAlias}-$isNew',
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
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                _TextFieldBlock(
                  label: 'Catalog path',
                  child: _ReadOnlyField(
                    value: configPath.trim().isEmpty
                        ? 'Catalog path unavailable.'
                        : configPath,
                    actionIcon: Icons.copy_all_rounded,
                    onAction: configPath.trim().isEmpty
                        ? null
                        : onCopyCatalogPath,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 18),
      _DetailSectionCard(
        title: 'Behavior',
        child: _FeatureToggleGrid(
          children: [
            _FeatureToggleCard(
              title: 'Enabled',
              description: 'Expose this provider to the harness catalog.',
              icon: Icons.toggle_on_outlined,
              value: draft.enabled,
              onChanged: (bool value) {
                draft.enabled = value;
                if (!value) {
                  draft.isDefault = false;
                }
                onChanged();
              },
            ),
            _FeatureToggleCard(
              title: 'Default provider',
              description: 'Mark this provider as the catalog default.',
              icon: Icons.auto_awesome_motion_outlined,
              value: draft.isDefault,
              onChanged: (bool value) {
                draft.isDefault = value;
                if (value) {
                  draft.enabled = true;
                }
                onChanged();
              },
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildConnectionTab(BuildContext context) {
    return [
      _DetailSectionCard(
        title: 'Connection',
        child: Column(
          children: [
            _TextFieldBlock(
              label: 'Base URL',
              child: TextFormField(
                initialValue: draft.endpoint,
                key: ValueKey<String>(
                  'provider-connection-url-${draft.persistedAlias}-$isNew',
                ),
                onChanged: (String value) {
                  draft.endpoint = value;
                  onChanged();
                },
              ),
            ),
            const SizedBox(height: 16),
            _TextFieldBlock(
              label: 'API key env var',
              child: TextFormField(
                initialValue: draft.apiKeyEnv,
                key: ValueKey<String>(
                  'provider-connection-key-${draft.persistedAlias}-$isNew',
                ),
                onChanged: (String value) {
                  draft.apiKeyEnv = value;
                  onChanged();
                },
              ),
            ),
            const SizedBox(height: 16),
            _TextFieldBlock(
              label: 'Timeout seconds',
              child: TextFormField(
                initialValue: draft.timeoutSecs == 0
                    ? ''
                    : '${draft.timeoutSecs}',
                key: ValueKey<String>(
                  'provider-connection-timeout-${draft.persistedAlias}-$isNew',
                ),
                keyboardType: TextInputType.number,
                onChanged: (String value) {
                  draft.timeoutSecs = int.tryParse(value.trim()) ?? 0;
                  onChanged();
                },
              ),
            ),
            const SizedBox(height: 18),
            _FeatureToggleCard(
              title: 'Secure connection',
              description:
                  'Require HTTPS. Disable only for local HTTP endpoints.',
              icon: Icons.lock_outline_rounded,
              value: draft.secure,
              onChanged: (bool value) {
                draft.secure = value;
                onChanged();
              },
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildModelsTab(BuildContext context) {
    return [
      _DetailSectionCard(
        title: 'Models',
        trailing: FilledButton.icon(
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
        child: draft.models.isEmpty
            ? const InfoPanel(
                title: 'No models configured',
                body:
                    'Add model aliases here when the provider exposes a specific catalog.',
              )
            : Column(
                children: List<Widget>.generate(draft.models.length, (
                  int index,
                ) {
                  final model = draft.models[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == draft.models.length - 1 ? 0 : 12,
                    ),
                    child: _ModelCard(
                      model: model,
                      draftAlias: draft.persistedAlias,
                      isNew: isNew,
                      index: index,
                      onChanged: onChanged,
                      onDelete: () {
                        draft.models.removeAt(index);
                        onChanged();
                      },
                    ),
                  );
                }),
              ),
      ),
    ];
  }

  List<Widget> _buildAdvancedTab(BuildContext context) {
    final previewText = draft.alias.trim().isEmpty
        ? 'Set a provider name to preview YAML.'
        : previewLoading
        ? 'Refreshing preview...'
        : yamlPreview.trim().isEmpty
        ? 'Preview unavailable.'
        : yamlPreview;

    return [
      _DetailSectionCard(
        title: 'Verification',
        child: InfoPanel(
          title: draft.accessVerified
              ? 'Provider verified'
              : 'Verification required',
          body: draft.verificationSummary,
          tone: draft.accessVerified ? successColor : warningColor,
        ),
      ),
      const SizedBox(height: 18),
      _DetailSectionCard(
        title: 'Validation preview',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoPanel(
              title: previewValidationStatus.trim().isEmpty
                  ? 'Preview status'
                  : previewValidationStatus,
              body: previewValidationSummary.trim().isEmpty
                  ? 'Preview feedback will appear here as the provider draft changes.'
                  : previewValidationSummary,
              tone: previewValidationStatus == 'valid'
                  ? successColor
                  : previewValidationStatus == 'invalid'
                  ? dangerColor
                  : infoColor,
            ),
            if (previewError != null) ...[
              const SizedBox(height: 14),
              InfoPanel(
                title: 'Preview error',
                body: previewError!,
                tone: dangerColor,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
      _DetailSectionCard(
        title: 'Raw YAML',
        trailing: OutlinedButton.icon(
          onPressed: yamlPreview.trim().isEmpty ? null : onCopyYamlPreview,
          icon: const Icon(Icons.copy_all_rounded),
          label: const Text('Copy'),
        ),
        child: SelectionArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xDD111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor.withValues(alpha: 0.85)),
            ),
            child: Text(
              previewText,
              style: const TextStyle(
                color: textPrimaryColor,
                height: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _ProviderDetailTabs extends StatelessWidget {
  const _ProviderDetailTabs({
    required this.activeTab,
    required this.onTabChanged,
  });

  final _ProviderDetailTab activeTab;
  final ValueChanged<_ProviderDetailTab> onTabChanged;

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
        children: _ProviderDetailTab.values.map((_ProviderDetailTab tab) {
          final selected = tab == activeTab;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTabChanged(tab),
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tab.label,
                    style: TextStyle(
                      color: selected ? textPrimaryColor : textMutedColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 58,
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

class _DetailSectionCard extends StatelessWidget {
  const _DetailSectionCard({
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _TextFieldBlock extends StatelessWidget {
  const _TextFieldBlock({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textPrimaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value, this.actionIcon, this.onAction});

  final String value;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0x99212D41),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: textMutedColor),
              ),
            ),
          ),
          if (actionIcon != null)
            Container(
              width: 56,
              height: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: borderColor.withValues(alpha: 0.85)),
                ),
              ),
              child: IconButton(
                onPressed: onAction,
                icon: Icon(actionIcon, color: textMutedColor),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeatureToggleGrid extends StatelessWidget {
  const _FeatureToggleGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final columns = constraints.maxWidth > 920
            ? 3
            : constraints.maxWidth > 620
            ? 2
            : 1;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: children
              .map((Widget child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _FeatureToggleCard extends StatelessWidget {
  const _FeatureToggleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x85162230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: infoColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: infoColor.withValues(alpha: 0.26)),
                ),
                child: Icon(icon, size: 18, color: infoColor),
              ),
              const Spacer(),
              Switch.adaptive(value: value, onChanged: onChanged),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(color: textMutedColor, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.draftAlias,
    required this.isNew,
    required this.index,
    required this.onChanged,
    required this.onDelete,
  });

  final ProviderModelConfig model;
  final String draftAlias;
  final bool isNew;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x85162230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.85)),
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
                    'provider-model-$draftAlias-$isNew-$index-${model.name}',
                  ),
                  decoration: const InputDecoration(labelText: 'Model alias'),
                  onChanged: (String value) {
                    model.name = value;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: model.enabled,
            onChanged: (bool value) {
              model.enabled = value;
              onChanged();
            },
            title: const Text('Enabled'),
            subtitle: Text(
              model.accessVerified ? 'Verified access' : 'Verification pending',
              style: const TextStyle(color: textMutedColor),
            ),
          ),
        ],
      ),
    );
  }
}
