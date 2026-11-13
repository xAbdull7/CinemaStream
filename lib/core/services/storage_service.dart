import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../data/models/media_item.dart';

class StorageService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    // Initialize FFI for Windows desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final appDocDir = await getApplicationSupportDirectory();
    final dbPath = p.join(appDocDir.path, 'cinema_stream.db');

    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE media_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              raw_file_name TEXT NOT NULL,
              file_path TEXT UNIQUE NOT NULL,
              media_type TEXT NOT NULL,
              series_title TEXT,
              season_number INTEGER,
              episode_number INTEGER,
              duration_seconds INTEGER DEFAULT 0,
              stopped_at_seconds INTEGER DEFAULT 0,
              is_watched INTEGER DEFAULT 0,
              poster_url TEXT,
              backdrop_url TEXT,
              overview TEXT,
              rating REAL,
              release_year TEXT,
              last_played_at TEXT
            )
          ''');

          await db.execute('''
            CREATE INDEX idx_file_path ON media_items (file_path);
          ''');
          await db.execute('''
            CREATE INDEX idx_stopped_at ON media_items (stopped_at_seconds);
          ''');
        },
      ),
    );
  }

  /// Insert or update an item without overwriting user progress
  static Future<void> saveMediaItem(MediaItem item) async {
    final db = await database;
    final existing = await getItemByPath(item.filePath);

    if (existing == null) {
      await db.insert('media_items', item.toMap());
    } else {
      // Preserve existing user playback progress and metadata if already fetched
      final updated = item.copyWith(
        id: existing.id,
        durationSeconds: existing.durationSeconds > 0 ? existing.durationSeconds : item.durationSeconds,
        stoppedAtSeconds: existing.stoppedAtSeconds,
        isWatched: existing.isWatched,
        posterUrl: existing.posterUrl ?? item.posterUrl,
        backdropUrl: existing.backdropUrl ?? item.backdropUrl,
        overview: existing.overview ?? item.overview,
        rating: existing.rating ?? item.rating,
        releaseYear: existing.releaseYear ?? item.releaseYear,
        lastPlayedAt: existing.lastPlayedAt,
      );
      await db.update(
        'media_items',
        updated.toMap(),
        where: 'file_path = ?',
        whereArgs: [item.filePath],
      );
    }
  }

  /// Update the exact second stopped and total duration
  static Future<void> updatePlaybackProgress({
    required String filePath,
    required int stoppedAtSeconds,
    required int durationSeconds,
  }) async {
    final db = await database;
    final isWatched = durationSeconds > 0 && (stoppedAtSeconds / durationSeconds) >= 0.92;

    await db.update(
      'media_items',
      {
        'stopped_at_seconds': stoppedAtSeconds,
        'duration_seconds': durationSeconds,
        'is_watched': isWatched ? 1 : 0,
        'last_played_at': DateTime.now().toIso8601String(),
      },
      where: 'file_path = ?',
      whereArgs: [filePath],
    );
  }

  /// Remove an item from Continue Watching list
  static Future<void> removeFromContinueWatching(String filePath) async {
    final db = await database;
    await db.update(
      'media_items',
      {'stopped_at_seconds': 0},
      where: 'file_path = ?',
      whereArgs: [filePath],
    );
  }

  /// Mark an item as completely watched
  static Future<void> markAsWatched(String filePath) async {
    final db = await database;
    final item = await getItemByPath(filePath);
    await db.update(
      'media_items',
      {
        'is_watched': 1,
        'stopped_at_seconds': item?.durationSeconds ?? 0,
      },
      where: 'file_path = ?',
      whereArgs: [filePath],
    );
  }

  /// Clear all watch progress and continue watching history
  static Future<void> clearWatchHistory() async {
    final db = await database;
    await db.update(
      'media_items',
      {
        'stopped_at_seconds': 0,
        'is_watched': 0,
      },
    );
  }

  /// Get items for the "Continue Watching" row on the home screen
  static Future<List<MediaItem>> getContinueWatching() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'media_items',
      where: 'stopped_at_seconds > 5 AND is_watched = 0',
      orderBy: 'last_played_at DESC',
      limit: 15,
    );
    return maps.map((m) => MediaItem.fromMap(m)).toList();
  }

  /// Get all movies
  static Future<List<MediaItem>> getAllMovies() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'media_items',
      where: 'media_type = ?',
      whereArgs: ['movie'],
      orderBy: 'title ASC',
    );
    return maps.map((m) => MediaItem.fromMap(m)).toList();
  }

  /// Get all series episodes
  static Future<List<MediaItem>> getAllEpisodes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'media_items',
      where: 'media_type = ?',
      whereArgs: ['episode'],
      orderBy: 'series_title ASC, season_number ASC, episode_number ASC',
    );
    return maps.map((m) => MediaItem.fromMap(m)).toList();
  }

  static Future<MediaItem?> getItemByPath(String filePath) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'media_items',
      where: 'file_path = ?',
      whereArgs: [filePath],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return MediaItem.fromMap(maps.first);
  }
}

