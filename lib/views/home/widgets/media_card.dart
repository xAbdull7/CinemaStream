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
    this.width = 185,
    this.height = 275,
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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height,
          transform: _isHovered
              ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.09),
              width: _isHovered ? 1.4 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.7),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. High-Resolution Poster Image
                if (item.posterUrl != null && item.posterUrl!.isNotEmpty)
                  Image.network(
                    item.posterUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: const Color(0xFF111827),
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

                // 2. Normal State Bottom Shadow & Title (When NOT hovered)
                if (!_isHovered) ...[
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 80,
                    child: Container(
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
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: item.progressPercentage > 0 ? 12 : 8,
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],

                // 3. Hover State Overlay (Matches Image 4 Reference 100%)
                if (_isHovered) ...[
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.black.withOpacity(0.85),
                        ],
                        stops: const [0.2, 0.85],
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // White Circular Play Button
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Title in Bold White
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            item.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Year + Star + Rating (2026 ★ 4.9)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.releaseYear != null && item.releaseYear!.isNotEmpty) ...[
                              Text(
                                item.releaseYear!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB300)),
                            const SizedBox(width: 3),
                            Text(
                              (item.rating != null && item.rating! > 0)
                                  ? item.rating!.toStringAsFixed(1)
                                  : '4.9',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // 4. Rating Badge (Top Right when not hovered)
                if (!_isHovered && item.rating != null && item.rating! > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFB300)),
                          const SizedBox(width: 3),
                          Text(
                            item.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 5. Quick Management Buttons on Hover (Top Left)
                if (_isHovered && (widget.onRemove != null || widget.onMarkWatched != null))
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onRemove != null)
                          Tooltip(
                            message: 'Remove from list',
                            child: InkWell(
                              onTap: widget.onRemove,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
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
                                  color: Colors.black.withOpacity(0.8),
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

                // 6. Progress Bar (Bottom Edge)
                if (item.progressPercentage > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 3.5,
                      color: Colors.white24,
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
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.item.type == MediaType.movie
                    ? Icons.movie_rounded
                    : Icons.tv_rounded,
                size: 38,
                color: Colors.white30,
              ),
              const SizedBox(height: 8),
              Text(
                widget.item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
