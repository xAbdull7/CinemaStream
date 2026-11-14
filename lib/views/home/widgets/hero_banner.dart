import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/media_item.dart';

class HeroBanner extends StatefulWidget {
  final List<MediaItem> featuredItems;
  final ValueChanged<MediaItem> onPlay;
  final ValueChanged<MediaItem> onDetails;
  final ValueChanged<MediaItem> onToggleWatchlist;
  final bool Function(MediaItem) isInWatchlist;
  final bool isArabic;

  const HeroBanner({
    super.key,
    required this.featuredItems,
    required this.onPlay,
    required this.onDetails,
    required this.onToggleWatchlist,
    required this.isInWatchlist,
    required this.isArabic,
  });

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  @override
  void didUpdateWidget(HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.featuredItems.length != widget.featuredItems.length) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _autoScrollTimer?.cancel();
    if (widget.featuredItems.length <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        final nextIdx = (_currentIndex + 1) % widget.featuredItems.length;
        _pageController.animateToPage(
          nextIdx,
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onUserSlide(int index) {
    setState(() => _currentIndex = index);
    _startTimer(); // Reset auto-scroll on manual interaction
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bannerHeight = (screenHeight * 0.74).clamp(620.0, 780.0);

    if (widget.featuredItems.isEmpty) {
      return Container(
        height: bannerHeight,
        color: const Color(0xFF0D0D0E),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.movie_filter_rounded, size: 72, color: Colors.white24),
              const SizedBox(height: 18),
              Text(
                widget.isArabic
                    ? 'أضف مجلد الأفلام أو المسلسلات من الإعدادات للبدء'
                    : 'Add media folders from Settings to start watching',
                style: const TextStyle(fontSize: 18, color: Colors.white60, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    final totalItems = widget.featuredItems.length;

    return SizedBox(
      height: bannerHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Sliding PageView of Featured Backdrops (Bright, Cinematic & Radiant)
          PageView.builder(
            controller: _pageController,
            itemCount: totalItems,
            onPageChanged: _onUserSlide,
            itemBuilder: (context, index) {
              final item = widget.featuredItems[index];
              final imgUrl = item.backdropUrl ?? item.posterUrl;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Full-bleed High-Resolution Backdrop
                  if (imgUrl != null && imgUrl.isNotEmpty)
                    Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF141416)),
                    )
                  else
                    Container(color: const Color(0xFF141416)),

                  // Open, Air-filled Ambient Gradient Overlay (Preserves Backdrop Brightness)
                  // Bottom Gradient: Only deepens near the very bottom edge where sections meet
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const [0.0, 0.18, 0.55, 1.0],
                        colors: [
                          Colors.black,
                          Colors.black.withOpacity(0.75),
                          Colors.black.withOpacity(0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  // Side Gradient for crystal-clear readability behind title & synopsis
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: widget.isArabic ? Alignment.centerRight : Alignment.centerLeft,
                        end: widget.isArabic ? Alignment.centerLeft : Alignment.centerRight,
                        stops: const [0.0, 0.38, 0.72],
                        colors: [
                          Colors.black.withOpacity(0.78),
                          Colors.black.withOpacity(0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 1.5 Ambient Glow Bloom behind Title & Synopsis (Apple TV Style)
          Positioned(
            left: widget.isArabic ? null : 32,
            right: widget.isArabic ? 32 : null,
            bottom: 24,
            child: IgnorePointer(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.48,
                height: 340,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: widget.isArabic ? const Alignment(0.6, 0.3) : const Alignment(-0.6, 0.3),
                    radius: 0.95,
                    colors: [
                      const Color(0xFFE50914).withOpacity(0.09),
                      const Color(0xFF00E5FF).withOpacity(0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Information and CTA buttons for current slide
          Positioned(
            left: widget.isArabic ? null : 64,
            right: widget.isArabic ? 64 : null,
            bottom: 56,
            width: MediaQuery.of(context).size.width * 0.46,
            child: Builder(
              builder: (context) {
                final item = widget.featuredItems[_currentIndex.clamp(0, totalItems - 1)];
                final isBookmarked = widget.isInWatchlist(item);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title in Grand Luxury Typography
                    Text(
                      item.seriesTitle ?? item.title,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.8,
                        height: 1.1,
                        shadows: [
                          Shadow(offset: Offset(0, 4), blurRadius: 18, color: Colors.black87),
                          Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black54),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 16),

                    // Meta line: Liquid Glass Badges for Rating, Year, and Media Type
                    Row(
                      children: [
                        if (item.rating != null && item.rating! > 0) ...[
                          _buildLiquidGlassBadge(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 17),
                                const SizedBox(width: 5),
                                Text(
                                  '${item.rating!.toStringAsFixed(1)}/10',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (item.releaseYear != null && item.releaseYear!.isNotEmpty) ...[
                          _buildLiquidGlassBadge(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 13),
                                const SizedBox(width: 6),
                                Text(
                                  item.releaseYear!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        _buildLiquidGlassBadge(
                          child: Text(
                            item.type == MediaType.seriesEpisode
                                ? (widget.isArabic ? 'مسلسل' : 'Series')
                                : (widget.isArabic ? 'فيلم' : 'Movie'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Overview / Plot Summary with Luxurious Breathing Room
                    if (item.overview != null && item.overview!.isNotEmpty)
                      Text(
                        item.overview!,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.55,
                          letterSpacing: 0.25,
                          shadows: const [
                            Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black87),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 28),

                    // Liquid Glass Action Buttons Row: [ ▶ Play ] [ + My List ] [ ⓘ Details ]
                    Row(
                      children: [
                        // Primary Play Button (Solid Glossy White Pill)
                        ElevatedButton.icon(
                          onPressed: () => widget.onPlay(item),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 26),
                          label: Text(
                            item.hasResumePoint
                                ? (widget.isArabic ? 'استئناف المشاهدة' : 'Resume')
                                : (widget.isArabic ? 'تشغيل' : 'Play'),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Add to My List (+) Liquid Glass Circle Button
                        _buildLiquidGlassCircleButton(
                          icon: isBookmarked ? Icons.check_rounded : Icons.add_rounded,
                          color: isBookmarked ? AppColors.netflixRed : Colors.white,
                          tooltip: isBookmarked
                              ? (widget.isArabic ? 'في قائمتي' : 'In My List')
                              : (widget.isArabic ? 'إضافة إلى قائمتي' : 'Add to My List'),
                          onTap: () => widget.onToggleWatchlist(item),
                        ),

                        const SizedBox(width: 12),

                        // Details (ⓘ) Liquid Glass Circle Button
                        _buildLiquidGlassCircleButton(
                          icon: Icons.info_outline_rounded,
                          color: Colors.white,
                          tooltip: widget.isArabic ? 'مزيد من المعلومات' : 'More Info',
                          onTap: () => widget.onDetails(item),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          // 3. Carousel Dots Indicator on Right Edge (•••••••) with Liquid Glass Pill Capsule
          if (totalItems > 1)
            Positioned(
              right: widget.isArabic ? null : 64,
              left: widget.isArabic ? 64 : null,
              bottom: 64,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(totalItems, (i) {
                        final isCurrent = i == _currentIndex;
                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3.5),
                            height: 6,
                            width: isCurrent ? 24 : 6,
                            decoration: BoxDecoration(
                              color: isCurrent ? Colors.white : Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(color: Colors.white.withOpacity(0.4), blurRadius: 6),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiquidGlassBadge({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLiquidGlassCircleButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(26),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.25),
                      Colors.white.withOpacity(0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.28), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
