import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/media_item.dart';

class MediaCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  final double height;
  final String? subtitle;
  final VoidCallback? onRemove;
  final VoidCallback? onMarkWatched;

  const MediaCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 190,
    this.height = 280,
    this.subtitle,
    this.onRemove,
    this.onMarkWatched,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height,
          transform: _isHovered
              ? Matrix4.translationValues(0.0, -6.0, 0.0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.10),
              width: 1.2,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.netflixRed.withOpacity(0.35),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Poster Image (Native Flutter Image.network)
                if (item.posterUrl != null && item.posterUrl!.isNotEmpty)
                  Image.network(
                    item.posterUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppColors.cardBackground,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.netflixRed,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => _buildFallbackPoster(),
                  )
                else
                  _buildFallbackPoster(),

                // 2. Dark gradient overlay at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 95,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withAlpha(235),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Title & Info at bottom
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: item.progressPercentage > 0 ? 12 : 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.subtitle != null)
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withAlpha(180),
                          ),
                        )
                      else if (item.releaseYear != null)
                        Text(
                          item.releaseYear!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withAlpha(180),
                          ),
                        ),
                    ],
                  ),
                ),

                // 4. Rating Badge (Top Right)
                if (item.rating != null && item.rating! > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(200),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: AppColors.ratingStar),
                          const SizedBox(width: 3),
                          Text(
                            item.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 5. Quick Management Buttons on Hover (Top Left for Continue Watching)
                if (_isHovered && (widget.onRemove != null || widget.onMarkWatched != null))
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onRemove != null)
                          Tooltip(
                            message: 'Remove from Continue Watching',
                            child: InkWell(
                              onTap: widget.onRemove,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(220),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        if (widget.onMarkWatched != null) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Mark as Watched',
                            child: InkWell(
                              onTap: widget.onMarkWatched,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(220),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Icon(Icons.check_rounded, size: 14, color: Colors.greenAccent),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // 6. Red Netflix-Style Progress Bar (Bottom edge)
                if (item.progressPercentage > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 4,
                      color: AppColors.progressBackground,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: item.progressPercentage,
                        child: Container(
                          color: AppColors.netflixRed,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackPoster() {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.item.type == MediaType.movie ? Icons.movie_outlined : Icons.tv_rounded,
            size: 48,
            color: Colors.white24,
          ),
          const SizedBox(height: 12),
          Text(
            widget.item.title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
