import 'package:flutter/material.dart';
import '../models/home_model.dart';
import '../services/api_service.dart';
import '../widgets/anime_card_widget.dart';
import '../widgets/featured_slider.dart';

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
    setState(() {
      _futureHome = _apiService.getHome();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anichin'),
        centerTitle: false,
      ),
      body: FutureBuilder<HomeData>(
        future: _futureHome,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Gagal load data:\n${snapshot.error}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // ---- Featured Slider ----
                if (data.featuredSlider.isNotEmpty)
                  FeaturedSlider(
                    items: data.featuredSlider,
                    onTap: (item) {
                      // TODO: navigate ke detail page pakai item.url
                    },
                  ),

                const SizedBox(height: 16),

                // ---- Popular Today ----
                _SectionTitle(title: 'Popular Today'),
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: data.popularToday.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final anime = data.popularToday[index];
                      return AnimeCardWidget(
                        anime: anime,
                        onTap: () {
                          // TODO: navigate ke detail page pakai anime.url
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // ---- Latest Releases (grid) ----
                _SectionTitle(title: 'Latest Releases'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: data.latestReleases.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.55,
                  ),
                  itemBuilder: (context, index) {
                    final anime = data.latestReleases[index];
                    return AnimeCardWidget(
                      anime: anime,
                      onTap: () {
                        // TODO: navigate ke detail page pakai anime.url
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
