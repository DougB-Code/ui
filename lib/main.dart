import 'package:flutter/material.dart';
import 'package:ui/app/app_shell.dart';
import 'package:ui/control_plane/control_plane_api.dart';
import 'package:ui/harness_config/harness_config_api.dart';
import 'package:ui/operations/operations_api.dart';
import 'package:ui/providers/provider_catalog_api.dart';
import 'package:ui/shared/ui.dart';

void main() {
  runApp(
    AgentAwesomeBetaApp(
      controlPlaneBaseUrl: const String.fromEnvironment(
        'CONTROL_PLANE_BASE_URL',
        defaultValue: 'http://127.0.0.1:8080',
      ),
      controlPlaneApi: HttpControlPlaneApi.fromEnvironment(),
      harnessConfigApi: HttpHarnessConfigApi.fromEnvironment(),
      operationsApi: HttpOperationsApi.fromEnvironment(),
      providerApi: HttpProviderCatalogApi.fromEnvironment(),
    ),
  );
}

class AgentAwesomeBetaApp extends StatelessWidget {
  const AgentAwesomeBetaApp({
    super.key,
    required this.controlPlaneBaseUrl,
    required this.controlPlaneApi,
    required this.harnessConfigApi,
    required this.operationsApi,
    required this.providerApi,
  });

  final String controlPlaneBaseUrl;
  final ControlPlaneApi controlPlaneApi;
  final HarnessConfigApi harnessConfigApi;
  final OperationsApi operationsApi;
  final ProviderCatalogApi providerApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAgentAwesomeTheme(),
      home: BetaShell(
        controlPlaneBaseUrl: controlPlaneBaseUrl,
        controlPlaneApi: controlPlaneApi,
        harnessConfigApi: harnessConfigApi,
        operationsApi: operationsApi,
        providerApi: providerApi,
      ),
    );
  }
}
