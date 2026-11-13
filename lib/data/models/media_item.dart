enum MediaType { movie, seriesEpisode }

class MediaItem {
  final int? id;
  final String title;
  final String rawFileName;
  final String filePath;
  final MediaType type;
  final String? seriesTitle;
  final int? seasonNumber;
  final int? episodeNumber;
  final int durationSeconds;
  final int stoppedAtSeconds;
  final bool isWatched;
  final String? posterUrl;
  final String? backdropUrl;
  final String? overview;
  final double? rating;
  final String? releaseYear;
  final DateTime? lastPlayedAt;

  MediaItem({
    this.id,
    required this.title,
    required this.rawFileName,
    required this.filePath,
    required this.type,
    this.seriesTitle,
    this.seasonNumber,
    this.episodeNumber,
    this.durationSeconds = 0,
    this.stoppedAtSeconds = 0,
    this.isWatched = false,
    this.posterUrl,
    this.backdropUrl,
    this.overview,
    this.rating,
    this.releaseYear,
    this.lastPlayedAt,
  });

  /// Calculate watch percentage for progress bar (0.0 to 1.0)
  double get progressPercentage {
    if (durationSeconds <= 0) return 0.0;
    return (stoppedAtSeconds / durationSeconds).clamp(0.0, 1.0);
  }

  /// Whether the item was partially watched (ready for "Continue Watching")
  bool get hasResumePoint {
    return stoppedAtSeconds > 5 && !isWatched && progressPercentage < 0.95;
  }

  MediaItem copyWith({
    int? id,
    String? title,
    String? rawFileName,
    String? filePath,
    MediaType? type,
    String? seriesTitle,
    int? seasonNumber,
    int? episodeNumber,
    int? durationSeconds,
    int? stoppedAtSeconds,
    bool? isWatched,
    String? posterUrl,
    String? backdropUrl,
    String? overview,
    double? rating,
    String? releaseYear,
    DateTime? lastPlayedAt,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      rawFileName: rawFileName ?? this.rawFileName,
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      stoppedAtSeconds: stoppedAtSeconds ?? this.stoppedAtSeconds,
      isWatched: isWatched ?? this.isWatched,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      overview: overview ?? this.overview,
      rating: rating ?? this.rating,
      releaseYear: releaseYear ?? this.releaseYear,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'raw_file_name': rawFileName,
      'file_path': filePath,
      'media_type': type == MediaType.movie ? 'movie' : 'episode',
      'series_title': seriesTitle,
      'season_number': seasonNumber,
      'episode_number': episodeNumber,
      'duration_seconds': durationSeconds,
      'stopped_at_seconds': stoppedAtSeconds,
      'is_watched': isWatched ? 1 : 0,
      'poster_url': posterUrl,
      'backdrop_url': backdropUrl,
      'overview': overview,
      'rating': rating,
      'release_year': releaseYear,
      'last_played_at': lastPlayedAt?.toIso8601String(),
    };
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'] as int?,
      title: map['title'] as String,
      rawFileName: map['raw_file_name'] as String,
      filePath: map['file_path'] as String,
      type: map['media_type'] == 'movie' ? MediaType.movie : MediaType.seriesEpisode,
      seriesTitle: map['series_title'] as String?,
      seasonNumber: map['season_number'] as int?,
      episodeNumber: map['episode_number'] as int?,
      durationSeconds: (map['duration_seconds'] as int?) ?? 0,
      stoppedAtSeconds: (map['stopped_at_seconds'] as int?) ?? 0,
      isWatched: (map['is_watched'] as int?) == 1,
      posterUrl: map['poster_url'] as String?,
      backdropUrl: map['backdrop_url'] as String?,
      overview: map['overview'] as String?,
      rating: (map['rating'] as num?)?.toDouble(),
      releaseYear: map['release_year'] as String?,
      lastPlayedAt: map['last_played_at'] != null 
          ? DateTime.tryParse(map['last_played_at'] as String) 
          : null,
    );
  }
}

