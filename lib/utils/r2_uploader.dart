import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class R2Uploader {
  static const _accessKeyId = '125f7112e973bd63b741d1053cafb5ca';
  static const _secretAccessKey =
      '2f0d421215d9efd07c4d4d987a366fe8359360daf911435f49b7b488fbe5122a';
  static const _bucket = 'reptile-images';
  static const _region = 'auto';
  static const _accountId = '5afe5db71ffd2677a9780686b33f9267';
  // After enabling R2 public access, replace with the actual r2.dev subdomain:
  static const _publicBaseUrl = 'https://pub-10b6955917824b18a47d80c0f5fe1a1d.r2.dev';

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _hmac(List<int> key, String data) =>
      Hmac(sha256, key).convert(utf8.encode(data)).bytes;

  static String _sha256Hex(Uint8List data) =>
      sha256.convert(data).toString();

  /// Uploads [bytes] as JPEG to R2 and returns the public URL.
  /// [objectKey] example: 'userId/1716000000000.jpg'
  static Future<String> upload(Uint8List bytes, String objectKey) async {
    final now = DateTime.now().toUtc();
    final dateStamp = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final amzDate =
        '${dateStamp}T${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}Z';

    final host = '$_accountId.r2.cloudflarestorage.com';
    final payloadHash = _sha256Hex(bytes);
    final contentType = 'image/jpeg';

    // ── 1. Canonical request ─────────────────────────────────────────────────
    final canonicalHeaders =
        'content-type:$contentType\nhost:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate\n';
    final signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';
    final canonicalUri = '/$_bucket/$objectKey';
    const canonicalQueryString = '';

    final canonicalRequest = [
      'PUT',
      canonicalUri,
      canonicalQueryString,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    // ── 2. String to sign ────────────────────────────────────────────────────
    final credentialScope = '$dateStamp/$_region/s3/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      _hex(sha256.convert(utf8.encode(canonicalRequest)).bytes),
    ].join('\n');

    // ── 3. Signing key ───────────────────────────────────────────────────────
    final kDate = _hmac(utf8.encode('AWS4$_secretAccessKey'), dateStamp);
    final kRegion = _hmac(kDate, _region);
    final kService = _hmac(kRegion, 's3');
    final kSigning = _hmac(kService, 'aws4_request');

    final signature = _hex(_hmac(kSigning, stringToSign));

    final authorization = 'AWS4-HMAC-SHA256 '
        'Credential=$_accessKeyId/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';

    // ── 4. HTTP PUT ──────────────────────────────────────────────────────────
    final url = Uri.parse('https://$host$canonicalUri');
    final response = await http.put(
      url,
      headers: {
        'Host': host,
        'Content-Type': contentType,
        'x-amz-date': amzDate,
        'x-amz-content-sha256': payloadHash,
        'Authorization': authorization,
      },
      body: bytes,
    );

    if (response.statusCode != 200) {
      throw Exception('R2 upload failed ${response.statusCode}: ${response.body}');
    }

    return '$_publicBaseUrl/$objectKey';
  }
}
