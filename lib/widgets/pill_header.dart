import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PillHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final VoidCallback onSearchTap;

  /// True kalau lagi discroll -> pill nyusut ke kiri, cuma nampilin nama
  /// "Anichin" doang (ikon search disembunyiin). False kalau lagi diem ->
  /// balik ke lebar normal (nama + ikon search).
  final bool isCompact;

  PillHeaderDelegate({
    required this.topPadding,
    required this.onSearchTap,
    this.isCompact = false,
  });

  static const double _barHeight = 52;
  static const double _verticalMargin = 8;
  static const double _compactWidth = 132;
  static const Duration _duration = Duration(milliseconds: 320);
  static const Curve _curve = Curves.easeOutCubic;

  @override
  double get minExtent => topPadding + _barHeight + (_verticalMargin * 2);

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      // Transparan, biar konten yang di-scroll lewat di baliknya
      // beneran ke-blur sama BackdropFilter (efek glass yang asli).
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        16,
        topPadding + _verticalMargin,
        16,
        _verticalMargin,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fullWidth = constraints.maxWidth;

          return AnimatedAlign(
            duration: _duration,
            curve: _curve,
            alignment: isCompact ? Alignment.centerLeft : Alignment.center,
            child: AnimatedContainer(
              duration: _duration,
              curve: _curve,
              width: isCompact ? _compactWidth : fullWidth,
              height: _barHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_barHeight / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_barHeight / 2),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(_barHeight / 2),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Anichin', style: AppText.navTitle),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: isCompact ? 0 : 1,
                          child: IgnorePointer(
                            ignoring: isCompact,
                            child: GestureDetector(
                              onTap: onSearchTap,
                              behavior: HitTestBehavior.opaque,
                              child: const Hero(
                                tag: 'anichin-search-bar',
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: Icon(
                                    CupertinoIcons.search,
                                    color: AppColors.accent,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant PillHeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding ||
        oldDelegate.isCompact != isCompact;
  }
}
