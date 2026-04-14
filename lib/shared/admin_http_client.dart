import 'dart:convert';

import 'package:http/http.dart' as http;

typedef ExceptionBuilder = Exception Function(String message);

class AdminHttpClient {
  AdminHttpClient({
    required this.baseUrl,
    required this.adminToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String adminToken;
  final http.Client _client;

  Uri uri(String path, [Map<String, String>? query]) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path').replace(queryParameters: query);
  }

  Map<String, String> headers({bool json = false}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (adminToken.trim().isNotEmpty) {
      headers['X-Admin-Token'] = adminToken.trim();
    }
    return headers;
  }

  Future<Map<String, dynamic>> decodeJsonMap(
    http.Response response,
    ExceptionBuilder exceptionBuilder,
  ) async {
    final bodyText = utf8.decode(response.bodyBytes);
    final payload = bodyText.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(bodyText) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw exceptionBuilder(
        payload['error'] as String? ??
            'Request failed with status ${response.statusCode}.',
      );
    }
    return payload;
  }

  Future<List<Map<String, dynamic>>> decodeJsonList(
    http.Response response,
    ExceptionBuilder exceptionBuilder,
  ) async {
    final bodyText = utf8.decode(response.bodyBytes);
    final decoded = bodyText.trim().isEmpty
        ? <dynamic>[]
        : jsonDecode(bodyText);
    if (response.statusCode >= 400) {
      final errorPayload = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      throw exceptionBuilder(
        errorPayload['error'] as String? ??
            'Request failed with status ${response.statusCode}.',
      );
    }
    final payload = decoded is List<dynamic> ? decoded : <dynamic>[];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<http.Response> get(String path, {Map<String, String>? query}) {
    return _client.get(uri(path, query), headers: headers());
  }

  Future<http.Response> post(
    String path, {
    Map<String, String>? query,
    Object? body,
  }) {
    return _client.post(
      uri(path, query),
      headers: headers(json: body != null),
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> put(
    String path, {
    Map<String, String>? query,
    Object? body,
  }) {
    return _client.put(
      uri(path, query),
      headers: headers(json: body != null),
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> delete(String path, {Map<String, String>? query}) {
    return _client.delete(uri(path, query), headers: headers());
  }
}
