import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ui/shared/admin_http_client.dart';

void main() {
  test('builds admin headers consistently', () {
    final client = AdminHttpClient(
      baseUrl: 'http://127.0.0.1:8080',
      adminToken: 'secret-token',
    );

    expect(client.headers(), <String, String>{
      'Accept': 'application/json',
      'X-Admin-Token': 'secret-token',
    });
    expect(client.headers(json: true), <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Admin-Token': 'secret-token',
    });
  });

  test('decodes json maps and surfaces API errors', () async {
    final client = AdminHttpClient(
      baseUrl: 'http://127.0.0.1:8080',
      adminToken: '',
    );

    final ok = await client.decodeJsonMap(
      http.Response('{"status":"ok"}', 200),
      _TestException.new,
    );
    expect(ok['status'], 'ok');

    expect(
      () => client.decodeJsonMap(
        http.Response('{"error":"boom"}', 400),
        _TestException.new,
      ),
      throwsA(isA<_TestException>()),
    );
  });

  test('decodes json lists and surfaces list endpoint errors', () async {
    final client = AdminHttpClient(
      baseUrl: 'http://127.0.0.1:8080',
      adminToken: '',
    );

    final ok = await client.decodeJsonList(
      http.Response('[{"id":"1"},{"id":"2"}]', 200),
      _TestException.new,
    );
    expect(ok, hasLength(2));

    expect(
      () => client.decodeJsonList(
        http.Response('{"error":"list failed"}', 500),
        _TestException.new,
      ),
      throwsA(isA<_TestException>()),
    );
  });
}

class _TestException implements Exception {
  _TestException(this.message);

  final String message;
}
