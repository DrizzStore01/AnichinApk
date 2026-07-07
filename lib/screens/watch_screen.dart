import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/watch_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class WatchScreen extends StatefulWidget {
  /// Url halaman episode di anichin.cafe.
  final String episodeUrl;

  const WatchScreen({super.key, required this.episodeUrl});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  final ApiService _apiService = ApiService();
  late Future<WatchData> _futureWatch;

  WebViewController? _playerController;
  int _selectedServerIndex = 0;
  String? _loadedLink;

  @override
  void initState() {
    super.initState();
    _futureWatch = _apiService.getStream(widget.episodeUrl);
  }

  void _loadServer(StreamingLink server, int index) {
    if (_loadedLink == server.link) return;

    _playerController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..loadRequest(Uri.parse(server.link));

    setState(() {
      _selectedServerIndex = index;
      _loadedLink = server.link;
    });
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _goToEpisode(String episodeUrl) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WatchScreen(episodeUrl: episodeUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
      ),
      body: FutureBuilder<WatchData>(
        future: _futureWatch,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CupertinoActivityIndicator(
                radius: 16,
                color: AppColors.textSecondary,
              ),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: '${snapshot.error}',
              onRetry: () {
                setState(() {
                  _futureWatch = _apiService.getStream(widget.episodeUrl);
                });
              },
            );
          }

          final data = snapshot.data!;

          if (_playerController == null && data.streamingLinks.isNotEmpty) {
            _loadServer(data.streamingLinks.first, 0);
          }

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _playerController != null
                    ? WebViewWidget(controller: _playerController!)
                    : Container(color: Colors.black),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.title, style: AppText.sectionTitle),
                    const SizedBox(height: 4),
                    Text(data.series, style: AppText.cardSubtitle),
                    const SizedBox(height: 18),
                    _EpisodeNavBar(
                      navigation: data.navigation,
                      onNavigate: _goToEpisode,
                    ),
                    const SizedBox(height: 20),
                    Text('Pilih Server', style: AppText.cardTitle),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: data.streamingLinks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final server = data.streamingLinks[index];
                    final isActive = index == _selectedServerIndex;
                    return GestureDetector(
                      onTap: () => _loadServer(server, index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.accent
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              server.displayName,
                              style: AppText.cardSubtitle.copyWith(
                                color: isActive
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (server.hasAds) ...[
                              const SizedBox(width: 4),
                              Icon(
                                CupertinoIcons.exclamationmark_circle,
                                size: 13,
                                color: isActive
                                    ? Colors.white70
                                    : AppColors.textSecondary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (data.downloadLinks.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text('Download', style: AppText.cardTitle),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: data.downloadLinks
                        .map((q) => _DownloadTile(
                              quality: q,
                              onTapHost: (link) => _openExternal(link),
                            ))
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _EpisodeNavBar extends StatelessWidget {
  final EpisodeNavigation navigation;
  final ValueChanged<String> onNavigate;

  const _EpisodeNavBar({required this.navigation, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NavButton(
            label: 'Sebelumnya',
            icon: CupertinoIcons.chevron_left,
            enabled: navigation.prevEpisode != null,
            onTap: () => onNavigate(navigation.prevEpisode!),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _NavButton(
            label: 'Selanjutnya',
            icon: CupertinoIcons.chevron_right,
            iconTrailing: true,
            enabled: navigation.nextEpisode != null,
            onTap: () => onNavigate(navigation.nextEpisode!),
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool iconTrailing;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.iconTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    final children = [
      if (!iconTrailing) Icon(icon, size: 16),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (iconTrailing) ...[
        const SizedBox(width: 6),
        Icon(icon, size: 16),
      ],
    ];

    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadQuality quality;
  final ValueChanged<String> onTapHost;

  const _DownloadTile({required this.quality, required this.onTapHost});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quality.quality, style: AppText.cardTitle),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quality.links
                .map(
                  (host) => GestureDetector(
                    onTap: () => onTapHost(host.link),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(host.host, style: AppText.cardSubtitle),
                          const SizedBox(width: 4),
                          const Icon(
                            CupertinoIcons.arrow_up_right_square,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

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
              decoration: const BoxDecoration(
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
