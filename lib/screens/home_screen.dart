import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/home_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/anime_card_widget.dart';
import '../widgets/featured_slider.dart';
import '../widgets/pill_header.dart';
import '../widgets/section_header.dart';
import 'detail_screen.dart';
import 'search_screen.dart';
import 'watch_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  late Future<HomeData> _futureHome;

  @override
  void initState() {
    super.initState();
    _futureHome = _apiService.getHome();
  }

  Future<void> _refresh() async {
    final future = _apiService.getHome();
    setState(() => _futureHome = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<HomeData>(
        future: _futureHome,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingState();
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: '${snapshot.error}',
              onRetry: _refresh,
            );
          }

          final data = snapshot.data!;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: PillHeaderDelegate(
                  topPadding: MediaQuery.of(context).padding.top,
                  onSearchTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                ),
              ),
              CupertinoSliverRefreshControl(onRefresh: _refresh),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FeaturedSlider(
                    items: data.featuredSlider,
                    onTap: (item) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(animeUrl: item.url),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: SectionHeader(
                    title: 'Popular Today',
                    onSeeAll: () {
                      // TODO: navigate ke halaman list lengkap
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: data.popularToday.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final anime = data.popularToday[index];
                      return SizedBox(
                        width: 128,
                        child: AnimeCardWidget(
                          anime: anime,
                          titleInsideCard: true,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    WatchScreen(episodeUrl: anime.url),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: SectionHeader(
                    title: 'Latest Releases',
                    onSeeAll: () {
                      // TODO: navigate ke halaman list lengkap
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 12,
                    // Dihitung dinamis (bukan angka hardcode) biar tinggi
                    // cell SELALU muat poster + judul 2 baris + subtitle,
                    // gak peduli seberapa lebar layarnya. Kalau
                    // childAspectRatio-nya kekecilan tinggi (angka gede),
                    // teksnya numpuk ke row di bawahnya.
                    childAspectRatio: AnimeCardWidget.gridAspectRatio(
                      context,
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      horizontalPadding: 40,
                    ),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final anime = data.latestReleases[index];
                      return AnimeCardWidget(
                        anime: anime,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  WatchScreen(episodeUrl: anime.url),
                            ),
                          );
                        },
                      );
                    },
                    childCount: data.latestReleases.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CupertinoActivityIndicator(
        radius: 16,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.wifi_slash,
                color: AppColors.accent,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat data',
              style: AppText.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppText.cardSubtitle,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            CupertinoButton(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
              onPressed: onRetry,
              child: const Text(
                'Coba Lagi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
