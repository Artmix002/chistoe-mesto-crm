import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Генерирует verifier согласно RFC 7636: URL-safe строка длиной 43–128.
String generatePkceCodeVerifier() {
  final random = Random.secure();
  final bytes = List<int>.generate(48, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

String pkceCodeChallenge(String verifier) => base64UrlEncode(
  sha256.convert(utf8.encode(verifier)).bytes,
).replaceAll('=', '');

/// Отдельный state защищает loopback redirect от подмены OAuth-кода.
String generateOAuthState() => generatePkceCodeVerifier();
