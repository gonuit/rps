import 'dart:convert';

import 'package:http/http.dart' as http;

/// Exception thrown when a pub.dev API request fails.
class PubDevApiException implements Exception {
  /// HTTP status code, if available.
  final int? statusCode;

  /// Error message from the API response.
  final String? message;

  /// Creates a [PubDevApiException].
  PubDevApiException(this.statusCode, [this.message]);

  /// Creates a [PubDevApiException] from an HTTP [response].
  factory PubDevApiException.fromResponse(http.Response response) {
    final data = jsonDecode(response.body);
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      return PubDevApiException(response.statusCode, error['message']);
    }
    return PubDevApiException(response.statusCode);
  }

  @override
  String toString() =>
      'PubDevApiException(statusCode: $statusCode, message: $message)';
}

/// Client for the pub.dev REST API.
class PubDevApi {
  final http.Client? _client;
  final String _userAgent;

  /// Creates a [PubDevApi] with an optional HTTP [client] and [userAgent].
  const PubDevApi({
    http.Client? client,
    String userAgent = 'rps',
  })  : _client = client,
        _userAgent = userAgent;

  /// The base URL for the pub.dev API.
  String get baseUrl => 'https://pub.dev/api';

  /// Fetches the latest version string for [packageName].
  Future<String> getLastVersion(String packageName) async {
    final uri = Uri.parse('$baseUrl/packages/$packageName');
    final headers = {'User-Agent': _userAgent};
    final response = await (_client?.get(uri, headers: headers) ??
        http.get(uri, headers: headers));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['latest']['version'];
    } else {
      throw PubDevApiException.fromResponse(response);
    }
  }
}
