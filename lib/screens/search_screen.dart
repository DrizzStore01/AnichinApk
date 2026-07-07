import 'dart:async';
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
    setState(() {}); // buat refresh tombol clear (X)

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
      // Gagal load more -> diemin aja, jangan ganggu hasil yang udah ada di
      // layar. User tinggal scroll dikit lagi buat retry otomatis.
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        titleSpacing: 0,
        title: _buildSearchField(),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.search,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onQueryChanged,
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
          if (_controller.text.isNotEmpty)
            GestureDetector(
              onTap: _clear,
              behavior: HitTestBehavior.opaque,
              child: const Icon(
                CupertinoIcons.clear_circled_solid,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasSearched) {
      return const _MessageState(
        icon: CupertinoIcons.search,
        title: 'Cari anime favorit lu',
        subtitle: 'Ketik judulnya di kolom pencarian di atas.',
      );
    }

    if (_loading) {
      return const Center(
        child: CupertinoActivityIndicator(
          radius: 16,
          color: AppColors.textSecondary,
        ),
      );
    }

    if (_error != null) {
      return _MessageState(
        icon: CupertinoIcons.wifi_slash,
        title: 'Gagal memuat data',
        subtitle: _error!,
        onRetry: () => _search(_lastQuery),
      );
    }

    if (_results.isEmpty) {
      return const _MessageState(
        icon: CupertinoIcons.doc_text_search,
        title: 'Gak ketemu',
        subtitle: 'Coba kata kunci lain, mungkin ada typo.',
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 18,
        crossAxisSpacing: 12,
        childAspectRatio: 0.56,
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

/// State generik buat kondisi kosong/awal/error, biar konsisten sama
/// tampilan _ErrorState di screen lain.
class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

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
