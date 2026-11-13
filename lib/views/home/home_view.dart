import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/update_service.dart';
import '../../core/utils/filename_parser.dart';
import '../../data/models/media_item.dart';
import '../../providers/locale_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../details/series_details_dialog.dart';
import '../player/player_view.dart';
import '../settings/settings_view.dart';
import 'widgets/continue_watching_card.dart';
import 'widgets/hero_banner.dart';
import 'widgets/media_card.dart';
import 'widgets/pill_navbar.dart';

class HomeView extends StatefulWidget {
  final String? initialFilePath;
  const HomeView({super.key, this.initialFilePath});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isEditContinueWatching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playExternalFile(widget.initialFilePath!);
      });
    }

    // Auto-check for updates in background shortly after launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          UpdateService.checkAndPromptUpdate(context, isManual: false);
        }
      });
    });
  }

  Future<void> _playExternalFile(String filePath) async {
    MediaItem? item = await StorageService.getItemByPath(filePath);
    if (item == null) {
      final parsed = FilenameParser.parse(filePath);
      item = MediaItem(
        title: parsed.cleanTitle,
        rawFileName: p.basename(filePath),
        filePath: filePath,
        type: parsed.isSeries ? MediaType.seriesEpisode : MediaType.movie,
        seriesTitle: parsed.seriesTitle,
        seasonNumber: parsed.seasonNumber,
        episodeNumber: parsed.episodeNumber,
        releaseYear: parsed.year,
      );
      await StorageService.saveMediaItem(item);
    }
    if (!mounted) return;
    await _playMedia(item);
  }

  Future<void> _playMedia(MediaItem item, {MediaItem? nextEp}) async {
    final library = context.read<LibraryProvider>();
    final player = context.read<PlayerProvider>();

    var targetNext = nextEp;
    if (targetNext == null && item.type == MediaType.seriesEpisode && item.seriesTitle != null) {
      final eps = library.seriesGrouped[item.seriesTitle] ?? [];
      final sortedEps = List<MediaItem>.from(eps)
        ..sort((a, b) {
          final sComp = (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
          if (sComp != 0) return sComp;
          return (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
        });
      final idx = sortedEps.indexWhere((e) => e.filePath == item.filePath);
      if (idx != -1 && idx < sortedEps.length - 1) {
        targetNext = sortedEps[idx + 1];
      }
    }

    player.openMedia(item, nextEp: targetNext);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerView()),
    );
    if (mounted) {
      await library.refreshLibrary();
    }
  }

  Future<void> _openSeriesDetails(String seriesTitle, List<MediaItem> episodes) async {
    final library = context.read<LibraryProvider>();
    await showDialog(
      context: context,
      builder: (_) => SeriesDetailsDialog(
        seriesTitle: seriesTitle,
        episodes: episodes,
      ),
    );
    if (mounted) {
      await library.refreshLibrary();
    }
  }

  List<MediaItem> _pickFeaturedItems({
    required NavTab tab,
    required List<MediaItem> movies,
    required Map<String, List<MediaItem>> series,
    required List<MediaItem> myFavorites,
    required List<MediaItem> continueWatching,
  }) {
    final candidates = <MediaItem>[];

    if (tab == NavTab.myList) {
      candidates.addAll(myFavorites);
    } else if (tab == NavTab.movies) {
      candidates.addAll(movies.where((m) => m.backdropUrl != null && m.backdropUrl!.isNotEmpty));
      if (candidates.isEmpty) candidates.addAll(movies);
    } else if (tab == NavTab.shows) {
      for (final eps in series.values) {
        final withBackdrop = eps.where((e) => e.backdropUrl != null && e.backdropUrl!.isNotEmpty);
        if (withBackdrop.isNotEmpty) {
          candidates.add(withBackdrop.first);
        } else if (eps.isNotEmpty) {
          candidates.add(eps.first);
        }
      }
    } else {
      // Home tab: Blend top rated movies and series with backdrops
      if (continueWatching.isNotEmpty) {
        candidates.add(continueWatching.first);
      }
      for (final m in movies.where((m) => m.backdropUrl != null)) {
        if (!candidates.any((c) => c.filePath == m.filePath)) {
          candidates.add(m);
        }
        if (candidates.length >= 4) break;
      }
      for (final eps in series.values) {
        final withBackdrop = eps.where((e) => e.backdropUrl != null);
        if (withBackdrop.isNotEmpty && !candidates.any((c) => c.seriesTitle == eps.first.seriesTitle)) {
          candidates.add(withBackdrop.first);
        }
        if (candidates.length >= 7) break;
      }
    }

    if (candidates.isEmpty && movies.isNotEmpty) {
      candidates.add(movies.first);
    }
    if (candidates.isEmpty && series.isNotEmpty) {
      candidates.add(series.values.first.first);
    }

    // Sort by rating descending if available
    candidates.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return candidates.take(7).toList();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final locale = context.watch<LocaleProvider>();
    final isArabic = locale.isArabic;

    var continueWatching = library.continueWatching;
    var movies = library.movies;
    var series = library.seriesGrouped;
    var myFavorites = library.myFavorites;

    // Apply Live Search Filter if searching
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      continueWatching = continueWatching.where((m) => m.title.toLowerCase().contains(q)).toList();
      movies = movies.where((m) => m.title.toLowerCase().contains(q)).toList();

      final filteredSeries = <String, List<MediaItem>>{};
      series.forEach((key, list) {
        if (key.toLowerCase().contains(q) || list.any((e) => e.title.toLowerCase().contains(q))) {
          filteredSeries[key] = list;
        }
      });
      series = filteredSeries;
      myFavorites = myFavorites.where((m) => m.title.toLowerCase().contains(q)).toList();
    }

    final activeTab = library.activeTab;
    final featuredItems = _pickFeaturedItems(
      tab: activeTab,
      movies: library.movies,
      series: library.seriesGrouped,
      myFavorites: library.myFavorites,
      continueWatching: library.continueWatching,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      body: Stack(
        children: [
          // 0. Atmospheric Ambient Glow Lights (Liquid Glass Optical Refraction Canvas)
          Positioned(
            top: 100,
            right: -80,
            width: 500,
            height: 500,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE50914).withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -100,
            width: 600,
            height: 600,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3F51B5).withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 1. Main Scrollable Content
          CustomScrollView(
            slivers: [
              // Hero Banner (Featured Carousel) - Shown when not searching
              if (_searchQuery.isEmpty)
                SliverToBoxAdapter(
                  child: HeroBanner(
                    featuredItems: featuredItems,
                    isArabic: isArabic,
                    onPlay: (item) => _playMedia(item),
                    onDetails: (item) {
                      if (item.type == MediaType.seriesEpisode) {
                        final sTitle = item.seriesTitle ?? item.title;
                        final eps = library.seriesGrouped[sTitle] ?? [item];
                        _openSeriesDetails(sTitle, eps);
                      }
                    },
                    onToggleWatchlist: (item) => library.toggleWatchlist(item.filePath),
                    isInWatchlist: (item) => library.isInWatchlist(item.filePath),
                  ),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 120)),

              // Scanning indicator if active
              if (library.isScanning)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 56, vertical: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.netflixDarkRed.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.netflixRed.withOpacity(0.6), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          locale.tr('scanning', params: {'count': library.scannedCount.toString()}),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),

              // Empty search state
              if (_searchQuery.isNotEmpty &&
                  continueWatching.isEmpty &&
                  movies.isEmpty &&
                  series.isEmpty &&
                  myFavorites.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(100),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(Icons.search_off_rounded, size: 72, color: Colors.white24),
                        const SizedBox(height: 18),
                        Text(
                          locale.tr('no_results'),
                          style: const TextStyle(fontSize: 20, color: Colors.white60, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

              // -------------------------------------------------------------
              // ROW 1: Continue Watching (16:9 Landscape Expansive 350px Cards)
              // -------------------------------------------------------------
              if (continueWatching.isNotEmpty && (activeTab == NavTab.home || _searchQuery.isNotEmpty))
                SliverToBoxAdapter(
                  child: _buildContinueWatchingSection(
                    continueWatching: continueWatching,
                    library: library,
                    isArabic: isArabic,
                  ),
                ),

              // -------------------------------------------------------------
              // ROW 2: TV Series (Poster 2:3 Expanded 190x280 Cards)
              // -------------------------------------------------------------
              if (series.isNotEmpty &&
                  (activeTab == NavTab.home || activeTab == NavTab.shows || _searchQuery.isNotEmpty))
                SliverToBoxAdapter(
                  child: _buildSection(
                    title: locale.tr('tv_series'),
                    child: SizedBox(
                      height: 295,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 56),
                        scrollDirection: Axis.horizontal,
                        itemCount: series.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 20),
                        itemBuilder: (context, index) {
                          final entry = series.entries.elementAt(index);
                          final seriesTitle = entry.key;
                          final episodes = entry.value;

                          final representativeItem = episodes.firstWhere(
                            (e) => e.posterUrl != null && e.posterUrl!.isNotEmpty,
                            orElse: () => episodes.first,
                          );

                          final seasonCount = episodes.map((e) => e.seasonNumber ?? 1).toSet().length;

                          return MediaCard(
                            item: representativeItem.copyWith(title: seriesTitle),
                            subtitle:
                                '$seasonCount ${locale.tr("seasons")} • ${episodes.length} ${locale.tr("episodes")}',
                            onTap: () => _openSeriesDetails(seriesTitle, episodes),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              // -------------------------------------------------------------
              // ROW 3: Movies (Poster 2:3 Expanded 190x280 Cards)
              // -------------------------------------------------------------
              if (movies.isNotEmpty &&
                  (activeTab == NavTab.home || activeTab == NavTab.movies || _searchQuery.isNotEmpty))
                SliverToBoxAdapter(
                  child: _buildSection(
                    title: locale.tr('movies'),
                    child: SizedBox(
                      height: 295,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 56),
                        scrollDirection: Axis.horizontal,
                        itemCount: movies.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 20),
                        itemBuilder: (context, index) {
                          final item = movies[index];
                          return MediaCard(
                            item: item,
                            onTap: () => _playMedia(item),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              // -------------------------------------------------------------
              // ROW 4: My List Tab Content (Watchlist)
              // -------------------------------------------------------------
              if (activeTab == NavTab.myList && _searchQuery.isEmpty)
                SliverToBoxAdapter(
                  child: myFavorites.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 80),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const Icon(Icons.bookmark_border_rounded, size: 64, color: Colors.white24),
                              const SizedBox(height: 16),
                              Text(
                                isArabic ? 'قائمتك فارغة حالياً' : 'Your list is empty',
                                style: const TextStyle(fontSize: 20, color: Colors.white70, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isArabic
                                    ? 'اضغط على زر (+) في البانر لإضافة أي فيلم أو مسلسل لقائمتك'
                                    : 'Click the (+) button in the banner to add titles to your list',
                                style: const TextStyle(fontSize: 14, color: Colors.white38),
                              ),
                            ],
                          ),
                        )
                      : _buildSection(
                          title: isArabic ? 'قائمتي المفضلة' : 'My List',
                          child: SizedBox(
                            height: 295,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 56),
                              scrollDirection: Axis.horizontal,
                              itemCount: myFavorites.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 20),
                              itemBuilder: (context, index) {
                                final item = myFavorites[index];
                                return MediaCard(
                                  item: item,
                                  onTap: () {
                                    if (item.type == MediaType.seriesEpisode && item.seriesTitle != null) {
                                      final eps = library.seriesGrouped[item.seriesTitle!] ?? [item];
                                      _openSeriesDetails(item.seriesTitle!, eps);
                                    } else {
                                      _playMedia(item);
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // 2. Symmetric Floating Liquid Glass Header (Left Brand Pill & Right Navigation Pill)
          Positioned(
            top: 26,
            left: 56,
            right: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Left: Liquid Glass Brand Pill enclosing Official Mascot Icon & App Name
                ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0x38FFFFFF),
                            Color(0x15FFFFFF),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.28),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.12),
                            blurRadius: 0,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Official Mascot Popcorn Kernel Icon
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'CINEMA',
                            style: TextStyle(
                              color: AppColors.netflixRed,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'STREAM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 2.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top Right: Floating Liquid Glass Pill Navbar
                PillNavbar(
                  activeTab: library.activeTab,
                  onTabChanged: (tab) => library.setActiveTab(tab),
                  searchController: _searchController,
                  onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
                  onOpenSettings: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsView()),
                    );
                  },
                  isArabic: isArabic,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Continue Watching Section with Expansive 16:9 Landscape Cards and ✎ Edit Toggle ---
  Widget _buildContinueWatchingSection({
    required List<MediaItem> continueWatching,
    required LibraryProvider library,
    required bool isArabic,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 32, 56, 18),
          child: Row(
            children: [
              Text(
                isArabic ? 'متابعة المشاهدة' : 'Continue Watching',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 14),
              // ✎ Edit Pencil Toggle Button in Liquid Glass Style
              Tooltip(
                message: isArabic ? 'تعديل وحذف من القائمة' : 'Edit / Remove items',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() => _isEditContinueWatching = !_isEditContinueWatching);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _isEditContinueWatching
                                ? AppColors.netflixRed.withOpacity(0.25)
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _isEditContinueWatching
                                  ? AppColors.netflixRed.withOpacity(0.7)
                                  : Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isEditContinueWatching ? Icons.check_circle_rounded : Icons.edit_outlined,
                                color: _isEditContinueWatching ? AppColors.netflixRed : Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isEditContinueWatching
                                    ? (isArabic ? 'تم' : 'Done')
                                    : (isArabic ? 'تعديل' : 'Edit'),
                                style: TextStyle(
                                  color: _isEditContinueWatching ? AppColors.netflixRed : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 270,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            scrollDirection: Axis.horizontal,
            itemCount: continueWatching.length,
            separatorBuilder: (_, __) => const SizedBox(width: 22),
            itemBuilder: (context, index) {
              final item = continueWatching[index];
              return ContinueWatchingCard(
                item: item,
                isEditMode: _isEditContinueWatching,
                isArabic: isArabic,
                onTap: () => _playMedia(item),
                onRemove: () => library.removeFromContinueWatching(item.filePath),
                onMarkWatched: () => library.markAsWatched(item.filePath),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 36, 56, 18),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
        child,
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
