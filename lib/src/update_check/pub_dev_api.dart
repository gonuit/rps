import 'dart:convert';

import 'package:http/http.dart' as http;

class PubDevApiException implements Exception {
  final int? statusCode;
  final String? message;

  PubDevApiException(this.statusCode, [this.message]);

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

class PubDevApi {
  final http.Client? _client;
  final String _userAgent;

  const PubDevApi({
    http.Client? client,
    String userAgent = 'rps',
  })  : _client = client,
        _userAgent = userAgent;

  String get baseUrl => 'https://pub.dev/api';

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
