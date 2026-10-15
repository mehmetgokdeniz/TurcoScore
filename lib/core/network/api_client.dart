import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.path, this.baseUrl});

  final String message;
  final int? statusCode;
  final String? path;
  final String? baseUrl;

  /// Ağ hatası, 403 (WAF), 429 (rate limit) -> veri kaynağı kullanılamıyor.
  bool get isSourceUnavailable =>
      statusCode == null ||
      statusCode == 403 ||
      statusCode == 429 ||
      statusCode == 451;

  @override
  String toString() =>
      'ApiException(${statusCode ?? 'network'}): $message${path == null ? '' : ' ($path)'}';
}

class ApiClient {
  ApiClient({
    http.Client? client,
    List<String>? baseUrls,
    Map<String, String>? headers,
  })  : _client = client ?? http.Client(),
        _baseUrls = List.unmodifiable(baseUrls ?? ApiConstants.baseUrls),
        _extraHeaders = Map.unmodifiable(headers ?? const {});

  final http.Client _client;
  final List<String> _baseUrls;
  final Map<String, String> _extraHeaders;
  static const Duration _timeout = Duration(seconds: 20);

  /// Son başarılı alan adı; sonraki isteklerden önce o denenir.
  String? _activeBaseUrl;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'User-Agent': ApiConstants.userAgent,
        ..._extraHeaders,
      };

  List<String> get _orderedBaseUrls {
    final active = _activeBaseUrl;
    if (active == null) return _baseUrls;
    return [active, ..._baseUrls.where((url) => url != active)];
  }

  /// Yedekli taban adresler üzerinden JSON alır (çoklu alan adı stratejisi).
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    ApiException? lastFailure;

    for (final baseUrl in _orderedBaseUrls) {
      try {
        final result = await getAt(baseUrl, path,
            queryParameters: queryParameters);
        _activeBaseUrl = baseUrl;
        return result;
      } on ApiException catch (e) {
        lastFailure = e;
        // Alan adı cevap verdiyse (404/400) sorun yolda, değiştirmenin anlamı yok.
        if (!e.isSourceUnavailable) rethrow;
      }
    }

    throw lastFailure ?? ApiException('Erişilecek sunucu yok', path: path);
  }

  /// Belirli tek bir taban adrese istek atar (çoklu adresli kaynaklar için).
  Future<Map<String, dynamic>> getAt(
    String baseUrl,
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final body = await _readTextAt(baseUrl, path, queryParameters);
    final dynamic decoded;
    try {
      decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    } on FormatException {
      throw ApiException('Geçersiz JSON yanıtı',
          statusCode: 200, path: path, baseUrl: baseUrl);
    }
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw ApiException('Beklenmeyen yanıt biçimi',
        statusCode: 200, path: path, baseUrl: baseUrl);
  }

  /// JSON olmayan uçlar için ham metin (HTML, JS-dizi literal vb.).
  Future<String> getText(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    ApiException? lastFailure;
    for (final baseUrl in _orderedBaseUrls) {
      try {
        final text = await _readTextAt(baseUrl, path, queryParameters);
        _activeBaseUrl = baseUrl;
        return text;
      } on ApiException catch (e) {
        lastFailure = e;
        if (!e.isSourceUnavailable) rethrow;
      }
    }
    throw lastFailure ?? ApiException('Erişilecek sunucu yok', path: path);
  }

  Future<String> _readTextAt(
    String baseUrl,
    String path,
    Map<String, String>? queryParameters,
  ) async {
    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);

    final http.Response response;
    try {
      response = await _client.get(uri, headers: _headers).timeout(_timeout);
    } on TimeoutException {
      throw ApiException('İstek zaman aşımına uğradı',
          path: path, baseUrl: baseUrl);
    } on SocketException {
      throw ApiException('Bağlantı kurulamadı', path: path, baseUrl: baseUrl);
    } on http.ClientException catch (e) {
      throw ApiException(e.message, path: path, baseUrl: baseUrl);
    }

    if (response.statusCode >= 400) {
      throw ApiException('Sunucu hatası',
          statusCode: response.statusCode, path: path, baseUrl: baseUrl);
    }
    return utf8.decode(response.bodyBytes);
  }

  void dispose() => _client.close();
}
