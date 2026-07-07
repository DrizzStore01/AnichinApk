class FeaturedItem {
  final String title;
  final String url;
  final String thumbnail;
  final String description;

  FeaturedItem({
    required this.title,
    required this.url,
    required this.thumbnail,
    required this.description,
  });

  factory FeaturedItem.fromJson(Map<String, dynamic> json) {
    return FeaturedItem(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class AnimeCard {
  final String title;
  final String? episode;
  final String? type;
  final String url;
  final String thumbnail;
  final String? status;

  AnimeCard({
    required this.title,
    this.episode,
    this.type,
    required this.url,
    required this.thumbnail,
    this.status,
  });

  factory AnimeCard.fromJson(Map<String, dynamic> json) {
    return AnimeCard(
      // title di API sering nempel sama nama episode, ambil bagian sebelum tab/duplikat
      title: (json['title'] ?? '').toString().split('\t').first.trim(),
      episode: json['episode'],
      type: json['type'],
      url: json['url'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      status: json['status'],
    );
  }
}

class SidebarItem {
  final String title;
  final String episode;
  final String url;

  SidebarItem({
    required this.title,
    required this.episode,
    required this.url,
  });

  factory SidebarItem.fromJson(Map<String, dynamic> json) {
    return SidebarItem(
      title: json['title'] ?? '',
      episode: json['episode'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

class HomeData {
  final List<FeaturedItem> featuredSlider;
  final List<AnimeCard> popularToday;
  final List<AnimeCard> latestReleases;
  final List<SidebarItem> ongoingSidebar;

  HomeData({
    required this.featuredSlider,
    required this.popularToday,
    required this.latestReleases,
    required this.ongoingSidebar,
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    final result = json['result'] ?? {};
    return HomeData(
      featuredSlider: (result['featuredSlider'] as List? ?? [])
          .map((e) => FeaturedItem.fromJson(e))
          .toList(),
      popularToday: (result['popularToday'] as List? ?? [])
          .map((e) => AnimeCard.fromJson(e))
          .toList(),
      latestReleases: (result['latestReleases'] as List? ?? [])
          .map((e) => AnimeCard.fromJson(e))
          .toList(),
      ongoingSidebar: (result['ongoingSidebar'] as List? ?? [])
          .map((e) => SidebarItem.fromJson(e))
          .toList(),
    );
  }
}
