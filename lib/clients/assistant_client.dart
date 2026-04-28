/// Provides an ADK REST client for assistant sessions and streaming runs.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

/// AssistantException reports an ADK REST or stream parsing failure.
class AssistantException implements Exception {
  /// Creates an assistant exception with a display message.
  const AssistantException(this.message);

  /// Error message.
  final String message;

  /// Formats the exception for logs and UI fallback details.
  @override
  String toString() => 'AssistantException: $message';
}

/// AssistantEvent is a normalized ADK runtime event.
class AssistantEvent {
  /// Creates a normalized assistant event.
  const AssistantEvent({
    required this.id,
    required this.author,
    required this.text,
    required this.partial,
    this.toolActivity,
    this.confirmation,
    this.errorMessage = '',
  });

  /// Event id.
  final String id;

  /// ADK event author.
  final String author;

  /// Text content, if present.
  final String text;

  /// Whether this is a partial streaming event.
  final bool partial;

  /// Tool activity, if present.
  final ToolActivity? toolActivity;

  /// Confirmation request, if present.
  final ConfirmationRequest? confirmation;

  /// Error message, if present.
  final String errorMessage;
}

/// AssistantClient calls the ADK REST API used by the Flutter workspace.
class AssistantClient {
  /// Creates an assistant client.
  AssistantClient({
    required this.baseUrl,
    required this.appName,
    required this.userId,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Base URL of the ADK REST API.
  final String baseUrl;

  /// ADK app name.
  final String appName;

  /// ADK user id.
  final String userId;

  final http.Client _http;

  /// Lists existing ADK sessions for the configured user.
  Future<List<ChatSession>> listSessions() async {
    final response = await _http.get(
      _uri('/apps/$appName/users/$userId/sessions'),
    );
    if (response.statusCode != 200) {
      throw AssistantException('HTTP ${response.statusCode} listing sessions');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <ChatSession>[];
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(parseChatSession)
        .toList();
  }

  /// Creates a new ADK session.
  Future<ChatSession> createSession() async {
    final response = await _http.post(
      _uri('/apps/$appName/users/$userId/sessions'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{'state': <String, dynamic>{}}),
    );
    if (response.statusCode != 200) {
      throw AssistantException('HTTP ${response.statusCode} creating session');
    }
    return parseChatSession(jsonDecode(response.body));
  }

  /// Deletes an ADK session.
  Future<void> deleteSession(String sessionId) async {
    final response = await _http.delete(
      _uri('/apps/$appName/users/$userId/sessions/$sessionId'),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw AssistantException('HTTP ${response.statusCode} deleting session');
    }
  }

  /// Loads normalized events for one ADK session.
  Future<List<AssistantEvent>> loadSessionEvents(String sessionId) async {
    final response = await _http.get(
      _uri('/apps/$appName/users/$userId/sessions/$sessionId'),
    );
    if (response.statusCode != 200) {
      throw AssistantException('HTTP ${response.statusCode} loading session');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const <AssistantEvent>[];
    }
    final events = decoded['events'];
    if (events is! List) {
      return const <AssistantEvent>[];
    }
    return events
        .whereType<Map<String, dynamic>>()
        .map(parseAssistantEvent)
        .toList();
  }

  /// Sends a user message or confirmation reply and streams ADK events.
  Stream<AssistantEvent> sendMessage({
    required String sessionId,
    String text = '',
    ConfirmationReply? confirmation,
  }) async* {
    final request = http.Request('POST', _uri('/run_sse'));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode(_runBody(sessionId, text, confirmation));
    final response = await _http.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw AssistantException(
        'HTTP ${response.statusCode} running agent: $body',
      );
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final buffer = StringBuffer();
    await for (final line in lines) {
      if (line.startsWith('data:')) {
        buffer.writeln(line.substring(5).trimLeft());
      } else if (line.isEmpty && buffer.isNotEmpty) {
        yield parseAssistantEvent(jsonDecode(buffer.toString()));
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) {
      yield parseAssistantEvent(jsonDecode(buffer.toString()));
    }
  }

  /// Closes the underlying HTTP client.
  void close() {
    _http.close();
  }

  Uri _uri(String path) {
    final trimmedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$trimmedBase$path');
  }

  Map<String, dynamic> _runBody(
    String sessionId,
    String text,
    ConfirmationReply? confirmation,
  ) {
    final part = confirmation == null
        ? <String, dynamic>{'text': text}
        : <String, dynamic>{
            'functionResponse': <String, dynamic>{
              'id': confirmation.callId,
              'name': 'adk_request_confirmation',
              'response': <String, dynamic>{
                'confirmed': confirmation.confirmed,
                if (confirmation.confirmed && confirmation.action != null)
                  'payload': <String, dynamic>{'action': confirmation.action},
              },
            },
          };
    return <String, dynamic>{
      'appName': appName,
      'userId': userId,
      'sessionId': sessionId,
      'streaming': true,
      'newMessage': <String, dynamic>{
        'role': 'user',
        'parts': <Map<String, dynamic>>[part],
      },
    };
  }
}

/// Parses a session returned by the ADK sessions API.
ChatSession parseChatSession(dynamic value) {
  final map = value is Map<String, dynamic> ? value : <String, dynamic>{};
  final id = stringFrom(map['id'], fallback: 'session');
  final updatedSeconds = map['lastUpdateTime'];
  final updatedAt = updatedSeconds is num
      ? DateTime.fromMillisecondsSinceEpoch(updatedSeconds.toInt() * 1000)
      : DateTime.now();
  return ChatSession(id: id, title: titleFromSession(id), updatedAt: updatedAt);
}

/// Parses one ADK runtime event into a UI event.
AssistantEvent parseAssistantEvent(Map<String, dynamic> event) {
  final content = event['content'];
  final parts = content is Map<String, dynamic> ? content['parts'] : null;
  var text = '';
  ToolActivity? toolActivity;
  ConfirmationRequest? confirmation;
  if (parts is List) {
    for (final rawPart in parts.whereType<Map<String, dynamic>>()) {
      if (rawPart['text'] != null) {
        text += stringFrom(rawPart['text']);
      }
      final functionCall = rawPart['functionCall'];
      if (functionCall is Map<String, dynamic>) {
        final name = stringFrom(functionCall['name'], fallback: 'tool');
        if (name == 'adk_request_confirmation') {
          confirmation = parseConfirmation(functionCall);
        } else {
          toolActivity = ToolActivity(
            name: name,
            status: 'requested',
            summary: 'Aurora requested $name',
          );
        }
      }
      final functionResponse = rawPart['functionResponse'];
      if (functionResponse is Map<String, dynamic>) {
        final name = stringFrom(functionResponse['name'], fallback: 'tool');
        toolActivity = ToolActivity(
          name: name,
          status: 'completed',
          summary: 'Tool response received',
        );
      }
    }
  }
  return AssistantEvent(
    id: stringFrom(
      event['id'],
      fallback: DateTime.now().microsecondsSinceEpoch.toString(),
    ),
    author: stringFrom(event['author'], fallback: 'Aurora'),
    text: text,
    partial: event['partial'] == true,
    toolActivity: toolActivity,
    confirmation: confirmation,
    errorMessage: stringFrom(event['errorMessage']),
  );
}

/// Parses an ADK confirmation function call.
ConfirmationRequest parseConfirmation(Map<String, dynamic> functionCall) {
  final args = functionCall['args'];
  final body = args is Map<String, dynamic> ? args['toolConfirmation'] : null;
  final confirmation = body is Map<String, dynamic>
      ? body
      : <String, dynamic>{};
  final payload = confirmation['payload'];
  final optionsSource = payload is Map<String, dynamic>
      ? payload['options']
      : null;
  final options = optionsSource is List
      ? optionsSource.whereType<Map<String, dynamic>>().map((option) {
          return ConfirmationOption(
            action: stringFrom(option['action'], fallback: 'approve_once'),
            label: stringFrom(option['label'], fallback: 'Approve once'),
          );
        }).toList()
      : const <ConfirmationOption>[
          ConfirmationOption(action: 'deny', label: 'Deny'),
          ConfirmationOption(action: 'approve_once', label: 'Approve once'),
        ];
  return ConfirmationRequest(
    callId: stringFrom(functionCall['id']),
    hint: stringFrom(
      confirmation['hint'],
      fallback: 'Aurora wants to use a tool.',
    ),
    options: options,
  );
}

/// Converts a dynamic value to a string.
String stringFrom(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

/// Builds a compact display title from a session id.
String titleFromSession(String id) {
  if (id.length <= 8) {
    return 'Chat $id';
  }
  return 'Chat ${id.substring(0, 8)}';
}
