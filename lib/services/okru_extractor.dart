import 'dart:convert';
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
  static Future<String?> extractDirectUrl(String embedUrl) async {
    final videoId = RegExp(r'(\d[\d-]*)/?$').firstMatch(embedUrl)?.group(1);
    if (videoId == null) return null;

    final response = await http.get(
      Uri.parse('https://ok.ru/videoembed/$videoId'),
      headers: {'User-Agent': _userAgent},
    );
    if (response.statusCode != 200) return null;

    final html = response.body;

    // Attribute-nya "data-options="{...semua di-HTML-escape...}"" — gak ada
    // tanda kutip mentah di dalem value-nya (semua udah jadi &quot;), jadi
    // aman diambil sekaligus sampe kutip penutup pertama.
    final optionsMatch =
        RegExp(r'data-options="([^"]*)"').firstMatch(html);
    if (optionsMatch == null) return null;

    Map<String, dynamic>? player;
    try {
      player = json.decode(_htmlUnescape(optionsMatch.group(1)!));
    } catch (_) {
      return null;
    }

    final flashvars = player?['flashvars'] as Map<String, dynamic>?;
    if (flashvars == null) return null;

    final metadataRaw = flashvars['metadata'];
    if (metadataRaw is! String) return null;

    Map<String, dynamic> metadata;
    try {
      metadata = json.decode(_htmlUnescape(metadataRaw));
    } catch (_) {
      return null;
    }

    // Prioritas: hlsManifestUrl (adaptive, paling stabil di video_player).
    final hlsUrl = metadata['hlsManifestUrl'];
    if (hlsUrl is String && hlsUrl.isNotEmpty) return hlsUrl;

    final videos = (metadata['videos'] as List?) ?? [];
    if (videos.isEmpty) return null;

    // Urutan kualitas dari yang paling bagus, sesuai nama yang dipake OK.ru.
    const preferredOrder = ['full', 'hd', 'sd', 'low', 'lowest', 'mobile'];
    for (final name in preferredOrder) {
      final match = videos.cast<Map?>().firstWhere(
            (v) => v?['name'] == name,
            orElse: () => null,
          );
      if (match != null && match['url'] is String) {
        return match['url'] as String;
      }
    }

    // Gak ketemu nama yang cocok, ambil aja yang terakhir (biasanya kualitas tertinggi).
    final fallback = videos.last;
    return fallback is Map && fallback['url'] is String
        ? fallback['url'] as String
        : null;
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
