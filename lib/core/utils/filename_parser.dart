import 'package:path/path.dart' as p;

class ParsedMediaInfo {
  final String cleanTitle;
  final bool isSeries;
  final String? seriesTitle;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? year;
  final String? resolution;

  ParsedMediaInfo({
    required this.cleanTitle,
    required this.isSeries,
    this.seriesTitle,
    this.seasonNumber,
    this.episodeNumber,
    this.year,
    this.resolution,
  });
}

class FilenameParser {
  // Regex to detect Season & Episode in filename: S01E02, s1e2, 1x02, etc.
  static final RegExp _seasonEpisodeRegex = RegExp(
    r'(?:s|season\s*)(\d{1,2})(?:e|x|episode\s*)(\d{1,3})|(\d{1,2})x(\d{1,2})',
    caseSensitive: false,
  );

  // Regex to detect Episode only in filename: E01, E1, EP01, Episode 1
  static final RegExp _episodeOnlyRegex = RegExp(
    r'(?:^|[\s._\-\[\(])(?:e|ep|episode)\s*(\d{1,3})(?:[\s._\-\]\)]|$)',
    caseSensitive: false,
  );

  // Regex to detect 4-digit Year: (1950 - 2030)
  static final RegExp _yearRegex = RegExp(r'\b(19\d{2}|20\d{2})\b');

  // Strip release websites and ripper group tags
  static final RegExp _sitePrefixRegex = RegExp(
    r'^\s*\[?(?:egybest|akwam|myegy|arabseed|faselhd|cima4u|shahid4u|wecima|topcinema|cimaclub|yts|yts\.mx|yify|rarbg|psa|ettv|vtv)\]?[\s._\-]*',
    caseSensitive: false,
  );

  // Common quality markers and rip tags to remove
  static final RegExp _tagsRegex = RegExp(
    r'\b(1080p|720p|480p|2160p|4k|uhd|bluray|blu-ray|web-dl|webrip|hdrip|brrip|dvdrip|x264|x265|hevc|10bit|aac|ac3|dts|remux|hdtv|nf|proper|repack|multi|amzn|xvid|shaanig|demonangex|upgraded|remaster)\b',
    caseSensitive: false,
  );

  static ParsedMediaInfo parse(String rawFilePath) {
    var fileName = p.basenameWithoutExtension(rawFilePath);
    final normPath = rawFilePath.replaceAll('/', '\\');
    final parts = normPath.split('\\');

    int? season;
    int? episode;
    String? seriesName;
    bool isSeries = false;

    // 1. Check for S01E02 in filename
    final seMatch = _seasonEpisodeRegex.firstMatch(fileName);
    if (seMatch != null) {
      isSeries = true;
      if (seMatch.group(1) != null && seMatch.group(2) != null) {
        season = int.parse(seMatch.group(1)!);
        episode = int.parse(seMatch.group(2)!);
      } else if (seMatch.group(3) != null && seMatch.group(4) != null) {
        season = int.parse(seMatch.group(3)!);
        episode = int.parse(seMatch.group(4)!);
      }
      final rawSeriesName = fileName.substring(0, seMatch.start);
      seriesName = _cleanName(rawSeriesName);
    }

    // 2. Check for Episode only in filename (e.g. E01, Episode 1)
    if (!isSeries) {
      final epMatch = _episodeOnlyRegex.firstMatch(fileName);
      if (epMatch != null) {
        isSeries = true;
        episode = int.parse(epMatch.group(1)!);
        final rawSeriesName = fileName.substring(0, epMatch.start);
        seriesName = _cleanName(rawSeriesName);
      }
    }

    // 3. Inspect directory structure for "Season X", "S01", or "Shows" folder
    for (int i = 0; i < parts.length - 1; i++) {
      final partClean = parts[i].trim();

      // Check for Season folder (e.g. Season 1, S02)
      final seasonMatch = RegExp(r'^(?:season|s)\s*(\d{1,2})$', caseSensitive: false).firstMatch(partClean);
      if (seasonMatch != null) {
        isSeries = true;
        season ??= int.parse(seasonMatch.group(1)!);
        if (seriesName == null || seriesName.isEmpty) {
          if (i > 0) seriesName = _cleanName(parts[i - 1]);
        }
      }
      // Check for standalone "Shows", "Series", "TV Shows", "مسلسلات" (NOT "Movies & TV shows")
      else if (RegExp(r'^(?:shows|series|tv shows|مسلسلات|anime)$', caseSensitive: false).hasMatch(partClean)) {
        isSeries = true;
        if (i + 1 < parts.length - 1 && (seriesName == null || seriesName.isEmpty)) {
          seriesName = _cleanName(parts[i + 1]);
        }
      }
    }

    if (isSeries) {
      // Find fallback season from any path part
      if (season == null) {
        for (final part in parts) {
          final sMatch = RegExp(r'(?:season|s)\s*(\d{1,2})\b', caseSensitive: false).firstMatch(part);
          if (sMatch != null) {
            season = int.parse(sMatch.group(1)!);
            break;
          }
        }
      }
      season ??= 1;
      episode ??= 1;

      // Fallback series name from parent folder if needed
      if (seriesName == null || seriesName.length < 2) {
        if (parts.length >= 2) {
          seriesName = _cleanName(parts[parts.length - 2]);
        }
      }

      // Remove any lingering "S01" from series name
      seriesName = seriesName?.replaceAll(RegExp(r'\s*(s\d{1,2}|season\s*\d{1,2})\b', caseSensitive: false), '').trim();
      if (seriesName == null || seriesName.isEmpty) seriesName = 'Unknown Series';

      final cleanTitle = '$seriesName - S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}';

      return ParsedMediaInfo(
        cleanTitle: cleanTitle,
        isSeries: true,
        seriesTitle: seriesName,
        seasonNumber: season,
        episodeNumber: episode,
      );
    }

    // 4. Movie Parsing
    String? year;
    final yearMatch = _yearRegex.firstMatch(fileName);
    if (yearMatch != null) {
      year = yearMatch.group(1);
    }

    String titlePart = fileName;
    if (yearMatch != null) {
      titlePart = fileName.substring(0, yearMatch.start);
    }

    final cleanTitle = _cleanName(titlePart);

    return ParsedMediaInfo(
      cleanTitle: cleanTitle.isEmpty ? fileName : cleanTitle,
      isSeries: false,
      year: year,
    );
  }

  static String _cleanName(String raw) {
    var cleaned = raw.replaceAll(_sitePrefixRegex, '');
    cleaned = cleaned
        .replaceAll(RegExp(r'\[.*?\]|\(.*?\)|[\._\-]'), ' ') // remove bracketed text and separators
        .replaceAll(_tagsRegex, '')                         // remove rip tags
        .replaceAll(RegExp(r'\b(egybest|akwam|myegy|arabseed|faselhd|cima4u|shahid4u|wecima|topcinema)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')                    // collapse spaces
        .trim();
    return cleaned;
  }
}
