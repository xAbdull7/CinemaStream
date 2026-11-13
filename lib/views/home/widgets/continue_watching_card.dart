import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/media_item.dart';

class ContinueWatchingCard extends StatefulWidget {
  final MediaItem item;
  final bool isEditMode;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onMarkWatched;
  final bool isArabic;

  const ContinueWatchingCard({
    super.key,
    required this.item,
    required this.isEditMode,
    required this.onTap,
    required this.onRemove,
    required this.onMarkWatched,
    required this.isArabic,
  });

  @override
  State<ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<ContinueWatchingCard> {
  bool _isHovered = false;

  String _formatTimeLeft(MediaItem item) {
    if (item.durationSeconds <= 0) return '';
    final secondsLeft = item.durationSeconds - item.stoppedAtSeconds;
    final mins = (secondsLeft / 60).clamp(1, 999).round();
    if (mins >= 60) {
      final hours = (mins / 60).floor();
      final remMins = mins % 60;
      return widget.isArabic ? 'متبقي $hours س $remMins د' : '${hours}h ${remMins}m left';
    }
    return widget.isArabic ? 'متبقي $mins د' : '${mins}m left';
  }

  String _buildSubtitle(MediaItem item) {
    final parts = <String>[];
    if (item.seasonNumber != null && item.episodeNumber != null) {
      final s = item.seasonNumber.toString().padLeft(2, '0');
      final e = item.episodeNumber.toString().padLeft(2, '0');
      parts.add('S$s:E$e');
    }
    final timeLeft = _formatTimeLeft(item);
    if (timeLeft.isNotEmpty) {
      parts.add(timeLeft);
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final imgUrl = (item.backdropUrl != null && item.backdropUrl!.isNotEmpty)
        ? item.backdropUrl!
        : (item.posterUrl != null && item.posterUrl!.isNotEmpty)
            ? item.posterUrl!
            : null;

    final progress = item.progressPercentage;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 350,
          transform: _isHovered ? Matrix4.translationValues(0.0, -6.0, 0.0) : Matrix4.identity(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 16:9 Expansive Thumbnail Surface (350x197) with Liquid Glass Accents
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 197,
                  width: 350,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161618),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isHovered ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.12),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isHovered ? AppColors.netflixRed.withOpacity(0.3) : Colors.black.withOpacity(0.4),
                        blurRadius: _isHovered ? 24 : 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Backdrop / Thumbnail Image
                      if (imgUrl != null)
                        Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      else
                        _buildPlaceholder(),

                      // Cinematic Soft Ambient Vignette
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.2),
                              Colors.black.withOpacity(0.8),
                            ],
                            stops: const [0.4, 0.7, 1.0],
                          ),
                        ),
                      ),

                      // Liquid Glass Title Badge inside Thumbnail
                      Positioned(
                        left: 14,
                        bottom: 14,
                        right: 14,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
                              ),
                              child: Text(
                                item.seriesTitle ?? item.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Liquid Glass Hover Play Button Overlay
                      if (_isHovered && !widget.isEditMode)
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: AppColors.netflixRed.withOpacity(0.88),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.netflixRed.withOpacity(0.5),
                                      blurRadius: 18,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                              ),
                            ),
                          ),
                        ),

                      // Edit Mode Delete Badge
                      if (widget.isEditMode)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: widget.onRemove,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppColors.netflixRed,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
                                ],
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ),

                      // Bottom Progress Line (Red with Glowing Highlight)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 4,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                Container(color: Colors.white.withOpacity(0.2)),
                                Container(
                                  width: constraints.maxWidth * progress,
                                  decoration: const BoxDecoration(
                                    color: AppColors.netflixRed,
                                    boxShadow: [
                                      BoxShadow(color: AppColors.netflixRed, blurRadius: 4),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 2. Title & Subtitle below Thumbnail
              Text(
                item.seriesTitle != null && item.seriesTitle != item.title
                    ? item.title
                    : (item.seriesTitle ?? item.title),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              Text(
                _buildSubtitle(item),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF222225),
      child: const Center(
        child: Icon(Icons.movie_rounded, color: Colors.white24, size: 44),
      ),
    );
  }
}
