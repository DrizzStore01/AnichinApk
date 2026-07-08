import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/watch_model.dart';
import '../services/api_service.dart';
import '../services/okru_extractor.dart';
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

  // WebView (dipake buat server selain OK.ru, atau kalau extract OK.ru gagal).
  WebViewController? _playerController;

  // Native player (dipake kalau berhasil extract direct url dari OK.ru).
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  int _selectedServerIndex = 0;
  String? _loadedLink;
  bool _isNative = false;
  bool _extracting = false;

  // Kualitas video yang tersedia buat server OK.ru yang lagi aktif, plus
  // header yang wajib dibawa tiap kali request video/manifest (Referer dsb).
  List<OkRuQuality> _qualities = [];
  OkRuQuality? _currentQuality;
  Map<String, String> _playbackHeaders = const {};

  @override
  void initState() {
    super.initState();
    _futureWatch = _apiService.getStream(widget.episodeUrl)
      ..then((data) {
        if (mounted && data.streamingLinks.isNotEmpty) {
          _loadServer(data.streamingLinks.first, 0);
        }
      });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _disposeNativePlayer() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  Future<void> _loadServer(StreamingLink server, int index) async {
    if (_loadedLink == server.link) return;

    _loadedLink = server.link;
    setState(() {
      _selectedServerIndex = index;
      _isNative = false;
      _qualities = [];
      _currentQuality = null;
      _extracting = OkRuExtractor.isOkRuLink(server.link);
    });

    if (OkRuExtractor.isOkRuLink(server.link)) {
      OkRuStream? stream;
      try {
        stream = await OkRuExtractor.extractDirectUrl(server.link);
      } catch (e) {
        debugPrint('[Watch] extractDirectUrl throw exception: $e');
        stream = null;
      }

      // Kalau user udah pindah server lagi sebelum extract selesai, batalin.
      if (_loadedLink != server.link || !mounted) return;

      if (stream != null) {
        _disposeNativePlayer();
        _playbackHeaders = stream.headers;

        final quality = stream.defaultQuality;
        // PENTING: httpHeaders wajib dikirim juga pas request video/manifest
        // -nya (bukan cuma pas ambil embed page). Tanpa Referer & User-Agent
        // yang bener, CDN OK.ru nolak request-nya (403) dan initialize()
        // bakal gagal walau url-nya sendiri valid.
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(quality.url),
          httpHeaders: _playbackHeaders,
        );
        try {
          await controller.initialize();
        } catch (e) {
          debugPrint('[Watch] native player initialize() gagal: $e');
          controller.dispose();
          _loadWebView(server.link);
          return;
        }

        if (_loadedLink != server.link || !mounted) return;

        _videoController = controller;
        _chewieController = _buildChewieController(controller, autoPlay: true);

        setState(() {
          _isNative = true;
          _extracting = false;
          _qualities = stream!.qualities;
          _currentQuality = quality;
        });
        return;
      }
    }

    // Bukan OK.ru, atau extract gagal -> fallback ke WebView.
    if (!mounted || _loadedLink != server.link) return;
    _loadWebView(server.link);
  }

  /// Ganti kualitas video TANPA balik ke awal — posisi tonton & status
  /// play/pause dipertahanin (kayak ganti kualitas di YouTube).
  Future<void> _switchQuality(OkRuQuality quality) async {
    if (quality == _currentQuality || _videoController == null) return;

    final resumeAt = _videoController!.value.position;
    final wasPlaying = _videoController!.value.isPlaying;

    setState(() => _extracting = true);
    _disposeNativePlayer();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(quality.url),
      httpHeaders: _playbackHeaders,
    );

    try {
      await controller.initialize();
      await controller.seekTo(resumeAt);
    } catch (e) {
      debugPrint('[Watch] gagal ganti kualitas ke ${quality.label}: $e');
      controller.dispose();
      if (!mounted) return;
      setState(() => _extracting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ganti ke kualitas ${quality.label}')),
      );
      return;
    }

    if (!mounted) {
      controller.dispose();
      return;
    }

    _videoController = controller;
    _chewieController = _buildChewieController(controller, autoPlay: wasPlaying);

    setState(() {
      _currentQuality = quality;
      _extracting = false;
    });
  }

  ChewieController _buildChewieController(
    VideoPlayerController controller, {
    required bool autoPlay,
  }) {
    return ChewieController(
      videoPlayerController: controller,
      autoPlay: autoPlay,
      looping: false,
      allowFullScreen: true,
      // Layar gak mati sendiri pas lagi nonton.
      allowedScreenSleep: false,
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.accent,
        handleColor: AppColors.accent,
        bufferedColor: Colors.white24,
      ),
      optionsTranslation: OptionsTranslation(
        playbackSpeedButtonText: 'Kecepatan Putar',
        subtitlesButtonText: 'Subtitle',
        cancelButtonText: 'Batal',
      ),
      additionalOptions: (context) {
        if (_qualities.length <= 1) return [];
        return [
          OptionItem(
            onTap: (ctx) {
              Navigator.of(ctx).pop();
              _showQualityPicker();
            },
            iconData: Icons.high_quality_outlined,
            title: 'Kualitas (${_currentQuality?.label ?? '-'})',
          ),
        ];
      },
      errorBuilder: (context, errorMessage) {
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: Colors.white70,
                size: 30,
              ),
              const SizedBox(height: 10),
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQualityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Pilih Kualitas', style: AppText.cardTitle),
                ),
              ),
              ..._qualities.map((q) {
                final selected = q == _currentQuality;
                return ListTile(
                  title: Text(
                    q.label,
                    style: AppText.cardTitle.copyWith(
                      color: selected ? AppColors.accent : null,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(CupertinoIcons.checkmark_alt,
                          color: AppColors.accent)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _switchQuality(q);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _loadWebView(String link) {
    _disposeNativePlayer();
    _playerController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..loadRequest(Uri.parse(link));

    setState(() {
      _isNative = false;
      _extracting = false;
      _qualities = [];
      _currentQuality = null;
    });
  }

  Widget _buildPlayerArea() {
    if (_extracting) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(color: Colors.white, radius: 14),
            SizedBox(height: 10),
            Text(
              'Menyiapkan video...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_isNative && _chewieController != null) {
      return Stack(
        children: [
          Positioned.fill(child: Chewie(controller: _chewieController!)),
          if (_qualities.length > 1)
            Positioned(
              top: 10,
              right: 10,
              child: _QualityChip(
                label: _currentQuality?.label ?? '',
                onTap: _showQualityPicker,
              ),
            ),
        ],
      );
    }

    if (_playerController != null) {
      return WebViewWidget(controller: _playerController!);
    }

    return Container(color: Colors.black);
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
                  _futureWatch = _apiService.getStream(widget.episodeUrl)
                    ..then((data) {
                      if (mounted && data.streamingLinks.isNotEmpty) {
                        _loadServer(data.streamingLinks.first, 0);
                      }
                    });
                });
              },
            );
          }

          final data = snapshot.data!;

          return Column(
            children: [
              // Player gak ikut ke-scroll, posisinya fix di atas.
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildPlayerArea(),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
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
                          _ServerDropdown(
                            servers: data.streamingLinks,
                            selectedIndex: _selectedServerIndex,
                            onChanged: _loadServer,
                          ),
                        ],
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ServerDropdown extends StatelessWidget {
  final List<StreamingLink> servers;
  final int selectedIndex;
  final void Function(StreamingLink server, int index) onChanged;

  const _ServerDropdown({
    required this.servers,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedIndex,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          icon: const Icon(
            CupertinoIcons.chevron_down,
            size: 16,
            color: AppColors.textSecondary,
          ),
          borderRadius: BorderRadius.circular(12),
          items: List.generate(servers.length, (index) {
            final server = servers[index];
            return DropdownMenuItem<int>(
              value: index,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    server.displayName,
                    style: AppText.cardTitle,
                  ),
                  if (server.hasAds) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      CupertinoIcons.exclamationmark_circle,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
            );
          }),
          onChanged: (index) {
            if (index == null) return;
            onChanged(servers[index], index);
          },
        ),
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
      width: double.infinity,
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
          ...quality.links.map(
            (host) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onTapHost(host.link),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(host.host, style: AppText.cardTitle),
                      ),
                      const Icon(
                        CupertinoIcons.arrow_up_right_square,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QualityChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              CupertinoIcons.chevron_down,
              size: 12,
              color: Colors.white70,
            ),
          ],
        ),
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
