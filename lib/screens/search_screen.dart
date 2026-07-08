import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/home_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/anime_card_widget.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;

  // Buat nolak response API yang "telat" nyampe (misal user udah ganti
  // query lain sebelum response query sebelumnya balik).
  int _requestId = 0;

  List<AnimeCard> _results = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasNextPage = false;
  int _currentPage = 1;
  String? _error;
  bool _hasSearched = false;
  String _lastQuery = '';

  // Ukuran floating bar (back button + search field), dipakai buat nentuin
  // padding atas konten biar gak ketutup.
  static const double _barHeight = 44;
  static const double _barTopMargin = 8;
  static const double _contentGapAfterBar = 14;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasNextPage || _loadingMore || _loading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {}); // refresh tombol clear (X)

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _error = null;
        _loading = false;
        _hasNextPage = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search(trimmed);
    });
  }

  Future<void> _search(String query) async {
    final int myRequestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _hasSearched = true;
      _lastQuery = query;
    });

    try {
      final data = await _apiService.search(query, page: 1);
      if (myRequestId != _requestId || !mounted) return;

      setState(() {
        _results = data.data;
        _currentPage = data.currentPage;
        _hasNextPage = data.hasNextPage;
        _loading = false;
      });
    } catch (e) {
      if (myRequestId != _requestId || !mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final int myRequestId = _requestId;
    final nextPage = _currentPage + 1;
    setState(() => _loadingMore = true);

    try {
      final data = await _apiService.search(_lastQuery, page: nextPage);
      if (myRequestId != _requestId || !mounted) return;

      setState(() {
        _results = [..._results, ...data.data];
        _currentPage = data.currentPage;
        _hasNextPage = data.hasNextPage;
        _loadingMore = false;
      });
    } catch (_) {
      // Gagal load more -> diemin aja, jangan ganggu hasil yang udah ada.
      if (myRequestId != _requestId || !mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() {
      _results = [];
      _hasSearched = false;
      _error = null;
      _loading = false;
      _hasNextPage = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final contentTopPadding =
        topPadding + _barTopMargin + _barHeight + _contentGapAfterBar;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Konten di-scroll DI BALIK floating bar (biar keliatan efek
          // blur/glass-nya kayak di home).
          Positioned.fill(
            child: _buildBody(contentTopPadding),
          ),

          // Floating back button + search bar.
          Positioned(
            top: topPadding + _barTopMargin,
            left: 16,
            right: 16,
            height: _barHeight,
            child: Row(
              children: [
                _FloatingGlassButton(
                  size: _barHeight,
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    CupertinoIcons.back,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Hero(
                    tag: 'anichin-search-bar',
                    child: Material(
                      type: MaterialType.transparency,
                      child: _FloatingSearchField(
                        height: _barHeight,
                        controller: _controller,
                        onChanged: _onQueryChanged,
                        onClear: _clear,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(double contentTopPadding) {
    if (!_hasSearched) {
      return _MessageState(
        icon: CupertinoIcons.search,
        title: 'Cari anime favorit lu',
        subtitle: 'Ketik judulnya di kolom pencarian di atas.',
        topPadding: contentTopPadding,
      );
    }

    if (_loading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: contentTopPadding),
          child: const CupertinoActivityIndicator(
            radius: 16,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    if (_error != null) {
      return _MessageState(
        icon: CupertinoIcons.wifi_slash,
        title: 'Gagal memuat data',
        subtitle: _error!,
        onRetry: () => _search(_lastQuery),
        topPadding: contentTopPadding,
      );
    }

    if (_results.isEmpty) {
      return _MessageState(
        icon: CupertinoIcons.doc_text_search,
        title: 'Gak ketemu',
        subtitle: 'Coba kata kunci lain, mungkin ada typo.',
        topPadding: contentTopPadding,
      );
    }

    const crossAxisCount = 3;
    const crossAxisSpacing = 12.0;

    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(20, contentTopPadding, 20, 32),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 18,
        crossAxisSpacing: crossAxisSpacing,
        // Dihitung dinamis biar poster + judul 2 baris + subtitle SELALU
        // muat di dalam cell, gak numpuk ke row bawahnya.
        childAspectRatio: AnimeCardWidget.gridAspectRatio(
          context,
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          horizontalPadding: 40,
        ),
      ),
      itemCount: _results.length + (_hasNextPage ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CupertinoActivityIndicator(
                radius: 12,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final anime = _results[index];
        return AnimeCardWidget(
          anime: anime,
          onTap: () {
            // Hasil search ngarah ke halaman seri, bukan episode langsung.
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DetailScreen(animeUrl: anime.url),
              ),
            );
          },
        );
      },
    );
  }
}

/// Tombol bulat gaya "glass" (blur + surface transparan), dipakai buat
/// tombol back floating — biar konsisten sama estetika PillHeaderDelegate
/// di home.
class _FloatingGlassButton extends StatelessWidget {
  final double size;
  final VoidCallback onTap;
  final Widget child;

  const _FloatingGlassButton({
    required this.size,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.75),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Search field floating gaya "glass", dipakai buat Hero target dari home.
class _FloatingSearchField extends StatelessWidget {
  final double height;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _FloatingSearchField({
    required this.height,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.75),
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.search,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: onChanged,
                    style: AppText.cardTitle,
                    cursorColor: AppColors.accent,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Cari judul anime...',
                      hintStyle: AppText.cardSubtitle,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: onClear,
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(
                        CupertinoIcons.clear_circled_solid,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// State generik buat kondisi kosong/awal/error.
class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  final double topPadding;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.topPadding,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, topPadding, 32, 32),
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
              child: Icon(icon, color: AppColors.accent, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppText.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppText.cardSubtitle,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
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
          ],
        ),
      ),
    );
  }
}
