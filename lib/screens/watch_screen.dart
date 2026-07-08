import 'dart:async';
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
      showControls: true,
      // Custom controls sendiri (bukan bawaan Chewie) biar tampilannya
      // lebih niat: tombol play besar di tengah, seek ±10 detik, progress
      // bar custom, fullscreen toggle, double-tap buat seek, auto-hide.
      customControls: _CustomPlayerControls(
        qualities: _qualities,
        currentQuality: _currentQuality,
        onQualityTap: _showQualityPicker,
      ),
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
      return Chewie(controller: _chewieController!);
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

/// Custom controls buat Chewie — ganti total tampilan bawaan Chewie biar
/// keliatan lebih niat: tombol play/pause besar di tengah, skip ±10 detik,
/// progress bar custom, tombol fullscreen, chip kualitas, double-tap kiri
/// /kanan buat seek, dan auto-hide kontrol pas lagi muter.
class _CustomPlayerControls extends StatefulWidget {
  final List<OkRuQuality> qualities;
  final OkRuQuality? currentQuality;
  final VoidCallback onQualityTap;

  const _CustomPlayerControls({
    required this.qualities,
    required this.currentQuality,
    required this.onQualityTap,
  });

  @override
  State<_CustomPlayerControls> createState() => _CustomPlayerControlsState();
}

class _CustomPlayerControlsState extends State<_CustomPlayerControls> {
  bool _visible = true;
  Timer? _hideTimer;

  bool _showSeekBubbleLeft = false;
  bool _showSeekBubbleRight = false;
  Timer? _seekBubbleTimer;

  ChewieController get _chewie => ChewieController.of(context);
  VideoPlayerController get _video => _chewie.videoPlayerController;

  @override
  void initState() {
    super.initState();
    _video.addListener(_onVideoTick);
    _scheduleHide();
  }

  @override
  void dispose() {
    _video.removeListener(_onVideoTick);
    _hideTimer?.cancel();
    _seekBubbleTimer?.cancel();
    super.dispose();
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _video.value.isPlaying) {
        setState(() => _visible = false);
      }
    });
  }

  void _toggleVisible() {
    setState(() => _visible = !_visible);
    if (_visible) _scheduleHide();
  }

  void _togglePlay() {
    if (_video.value.isPlaying) {
      _video.pause();
      _hideTimer?.cancel();
    } else {
      _video.play();
      _scheduleHide();
    }
    setState(() {});
  }

  void _seekBy(Duration offset) {
    final pos = _video.value.position + offset;
    final dur = _video.value.duration;
    final target =
        pos < Duration.zero ? Duration.zero : (pos > dur ? dur : pos);
    _video.seekTo(target);
  }

  void _handleDoubleTap(TapDownDetails details, double width) {
    final isLeft = details.localPosition.dx < width / 2;
    _seekBy(Duration(seconds: isLeft ? -10 : 10));

    setState(() {
      _showSeekBubbleLeft = isLeft;
      _showSeekBubbleRight = !isLeft;
    });
    _seekBubbleTimer?.cancel();
    _seekBubbleTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _showSeekBubbleLeft = false;
        _showSeekBubbleRight = false;
      });
    });
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final value = _video.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleVisible,
          onDoubleTapDown: (d) => _handleDoubleTap(d, constraints.maxWidth),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (value.isBuffering)
                const Center(
                  child: CupertinoActivityIndicator(
                    color: Colors.white,
                    radius: 14,
                  ),
                ),
              if (_showSeekBubbleLeft)
                const Align(
                  alignment: Alignment(-0.5, 0),
                  child: _SeekBubble(icon: CupertinoIcons.gobackward_10),
                ),
              if (_showSeekBubbleRight)
                const Align(
                  alignment: Alignment(0.5, 0),
                  child: _SeekBubble(icon: CupertinoIcons.goforward_10),
                ),
              AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_visible,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.55),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.65),
                        ],
                        stops: const [0, 0.25, 0.7, 1],
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                          child: Row(
                            children: [
                              if (_chewie.isFullScreen)
                                IconButton(
                                  icon: const Icon(
                                    CupertinoIcons.chevron_back,
                                    color: Colors.white,
                                  ),
                                  onPressed: _chewie.toggleFullScreen,
                                ),
                              const Spacer(),
                              if (widget.qualities.length > 1)
                                GestureDetector(
                                  onTap: widget.onQualityTap,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white24,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          widget.currentQuality?.label ?? '',
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
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _CircleIconButton(
                              icon: CupertinoIcons.gobackward_10,
                              onTap: () =>
                                  _seekBy(const Duration(seconds: -10)),
                            ),
                            const SizedBox(width: 34),
                            _CircleIconButton(
                              icon: value.isPlaying
                                  ? CupertinoIcons.pause_fill
                                  : CupertinoIcons.play_fill,
                              size: 56,
                              iconSize: 28,
                              onTap: _togglePlay,
                            ),
                            const SizedBox(width: 34),
                            _CircleIconButton(
                              icon: CupertinoIcons.goforward_10,
                              onTap: () =>
                                  _seekBy(const Duration(seconds: 10)),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Row(
                            children: [
                              Text(
                                _fmt(value.position),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: VideoProgressIndicator(
                                  _video,
                                  allowScrubbing: true,
                                  padding: EdgeInsets.zero,
                                  colors: VideoProgressColors(
                                    playedColor: AppColors.accent,
                                    bufferedColor: Colors.white38,
                                    backgroundColor: Colors.white12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _fmt(value.duration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _chewie.toggleFullScreen,
                                child: Icon(
                                  _chewie.isFullScreen
                                      ? CupertinoIcons.fullscreen_exit
                                      : CupertinoIcons.fullscreen,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.4),
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}

class _SeekBubble extends StatelessWidget {
  final IconData icon;

  const _SeekBubble({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.5),
      ),
      child: Icon(icon, color: Colors.white, size: 30),
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
