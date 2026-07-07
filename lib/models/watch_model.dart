class StreamingLink {
  final String server;
  final String link;

  StreamingLink({required this.server, required this.link});

  factory StreamingLink.fromJson(Map<String, dynamic> json) {
    return StreamingLink(
      server: json['server'] ?? '',
      link: json['link'] ?? '',
    );
  }

  /// True kalau nama server nandain ada iklan, misal "Rumble [Ads]".
  bool get hasAds => server.toLowerCase().contains('ads');

  /// Nama server tanpa embel-embel "[Ads]", buat ditampilin lebih rapi.
  String get displayName => server.replaceAll(RegExp(r'\s*\[.*?\]'), '').trim();
}

class DownloadHost {
  final String host;
  final String link;

  DownloadHost({required this.host, required this.link});

  factory DownloadHost.fromJson(Map<String, dynamic> json) {
    return DownloadHost(
      host: json['host'] ?? '',
      link: json['link'] ?? '',
    );
  }
}

class DownloadQuality {
  final String quality;
  final List<DownloadHost> links;

  DownloadQuality({required this.quality, required this.links});

  factory DownloadQuality.fromJson(Map<String, dynamic> json) {
    return DownloadQuality(
      quality: json['quality'] ?? '',
      links: (json['links'] as List? ?? [])
          .map((e) => DownloadHost.fromJson(e))
          .toList(),
    );
  }
}

class EpisodeNavigation {
  final String? prevEpisode;
  final String? allEpisodes;
  final String? nextEpisode;

  EpisodeNavigation({this.prevEpisode, this.allEpisodes, this.nextEpisode});

  factory EpisodeNavigation.fromJson(Map<String, dynamic> json) {
    return EpisodeNavigation(
      prevEpisode: json['prevEpisode'],
      allEpisodes: json['allEpisodes'],
      nextEpisode: json['nextEpisode'],
    );
  }
}

class WatchData {
  final String title;
  final String series;
  final String seriesUrl;
  final List<StreamingLink> streamingLinks;
  final List<DownloadQuality> downloadLinks;
  final EpisodeNavigation navigation;

  WatchData({
    required this.title,
    required this.series,
    required this.seriesUrl,
    required this.streamingLinks,
    required this.downloadLinks,
    required this.navigation,
  });

  factory WatchData.fromJson(Map<String, dynamic> json) {
    final result = json['result'] ?? {};
    return WatchData(
      title: result['title'] ?? '',
      series: result['series'] ?? '',
      seriesUrl: result['seriesUrl'] ?? '',
      streamingLinks: (result['streamingLinks'] as List? ?? [])
          .map((e) => StreamingLink.fromJson(e))
          .toList(),
      downloadLinks: (result['downloadLinks'] as List? ?? [])
          .map((e) => DownloadQuality.fromJson(e))
          .toList(),
      navigation: EpisodeNavigation.fromJson(result['navigation'] ?? {}),
    );
  }
}
