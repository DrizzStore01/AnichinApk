import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Satu opsi kualitas video yang bisa dipilih user (mis. "Full HD", "HD").
class OkRuQuality {
  final String label;
  final String url;

  OkRuQuality({required this.label, required this.url});
}

/// Hasil extract: SEMUA kualitas yang tersedia + header yang WAJIB dibawa
/// pas muter videonya (bukan cuma pas ambil embed page-nya doang). CDN
/// OK.ru punya proteksi hotlink — kalau request video/manifest-nya gak
/// bawa Referer & User-Agent yang bener, CDN bakal nolak (403) walau
/// url-nya valid.
class OkRuStream {
  /// Urutan dari yang paling direkomendasiin (HLS/Auto kalau ada, baru
  /// kualitas mp4 dari yang paling bagus).
  final List<OkRuQuality> qualities;
  final Map<String, String> headers;

  OkRuStream({required this.qualities, required this.headers});

  /// Kualitas yang dipakai pas pertama kali video dibuka.
  OkRuQuality get defaultQuality => qualities.first;
}

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

  /// Balikin [OkRuStream] (url + header wajib) — m3u8 kalau ada, kalau enggak
  /// ambil salah satu kualitas dari `videos`. Balikin null kalau gagal
  /// di-extract.
  ///
  /// Tiap langkah di-log pake debugPrint (prefix "[OkRu]"), keliatan di
  /// console `flutter run` buat gampang nge-debug kalau ada yang gagal.
  static Future<OkRuStream?> extractDirectUrl(String embedUrl) async {
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

    // Header ini WAJIB dibawa lagi pas request video/manifest-nya (bukan
    // cuma pas ambil HTML embed page). Tanpa ini, CDN OK.ru sering nolak
    // (403) walau url video-nya sendiri valid.
    final playbackHeaders = <String, String>{
      'User-Agent': _userAgent,
      'Referer': 'https://ok.ru/',
    };
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      // Ambil cuma nama=value-nya (bagian sebelum ';' pertama tiap cookie).
      playbackHeaders['Cookie'] = setCookie.split(',').map((c) {
        return c.split(';').first.trim();
      }).join('; ');
    }

    final html = response.body;

    // PENTING: halaman embed OK.ru biasanya punya LEBIH DARI SATU elemen yang
    // punya attribute data-options (ada widget lain selain video player).
    // Kalau kita cuma ambil match PERTAMA, sering kali yang ke-ambil itu
    // bukan JSON player (gak ada "flashvars" di dalemnya), jadi extract
    // gagal terus tanpa alasan yang jelas. Makanya di sini kita loop SEMUA
    // match, dan ambil yang JSON-nya beneran mengandung "flashvars".
    final allOptionsMatches =
        RegExp(r'data-options="([^"]*)"').allMatches(html).toList();
    if (allOptionsMatches.isEmpty) {
      debugPrint('[OkRu] regex data-options gak nemu match sama sekali. '
          'Kemungkinan HTML yang dibalikin beda (misal halaman blokir/captcha).');
      return null;
    }
    debugPrint('[OkRu] jumlah data-options ketemu: ${allOptionsMatches.length}');

    Map<String, dynamic>? player;
    for (final m in allOptionsMatches) {
      final raw = m.group(1)!;
      // Cek cepat sebelum decode JSON (masih ter-HTML-escape jadi &quot;
      // dsb, tapi kata "flashvars" tetep polos jadi aman di-cek).
      if (!raw.contains('flashvars')) continue;

      try {
        final decoded = json.decode(_htmlUnescape(raw)) as Map<String, dynamic>;
        if (decoded['flashvars'] is Map) {
          player = decoded;
          break;
        }
      } catch (e) {
        debugPrint('[OkRu] gagal decode salah satu data-options, skip: $e');
        continue;
      }
    }

    if (player == null) {
      debugPrint('[OkRu] gak ada data-options yang mengandung flashvars '
          'valid dari ${allOptionsMatches.length} kandidat.');
      return null;
    }
    debugPrint('[OkRu] player JSON (flashvars) berhasil di-decode. '
        'Keys: ${player.keys.toList()}');

    final flashvars = player['flashvars'] as Map<String, dynamic>;

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

    // Kumpulin SEMUA kualitas yang ada (bukan langsung pilih satu), biar
    // user bisa milih sendiri lewat UI quality picker.
    final qualities = <OkRuQuality>[];

    // HLS/Auto ditaruh paling atas (paling direkomendasiin, adaptive).
    final hlsUrl = metadata['hlsManifestUrl'];
    if (hlsUrl is String && hlsUrl.isNotEmpty) {
      debugPrint('[OkRu] hlsManifestUrl ketemu: $hlsUrl');
      qualities.add(OkRuQuality(label: 'Auto', url: hlsUrl));
    }

    final videos = (metadata['videos'] as List?) ?? [];
    debugPrint('[OkRu] jumlah videos (mp4): ${videos.length}');

    // Urutan kualitas dari yang paling bagus, sesuai nama yang dipake OK.ru.
    // Label-nya dibikin ala YouTube (angka resolusi), bukan nama internal
    // OK.ru — approx mapping yang umum dipakai extractor OK.ru lain.
    const preferredOrder = [
      'ultra',
      'quad',
      'full',
      'hd',
      'sd',
      'low',
      'lowest',
      'mobile',
    ];
    const labels = {
      'ultra': '2160p',
      'quad': '1440p',
      'full': '1080p',
      'hd': '720p',
      'sd': '480p',
      'low': '360p',
      'lowest': '240p',
      'mobile': '144p',
    };

    for (final name in preferredOrder) {
      final match = videos.cast<Map?>().firstWhere(
            (v) => v?['name'] == name,
            orElse: () => null,
          );
      if (match != null && match['url'] is String) {
        qualities.add(
          OkRuQuality(label: labels[name]!, url: match['url'] as String),
        );
      }
    }

    // Jaga-jaga: kalau ada video dengan nama yang gak dikenali (di luar
    // preferredOrder di atas), tetep dimasukin biar gak ke-skip diem-diem.
    for (final v in videos) {
      if (v is! Map || v['url'] is! String) continue;
      final url = v['url'] as String;
      if (qualities.any((q) => q.url == url)) continue;
      final name = v['name']?.toString() ?? 'Kualitas';
      qualities.add(OkRuQuality(label: labels[name] ?? name, url: url));
    }

    if (qualities.isEmpty) {
      debugPrint('[OkRu] gak ada hlsManifestUrl maupun videos yang valid.');
      return null;
    }

    debugPrint(
        '[OkRu] kualitas tersedia: ${qualities.map((q) => q.label).toList()}');
    return OkRuStream(qualities: qualities, headers: playbackHeaders);
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
