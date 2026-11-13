import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/media_item.dart';
import '../core/services/scanner_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/tmdb_service.dart';

enum NavTab { home, movies, shows, myList }

class LibraryProvider extends ChangeNotifier {
  List<MediaItem> _continueWatching = [];
  List<MediaItem> _movies = [];
  Map<String, List<MediaItem>> _seriesGrouped = {};
  List<String> _mediaFolders = [];
  bool _isScanning = false;
  int _scannedCount = 0;

  NavTab _activeTab = NavTab.home;
  Set<String> _watchlist = {};

  List<MediaItem> get continueWatching => _continueWatching;
  List<MediaItem> get movies => _movies;
  Map<String, List<MediaItem>> get seriesGrouped => _seriesGrouped;
  List<String> get mediaFolders => _mediaFolders;
  bool get isScanning => _isScanning;
  int get scannedCount => _scannedCount;

  NavTab get activeTab => _activeTab;
  Set<String> get watchlist => _watchlist;

  void setActiveTab(NavTab tab) {
    _activeTab = tab;
    notifyListeners();
  }

  bool isInWatchlist(String filePath) => _watchlist.contains(filePath);

  Future<void> toggleWatchlist(String filePath) async {
    if (_watchlist.contains(filePath)) {
      _watchlist.remove(filePath);
    } else {
      _watchlist.add(filePath);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_watchlist', _watchlist.toList());
  }

  List<MediaItem> get myFavorites {
    final list = <MediaItem>[];
    for (final m in _movies) {
      if (_watchlist.contains(m.filePath)) list.add(m);
    }
    for (final eps in _seriesGrouped.values) {
      final rep = eps.firstWhere(
        (e) => _watchlist.contains(e.filePath),
        orElse: () => eps.first,
      );
      if (_watchlist.contains(rep.filePath)) {
        list.add(rep);
      }
    }
    return list;
  }

  LibraryProvider() {
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _mediaFolders = prefs.getStringList('media_folders') ?? [];
    TmdbService.apiKey = prefs.getString('tmdb_api_key');
    _watchlist = (prefs.getStringList('user_watchlist') ?? []).toSet();
    await refreshLibrary();

    // Check if any item lacks a poster and enrich in background
    if (TmdbService.apiKey != null && TmdbService.apiKey!.isNotEmpty) {
      final needsEnrich = _movies.any((m) => m.posterUrl == null) ||
          _seriesGrouped.values.any((eps) => eps.any((e) => e.posterUrl == null));
      if (needsEnrich) {
        _enrichAllMetadata();
      }
    }
  }

  Future<void> addMediaFolder(String folderPath) async {
    if (!_mediaFolders.contains(folderPath)) {
      _mediaFolders.add(folderPath);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('media_folders', _mediaFolders);
      notifyListeners();
      await scanFolders();
    }
  }

  Future<void> removeMediaFolder(String folderPath) async {
    _mediaFolders.remove(folderPath);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('media_folders', _mediaFolders);
    notifyListeners();
  }

  Future<void> setTmdbApiKey(String key) async {
    TmdbService.apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tmdb_api_key', key);
    notifyListeners();
    _enrichAllMetadata();
  }

  Future<void> removeFromContinueWatching(String filePath) async {
    await StorageService.removeFromContinueWatching(filePath);
    await refreshLibrary();
  }

  Future<void> markAsWatched(String filePath) async {
    await StorageService.markAsWatched(filePath);
    await refreshLibrary();
  }

  Future<void> clearWatchHistory() async {
    await StorageService.clearWatchHistory();
    await refreshLibrary();
  }

  Future<void> refreshLibrary() async {
    _continueWatching = await StorageService.getContinueWatching();
    _movies = await StorageService.getAllMovies();
    
    final episodes = await StorageService.getAllEpisodes();
    final Map<String, List<MediaItem>> grouped = {};
    for (final ep in episodes) {
      final sTitle = ep.seriesTitle ?? 'Unknown Series';
      grouped.putIfAbsent(sTitle, () => []).add(ep);
    }
    _seriesGrouped = grouped;
    
    notifyListeners();
  }

  Future<void> scanFolders() async {
    if (_mediaFolders.isEmpty) return;
    _isScanning = true;
    _scannedCount = 0;
    notifyListeners();

    for (final folder in _mediaFolders) {
      await for (final _ in ScannerService.scanDirectory(folder)) {
        _scannedCount++;
        notifyListeners();
      }
    }

    _isScanning = false;
    notifyListeners();
    await refreshLibrary();

    // Trigger metadata enrichment in the background
    _enrichAllMetadata();
  }

  Future<void> _enrichAllMetadata() async {
    if (TmdbService.apiKey == null || TmdbService.apiKey!.isEmpty) return;

    for (final movie in _movies) {
      if (movie.posterUrl == null) {
        await TmdbService.enrichMediaItem(movie);
      }
    }

    for (final seriesKey in _seriesGrouped.keys) {
      final eps = _seriesGrouped[seriesKey]!;
      // Find if any episode already has a poster
      final existingWithPoster = eps.where((e) => e.posterUrl != null).toList();

      MediaItem enriched;
      if (existingWithPoster.isNotEmpty) {
        enriched = existingWithPoster.first;
      } else {
        enriched = await TmdbService.enrichMediaItem(eps.first);
      }

      // Propagate poster & backdrop to ALL episodes of this series
      if (enriched.posterUrl != null) {
        for (final ep in eps) {
          if (ep.posterUrl == null) {
            await StorageService.saveMediaItem(ep.copyWith(
              posterUrl: enriched.posterUrl,
              backdropUrl: enriched.backdropUrl,
              overview: enriched.overview,
              rating: enriched.rating,
            ));
          }
        }
      }
    }

    await refreshLibrary();
  }
}
