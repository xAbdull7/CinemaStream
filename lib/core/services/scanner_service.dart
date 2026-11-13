import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../data/models/media_item.dart';
import '../utils/filename_parser.dart';
import 'storage_service.dart';

class ScannerService {
  static const Set<String> supportedExtensions = {
    '.mkv',
    '.mp4',
    '.avi',
    '.mov',
    '.m4v',
    '.webm',
    '.ts',
    '.flv',
  };

  /// Scan a folder path on disk
  static Stream<MediaItem> scanDirectory(String directoryPath) async* {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return;

    try {
      final entities = dir.listSync(recursive: true, followLinks: false);

      for (final entity in entities) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext)) {
            // Ignore small sample files or trailers under 40MB
            final fileSize = await entity.length();
            if (fileSize < 40 * 1024 * 1024) continue;

            final parsed = FilenameParser.parse(entity.path);

            final mediaItem = MediaItem(
              title: parsed.cleanTitle,
              rawFileName: p.basename(entity.path),
              filePath: entity.path,
              type: parsed.isSeries ? MediaType.seriesEpisode : MediaType.movie,
              seriesTitle: parsed.seriesTitle,
              seasonNumber: parsed.seasonNumber,
              episodeNumber: parsed.episodeNumber,
              releaseYear: parsed.year,
            );

            // Save to database
            await StorageService.saveMediaItem(mediaItem);

            yield mediaItem;
          }
        }
      }
    } catch (e) {
      // In case of permission errors on some system folders
      debugPrint('Error scanning directory $directoryPath: $e');
    }
  }
}

