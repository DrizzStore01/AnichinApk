import 'package:flutter/material.dart';
import '../models/home_model.dart';
import '../theme/app_theme.dart';

class AnimeCardWidget extends StatelessWidget {
  final AnimeCard anime;
  final VoidCallback onTap;

  /// Kalau true: judul & tipe ditampilkan sebagai overlay DI DALAM card
  /// (dipakai di section "Popular Today"). Kalau false: judul ditampilkan
  /// sebagai teks biasa DI BAWAH card (dipakai di "Latest Releases").
  final bool titleInsideCard;

  const AnimeCardWidget({
    super.key,
    required this.anime,
    required this.onTap,
    this.titleInsideCard = false,
  });

  /// Ngitung `childAspectRatio` yang AMAN buat grid yang isinya card ini
  /// (varian `titleInsideCard: false`, judul+subtitle DI BAWAH poster).
  ///
  /// PENTING: jangan hardcode childAspectRatio kayak sebelumnya (0.56),
  /// soalnya itu gak ngitung tinggi asli konten (poster + judul 2 baris +
  /// subtitle). Kalau cell grid-nya lebih pendek dari tinggi asli konten,
  /// hasilnya numpuk/overlap ke row di bawahnya pas judulnya panjang.
  /// Fungsi ini itung tinggi yang beneran dibutuhin berdasarkan lebar
  /// card aktual, jadi selalu pas di semua ukuran layar.
  static double gridAspectRatio(
    BuildContext context, {
    required int crossAxisCount,
    required double crossAxisSpacing,
    required double horizontalPadding,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
    final itemWidth =
        (screenWidth - horizontalPadding - totalSpacing) / crossAxisCount;

    // Poster pakai aspect ratio 2:3 (lihat AspectRatio di bawah).
    final posterHeight = itemWidth * 3 / 2;

    // Tinggi teks di bawah poster: gap(8) + judul 2 baris (cardTitle
    // fontSize 13 x height 1.25 x 2 baris) + gap(2) + subtitle (cardSubtitle
    // fontSize 11.5) + sedikit buffer pengaman.
    const textBlockHeight = 8.0 + (13 * 1.25 * 2) + 2.0 + 16.0 + 6.0;

    final itemHeight = posterHeight + textBlockHeight;
    return itemWidth / itemHeight;
  }

  @override
  Widget build(BuildContext context) {
    final poster = AspectRatio(
      aspectRatio: 2 / 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                anime.thumbnail,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(color: AppColors.surface);
                },
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surface,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),

              // Judul di dalam card (khusus Popular Today)
              if (titleInsideCard)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          anime.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.cardTitle,
                        ),
                        if (anime.type != null) ...[
                          const SizedBox(height: 2),
                          Text(anime.type!, style: AppText.cardSubtitle),
                        ],
                      ],
                    ),
                  ),
                ),

              // Badge episode — kanan atas
              if (anime.episode != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(anime.episode!, style: AppText.badge),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: titleInsideCard
          ? poster
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                poster,
                const SizedBox(height: 8),
                Text(
                  anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle,
                ),
                if (anime.type != null) ...[
                  const SizedBox(height: 2),
                  Text(anime.type!, style: AppText.cardSubtitle),
                ],
              ],
            ),
    );
  }
}
