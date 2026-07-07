class DetailMetadata {
  final String? status;
  final String? network;
  final String? studio;
  final String? released;
  final String? duration;
  final String? season;
  final String? country;
  final String? type;
  final String? episodes;
  final String? fansub;

  DetailMetadata({
    this.status,
    this.network,
    this.studio,
    this.released,
    this.duration,
    this.season,
    this.country,
    this.type,
    this.episodes,
    this.fansub,
  });

  factory DetailMetadata.fromJson(Map<String, dynamic> json) {
    return DetailMetadata(
      status: json['status'],
      network: json['network'],
      studio: json['studio'],
      released: json['released'],
      duration: json['duration'],
      season: json['season'],
      country: json['country'],
      type: json['type'],
      episodes: json['episodes'],
      fansub: json['fansub'],
    );
  }
}

class DetailEpisode {
  final String episode;
  final String title;
  final String date;
  final String url;

  DetailEpisode({
    required this.episode,
    required this.title,
    required this.date,
    required this.url,
  });

  factory DetailEpisode.fromJson(Map<String, dynamic> json) {
    return DetailEpisode(
      episode: (json['episode'] ?? '').toString(),
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

class DetailData {
  final String title;
  final String alternativeTitle;
  final String thumbnail;
  final String rating;
  final String synopsis;
  final DetailMetadata metadata;
  final List<String> genres;
  final List<DetailEpisode> episodeList;

  DetailData({
    required this.title,
    required this.alternativeTitle,
    required this.thumbnail,
    required this.rating,
    required this.synopsis,
    required this.metadata,
    required this.genres,
    required this.episodeList,
  });

  factory DetailData.fromJson(Map<String, dynamic> json) {
    final result = json['result'] ?? {};
    return DetailData(
      title: result['title'] ?? '',
      alternativeTitle: result['alternativeTitle'] ?? '',
      thumbnail: result['thumbnail'] ?? '',
      rating: (result['rating'] ?? '').toString(),
      synopsis: result['synopsis'] ?? '',
      metadata: DetailMetadata.fromJson(result['metadata'] ?? {}),
      genres: (result['genres'] as List? ?? []).map((e) => e.toString()).toList(),
      episodeList: (result['episodeList'] as List? ?? [])
          .map((e) => DetailEpisode.fromJson(e))
          .toList(),
    );
  }
}
