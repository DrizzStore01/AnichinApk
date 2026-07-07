import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/detail_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'watch_screen.dart';

class DetailScreen extends StatefulWidget {
  /// Url halaman seri di anichin.cafe (bukan url episode).
  final String animeUrl;

  const DetailScreen({super.key, required this.animeUrl});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final ApiService _apiService = ApiService();
  late Future<DetailData> _futureDetail;
  bool _synopsisExpanded = false;

  @override
  void initState() {
    super.initState();
    _futureDetail = _apiService.getDetail(widget.animeUrl);
  }

  Future<void> _refresh() async {
    final future = _apiService.getDetail(widget.animeUrl);
    setState(() => _futureDetail = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<DetailData>(
        future: _futureDetail,
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
              _DetailHeader(data: data),
              CupertinoSliverRefreshControl(onRefresh: _refresh),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 70, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.title, style: AppText.sectionTitle),
                      if (data.alternativeTitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          data.alternativeTitle,
                          style: AppText.cardSubtitle,
                        ),
                      ],
                      const SizedBox(height: 14),
                      _MetaRow(metadata: data.metadata, rating: data.rating),
                      if (data.genres.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: data.genres
                              .map((g) => _GenreChip(label: g))
                              .toList(),
                        ),
                      ],
                      if (data.synopsis.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('Sinopsis', style: AppText.cardTitle),
                        const SizedBox(height: 8),
                        Text(
                          data.synopsis,
                          style: AppText.cardSubtitle.copyWith(height: 1.5),
                          maxLines: _synopsisExpanded ? null : 4,
                          overflow: _synopsisExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => setState(
                            () => _synopsisExpanded = !_synopsisExpanded,
                          ),
                          child: Text(
                            _synopsisExpanded
                                ? 'Tutup'
                                : 'Baca selengkapnya',
                            style: AppText.sectionAction,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Daftar Episode', style: AppText.cardTitle),
                          Text(
                            '${data.episodeList.length} episode',
                            style: AppText.cardSubtitle,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final ep = data.episodeList[index];
                      return _EpisodeTile(
                        episode: ep,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  WatchScreen(episodeUrl: ep.url),
                            ),
                          );
                        },
                      );
                    },
                    childCount: data.episodeList.length,
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

class _DetailHeader extends StatelessWidget {
  final DetailData data;

  const _DetailHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return SliverToBoxAdapter(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Backdrop blur dari poster, biar ada kedalaman di belakang tombol back.
          SizedBox(
            height: 260,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  data.thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: AppColors.surface),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.background.withOpacity(0.2),
                        AppColors.background,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: topPadding + 8,
            left: 12,
            child: _BackButton(),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: -60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _PosterThumb(url: data.thumbnail),
                if (data.rating.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RatingBadge(rating: data.rating),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterThumb extends StatelessWidget {
  final String url;

  const _PosterThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 152,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.background, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: AppColors.surface),
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final String rating;

  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.star_fill, color: Colors.amber, size: 14),
          const SizedBox(width: 4),
          Text(rating, style: AppText.cardTitle),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          CupertinoIcons.back,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final DetailMetadata metadata;
  final String rating;

  const _MetaRow({required this.metadata, required this.rating});

  @override
  Widget build(BuildContext context) {
    // Kasih jarak ekstra di kiri biar teks gak ketiban poster yang overlap.
    final parts = <String>[
      if (metadata.type != null) metadata.type!,
      if (metadata.status != null) metadata.status!,
      if (metadata.episodes != null) '${metadata.episodes} eps',
      if (metadata.duration != null) metadata.duration!,
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 122),
      child: Text(
        parts.join(' · '),
        style: AppText.cardSubtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;

  const _GenreChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        label,
        style: AppText.cardSubtitle.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final DetailEpisode episode;
  final VoidCallback onTap;

  const _EpisodeTile({required this.episode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                episode.episode,
                style: AppText.cardTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    style: AppText.cardTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(episode.date, style: AppText.cardSubtitle),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.play_circle_fill,
              color: AppColors.accent,
              size: 26,
            ),
          ],
        ),
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
