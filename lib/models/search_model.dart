import 'home_model.dart';

/// Wrapper hasil `/search`. List item-nya reuse `AnimeCard` dari home_model
/// soalnya field-nya sama persis (title, url, thumbnail, type, status,
/// episode) — cuma nambah `sub` yang udah ditambahin ke AnimeCard.
class SearchData {
  final String searchQuery;
  final int currentPage;
  final int totalResults;
  final bool hasNextPage;
  final List<AnimeCard> data;

  SearchData({
    required this.searchQuery,
    required this.currentPage,
    required this.totalResults,
    required this.hasNextPage,
    required this.data,
  });

  factory SearchData.fromJson(Map<String, dynamic> json) {
    final result = json['result'] ?? {};
    return SearchData(
      searchQuery: result['searchQuery'] ?? '',
      currentPage: int.tryParse('${result['currentPage']}') ?? 1,
      totalResults: int.tryParse('${result['totalResults']}') ?? 0,
      hasNextPage: result['hasNextPage'] == true,
      data: (result['data'] as List? ?? [])
          .map((e) => AnimeCard.fromJson(e))
          .toList(),
    );
  }
}
