import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../data/models/media_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';
import '../player/player_view.dart';

class SeriesDetailsDialog extends StatefulWidget {
  final String seriesTitle;
  final List<MediaItem> episodes;

  const SeriesDetailsDialog({
    super.key,
    required this.seriesTitle,
    required this.episodes,
  });

  @override
  State<SeriesDetailsDialog> createState() => _SeriesDetailsDialogState();
}

class _SeriesDetailsDialogState extends State<SeriesDetailsDialog> {
  int _selectedSeason = 1;
  late final Map<int, List<MediaItem>> _episodesBySeason;

  @override
  void initState() {
    super.initState();
    _groupEpisodes();
  }

  void _groupEpisodes() {
    _episodesBySeason = {};
    for (final ep in widget.episodes) {
      final s = ep.seasonNumber ?? 1;
      _episodesBySeason.putIfAbsent(s, () => []).add(ep);
    }

    // Sort seasons and episodes
    final seasons = _episodesBySeason.keys.toList()..sort();
    if (seasons.isNotEmpty) {
      _selectedSeason = seasons.first;
    }
  }

  Future<void> _playEpisode(MediaItem episode) async {
    final library = context.read<LibraryProvider>();
    final player = context.read<PlayerProvider>();

    // Calculate next episode in sequence
    MediaItem? nextEp;
    final sortedEps = List<MediaItem>.from(widget.episodes)
      ..sort((a, b) {
        final sComp = (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
        if (sComp != 0) return sComp;
        return (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
      });
    final idx = sortedEps.indexWhere((e) => e.filePath == episode.filePath);
    if (idx != -1 && idx < sortedEps.length - 1) {
      nextEp = sortedEps[idx + 1];
    }

    player.openMedia(episode, nextEp: nextEp, seriesEpisodes: widget.episodes);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerView()),
    );
    if (mounted) {
      await library.refreshLibrary();
      // Reload fresh episode state for this series
      final freshEp = await StorageService.getItemByPath(episode.filePath);
      if (freshEp != null && mounted) {
        setState(() {
          final list = _episodesBySeason[freshEp.seasonNumber ?? 1];
          if (list != null) {
            final idx = list.indexWhere((e) => e.filePath == freshEp.filePath);
            if (idx != -1) {
              list[idx] = freshEp;
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final firstItem = widget.episodes.first;
    final seasons = _episodesBySeason.keys.toList()..sort();
    final currentEpisodes = _episodesBySeason[_selectedSeason] ?? [];

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 700),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header with Backdrop & Title
              SizedBox(
                height: 250,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (firstItem.backdropUrl != null)
                      Image.network(
                        firstItem.backdropUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: AppColors.cardBackground),
                      )
                    else
                      Container(color: AppColors.cardBackground),

                    // Gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.surface,
                            AppColors.surface.withAlpha(160),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    // Close Button
                    Positioned(
                      top: 16,
                      right: locale.isArabic ? null : 16,
                      left: locale.isArabic ? 16 : null,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),

                    // Title & Meta
                    Positioned(
                      left: 24,
                      bottom: 20,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.seriesTitle,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (firstItem.rating != null && firstItem.rating! > 0) ...[
                                const Icon(Icons.star_rounded, size: 16, color: AppColors.ratingStar),
                                const SizedBox(width: 4),
                                Text(
                                  firstItem.rating!.toStringAsFixed(1),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 14),
                              ],
                              Text(
                                '${seasons.length} ${locale.tr('seasons')} • ${widget.episodes.length} ${locale.tr('episodes')}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Season Selector Dropdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      '${locale.tr('season')}:',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButton<int>(
                        value: _selectedSeason,
                        dropdownColor: AppColors.cardBackground,
                        underline: const SizedBox(),
                        items: seasons.map((s) {
                          return DropdownMenuItem<int>(
                            value: s,
                            child: Text('${locale.tr('season')} $s (${_episodesBySeason[s]?.length ?? 0} ${locale.tr('episodes')})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSeason = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white10, height: 1),

              // 3. Episode List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: currentEpisodes.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final ep = currentEpisodes[index];
                    final epNum = ep.episodeNumber ?? (index + 1);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$epNum',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        ep.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: ep.hasResumePoint
                          ? Text(
                              '${locale.tr('stopped_at')} ${(ep.stoppedAtSeconds / 60).floor()}',
                              style: const TextStyle(color: AppColors.netflixRed, fontSize: 12),
                            )
                          : null,
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: Text(ep.hasResumePoint ? locale.tr('resume') : locale.tr('play')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.netflixRed,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _playEpisode(ep),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

