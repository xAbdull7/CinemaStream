import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/models/media_item.dart';
import 'storage_service.dart';

class TmdbService {
  // TMDB image base URL
  static const String imageBasePoster = 'https://image.tmdb.org/t/p/w500';
  static const String imageBaseBackdrop = 'https://image.tmdb.org/t/p/original';

  // Users can enter their free API key from themoviedb.org in settings
  static String? apiKey;

  /// Fetch metadata for a MediaItem
  static Future<MediaItem> enrichMediaItem(MediaItem item) async {
    // If already has poster and overview, no need to re-fetch
    if (item.posterUrl != null && item.overview != null) {
      return item;
    }

    if (apiKey == null || apiKey!.isEmpty) {
      return item;
    }

    try {
      if (item.type == MediaType.movie) {
        return await _searchMovie(item);
      } else {
        return await _searchSeries(item);
      }
    } catch (_) {
      return item;
    }
  }

  static Future<MediaItem> _searchMovie(MediaItem item) async {
    final cleanTitle = _cleanForSearch(item.title);
    final yearParam = item.releaseYear != null ? '&year=${item.releaseYear}' : '';

    var result = await _fetchMovieFromTmdb(cleanTitle, yearParam, 'ar-SA');
    result ??= await _fetchMovieFromTmdb(cleanTitle, yearParam, 'en-US');

    if (result != null) {
      final posterPath = result['poster_path'];
      final backdropPath = result['backdrop_path'];
      final overview = result['overview'] as String?;
      final rating = (result['vote_average'] as num?)?.toDouble();
      final releaseDate = result['release_date'] as String?;
      final year = releaseDate != null && releaseDate.length >= 4 
          ? releaseDate.substring(0, 4) 
          : item.releaseYear;

      final updated = item.copyWith(
        posterUrl: posterPath != null ? '$imageBasePoster$posterPath' : null,
        backdropUrl: backdropPath != null ? '$imageBaseBackdrop$backdropPath' : null,
        overview: overview?.isNotEmpty == true ? overview : null,
        rating: rating,
        releaseYear: year,
      );

      await StorageService.saveMediaItem(updated);
      return updated;
    }
    return item;
  }

  static Future<Map<String, dynamic>?> _fetchMovieFromTmdb(String title, String yearParam, String lang) async {
    final query = Uri.encodeComponent(title);
    final url = Uri.parse(
      'https://api.themoviedb.org/3/search/movie?api_key=$apiKey&query=$query$yearParam&include_adult=false&language=$lang',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        if (results.isNotEmpty) return results.first;
      }
    } catch (_) {}
    return null;
  }

  static Future<MediaItem> _searchSeries(MediaItem item) async {
    final seriesName = _cleanForSearch(item.seriesTitle ?? item.title);

    var result = await _fetchSeriesFromTmdb(seriesName, 'ar-SA');
    result ??= await _fetchSeriesFromTmdb(seriesName, 'en-US');

    if (result != null) {
      final posterPath = result['poster_path'];
      final backdropPath = result['backdrop_path'];
      final overview = result['overview'] as String?;
      final rating = (result['vote_average'] as num?)?.toDouble();

      final updated = item.copyWith(
        posterUrl: posterPath != null ? '$imageBasePoster$posterPath' : null,
        backdropUrl: backdropPath != null ? '$imageBaseBackdrop$backdropPath' : null,
        overview: overview?.isNotEmpty == true ? overview : null,
        rating: rating,
      );

      await StorageService.saveMediaItem(updated);
      return updated;
    }
    return item;
  }

  static Future<Map<String, dynamic>?> _fetchSeriesFromTmdb(String title, String lang) async {
    final query = Uri.encodeComponent(title);
    final url = Uri.parse(
      'https://api.themoviedb.org/3/search/tv?api_key=$apiKey&query=$query&include_adult=false&language=$lang',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        if (results.isNotEmpty) return results.first;
      }
    } catch (_) {}
    return null;
  }

  static String _cleanForSearch(String raw) {
    return raw
        .replaceAll(RegExp(r'\b(egybest|akwam|myegy|arabseed|faselhd|cima4u|shahid4u|wecima)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
