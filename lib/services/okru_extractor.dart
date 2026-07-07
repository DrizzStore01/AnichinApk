import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Extractor khusus buat embed OK.ru (odnoklassniki).
///
/// Halaman embed OK.ru (`https://ok.ru/videoembed/<id>`) itu sebenernya nyimpen
/// JSON tersembunyi di attribute `data-options="{...}"` yang isinya
/// `flashvars.metadata` — JSON lain lagi yang isinya list `videos` (url video
/// asli per kualitas) dan/atau `hlsManifestUrl` (link m3u8). Kalau kita ambil
/// itu, kita bisa muter videonya pake native player (video_player/chewie)
/// tanpa perlu iframe/WebView sama sekali.
///
/// Catatan: link video hasil extract ini biasanya ada masa berlaku (~jam-an),
/// jadi harus di-extract ulang tiap kali user buka episode / pilih server ini.
class OkRuExtractor {
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  static bool isOkRuLink(String url) => url.contains('ok.ru');

  /// Balikin direct url video (m3u8 kalau ada, kalau enggak ambil salah satu
  /// kualitas dari `videos`). Balikin null kalau gagal di-extract.
  ///
  /// Tiap langkah di-log pake debugPrint (prefix "[OkRu]"), keliatan di
  /// console `flutter run` buat gampang nge-debug kalau ada yang gagal.
  static Future<String?> extractDirectUrl(String embedUrl) async {
    final videoId = RegExp(r'(\d[\d-]*)/?$').firstMatch(embedUrl)?.group(1);
    if (videoId == null) {
      debugPrint('[OkRu] gagal ambil videoId dari url: $embedUrl');
      return null;
    }
    debugPrint('[OkRu] videoId: $videoId');

    late final http.Response response;
    try {
      response = await http.get(
        Uri.parse('https://ok.ru/videoembed/$videoId'),
        headers: {'User-Agent': _userAgent},
      );
    } catch (e) {
      debugPrint('[OkRu] http.get gagal (exception): $e');
      return null;
    }

    debugPrint('[OkRu] statusCode: ${response.statusCode}, '
        'body length: ${response.body.length}');

    if (response.statusCode != 200) {
      debugPrint('[OkRu] statusCode bukan 200, berhenti di sini.');
      return null;
    }

    final html = response.body;

    // Attribute-nya "data-options="{...semua di-HTML-escape...}"" — gak ada
    // tanda kutip mentah di dalem value-nya (semua udah jadi &quot;), jadi
    // aman diambil sekaligus sampe kutip penutup pertama.
    final optionsMatch =
        RegExp(r'data-options="([^"]*)"').firstMatch(html);
    if (optionsMatch == null) {
      debugPrint('[OkRu] regex data-options gak nemu match sama sekali. '
          'Kemungkinan HTML yang dibalikin beda (misal halaman blokir/captcha).');
      return null;
    }
    debugPrint('[OkRu] data-options ketemu, panjang: '
        '${optionsMatch.group(1)!.length} karakter');

    Map<String, dynamic>? player;
    try {
      player = json.decode(_htmlUnescape(optionsMatch.group(1)!));
    } catch (e) {
      debugPrint('[OkRu] gagal decode JSON player (data-options): $e');
      return null;
    }
    debugPrint('[OkRu] player JSON berhasil di-decode. '
        'Keys: ${player?.keys.toList()}');

    final flashvars = player?['flashvars'] as Map<String, dynamic>?;
    if (flashvars == null) {
      debugPrint('[OkRu] flashvars null / bukan Map. player: $player');
      return null;
    }

    final metadataRaw = flashvars['metadata'];
    if (metadataRaw is! String) {
      debugPrint('[OkRu] flashvars.metadata bukan String: '
          '${metadataRaw.runtimeType}');
      return null;
    }

    Map<String, dynamic> metadata;
    try {
      metadata = json.decode(_htmlUnescape(metadataRaw));
    } catch (e) {
      debugPrint('[OkRu] gagal decode JSON metadata: $e');
      return null;
    }
    debugPrint('[OkRu] metadata JSON berhasil di-decode. '
        'Keys: ${metadata.keys.toList()}');

    // Prioritas: hlsManifestUrl (adaptive, paling stabil di video_player).
    final hlsUrl = metadata['hlsManifestUrl'];
    if (hlsUrl is String && hlsUrl.isNotEmpty) {
      debugPrint('[OkRu] hlsManifestUrl ketemu: $hlsUrl');
      return hlsUrl;
    }

    final videos = (metadata['videos'] as List?) ?? [];
    debugPrint('[OkRu] gak ada hlsManifestUrl, jumlah videos: ${videos.length}');
    if (videos.isEmpty) return null;

    // Urutan kualitas dari yang paling bagus, sesuai nama yang dipake OK.ru.
    const preferredOrder = ['full', 'hd', 'sd', 'low', 'lowest', 'mobile'];
    for (final name in preferredOrder) {
      final match = videos.cast<Map?>().firstWhere(
            (v) => v?['name'] == name,
            orElse: () => null,
          );
      if (match != null && match['url'] is String) {
        debugPrint('[OkRu] pakai kualitas "$name": ${match['url']}');
        return match['url'] as String;
      }
    }

    // Gak ketemu nama yang cocok, ambil aja yang terakhir (biasanya kualitas tertinggi).
    final fallback = videos.last;
    final fallbackUrl =
        fallback is Map && fallback['url'] is String ? fallback['url'] as String : null;
    debugPrint('[OkRu] pakai fallback video terakhir: $fallbackUrl');
    return fallbackUrl;
  }

  static String _htmlUnescape(String s) {
    return s
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }
}
