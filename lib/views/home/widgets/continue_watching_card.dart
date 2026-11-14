import 'package:flutter/material.dart';
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
      return widget.isArabic ? '$hours س $remMins د متبقية' : '${hours}h ${remMins}m left';
    }
    return widget.isArabic ? '$mins د متبقية' : '${mins}m left';
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
          width: 320,
          transform: _isHovered ? Matrix4.translationValues(0.0, -5.0, 0.0) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: const Color(0xFF131722),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? Colors.black.withOpacity(0.7) : Colors.black.withOpacity(0.45),
                blurRadius: _isHovered ? 20 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Backdrop / Thumbnail with Overlay (Height: 160)
                SizedBox(
                  height: 160,
                  width: 320,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imgUrl != null)
                        Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      else
                        _buildPlaceholder(),

                      // Subtle Dark Gradient over Image
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.85),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),

                      // Title & Episode Subtitle over image bottom (Matches Image 5)
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.seriesTitle ?? item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.seasonNumber != null && item.episodeNumber != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'S${item.seasonNumber} E${item.episodeNumber} "${item.title}"',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Top Right Quick Actions (Remove / Watched)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: widget.onRemove,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrubber Line & Time Remaining (Matches Image 5)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            height: 4,
                            color: Colors.white.withOpacity(0.2),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress.clamp(0.0, 1.0),
                              child: Container(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _formatTimeLeft(item),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Action Buttons (Resume, More Info, +) (Matches Image 5 100%)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: Row(
                    children: [
                      // White filled pill: ▶ Resume
                      ElevatedButton.icon(
                        onPressed: widget.onTap,
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 18),
                        label: Text(
                          widget.isArabic ? 'متابعة' : 'Resume',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Translucent Glass pill: ℹ More Info
                      OutlinedButton.icon(
                        onPressed: widget.onTap,
                        icon: const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 16),
                        label: Text(
                          widget.isArabic ? 'تفاصيل' : 'More Info',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.08),
                          side: BorderSide(color: Colors.white.withOpacity(0.18)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                      const Spacer(),

                      // Circle button: + (Watchlist toggle)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 36),
      ),
    );
  }
}
