import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalSubtitleTrack {
  final String title;
  final String path;
  final bool isDefault;

  LocalSubtitleTrack({
    required this.title,
    required this.path,
    this.isDefault = false,
  });
}

class OnlineSubtitle {
  final String fileName;
  final String releaseName;
  final String languageName;
  final String languageCode;
  final String downloadUrl;
  final double? rating;
  final int downloads;
  final String? format;

  OnlineSubtitle({
    required this.fileName,
    required this.releaseName,
    required this.languageName,
    required this.languageCode,
    required this.downloadUrl,
    this.rating,
    this.downloads = 0,
    this.format,
  });
}

class SubtitleService {
  static const List<String> subExtensions = ['.srt', '.vtt', '.ass', '.sub'];

  // Windows-1256 (Arabic) codepage lookup table for bytes 0x80..0xFF
  static const List<int> _cp1256ToUnicode = [
    8364, 1662, 8218, 402, 8222, 8230, 8224, 8225, 710, 8240, 1657, 8249, 338, 1670, 1688, 1672,
    1711, 8216, 8217, 8220, 8221, 8226, 8211, 8212, 1705, 8482, 1681, 8250, 339, 8204, 8205, 1722,
    160, 1548, 162, 163, 164, 165, 166, 167, 168, 169, 1726, 171, 172, 173, 174, 175,
    176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 1563, 187, 188, 189, 190, 1567,
    1729, 1569, 1570, 1571, 1572, 1573, 1574, 1575, 1576, 1577, 1578, 1579, 1580, 1581, 1582, 1583,
    1584, 1585, 1586, 1587, 1588, 1589, 1590, 215, 1591, 1592, 1593, 1594, 1600, 1601, 1602, 1603,
    224, 1604, 226, 1605, 1606, 1607, 1608, 231, 232, 233, 234, 235, 1609, 1610, 238, 239,
    1611, 1612, 1613, 1614, 244, 1615, 1616, 247, 1617, 249, 1618, 251, 252, 8206, 8207, 1746
  ];

  static String decodeSubBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {}

    final sb = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80) {
        sb.writeCharCode(b);
      } else {
        sb.writeCharCode(_cp1256ToUnicode[b - 0x80]);
      }
    }
    return sb.toString();
  }

  /// Find all local subtitle files associated with a video file
  static Future<List<LocalSubtitleTrack>> findLocalSubtitles(String videoFilePath) async {
    final List<LocalSubtitleTrack> tracks = [];
    final videoDir = Directory(p.dirname(videoFilePath));
    final videoBaseName = p.basenameWithoutExtension(videoFilePath);

    if (!await videoDir.exists()) return tracks;

    try {
      final files = videoDir.listSync();
      for (final file in files) {
        if (file is File) {
          final ext = p.extension(file.path).toLowerCase();
          if (subExtensions.contains(ext)) {
            final subName = p.basenameWithoutExtension(file.path);

            if (subName.toLowerCase() == videoBaseName.toLowerCase()) {
              tracks.add(LocalSubtitleTrack(
                title: 'Default (${ext.replaceAll('.', '').toUpperCase()})',
                path: file.path,
                isDefault: true,
              ));
            } else if (subName.toLowerCase().startsWith(videoBaseName.toLowerCase())) {
              final langPart = subName.substring(videoBaseName.length).replaceAll(RegExp(r'[._\-]'), ' ').trim();
              tracks.add(LocalSubtitleTrack(
                title: langPart.isNotEmpty ? langPart.toUpperCase() : 'External Subtitle',
                path: file.path,
              ));
            }
          }
        }
      }

      for (final subDirName in ['Subs', 'subs', 'Subtitles', 'subtitles']) {
        final subFolder = Directory(p.join(videoDir.path, subDirName));
        if (await subFolder.exists()) {
          final subFiles = subFolder.listSync();
          for (final sf in subFiles) {
            if (sf is File && subExtensions.contains(p.extension(sf.path).toLowerCase())) {
              tracks.add(LocalSubtitleTrack(
                title: p.basenameWithoutExtension(sf.path),
                path: sf.path,
              ));
            }
          }
        }
      }
    } catch (_) {}

    return tracks;
  }

  /// Manually pick a subtitle file from anywhere on the PC
  static Future<LocalSubtitleTrack?> pickLocalSubtitleFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Subtitle File',
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt', 'ass', 'sub'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final name = p.basename(path);
      return LocalSubtitleTrack(
        title: name,
        path: path,
        isDefault: true,
      );
    }
    return null;
  }

  /// Compute 64-bit checksum hash for OpenSubtitles API (like MPC-HC / K-Lite)
  static Future<String?> computeOpenSubtitlesHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final size = await file.length();
      if (size < 65536 * 2) return null;

      final raf = await file.open(mode: FileMode.read);
      try {
        final head = await raf.read(65536);
        await raf.setPosition(size - 65536);
        final tail = await raf.read(65536);

        var hash = BigInt.from(size);
        final mask64 = BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);

        void processChunk(Uint8List bytes) {
          final byteData = ByteData.sublistView(bytes);
          for (var i = 0; i < bytes.length; i += 8) {
            final val = BigInt.from(byteData.getUint64(i, Endian.little));
            hash = (hash + val) & mask64;
          }
        }

        processChunk(head);
        processChunk(tail);

        return hash.toRadixString(16).padLeft(16, '0');
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// Search online subtitles via file hash (100% exact release matching like K-Lite)
  static Future<List<OnlineSubtitle>> _searchByFileHash(String filePath, String langCode) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return [];
      final size = await file.length();
      final hash = await computeOpenSubtitlesHash(filePath);
      if (hash == null) return [];

      final url = 'https://rest.opensubtitles.org/search/moviebytesize-$size/moviehash-$hash/sublanguageid-$langCode';
      return await _executeHttpJson(url, langCode);
    } catch (_) {
      return [];
    }
  }

  /// Search online subtitles via OpenSubtitles REST API (Free, multi-query resilient search)
  static Future<List<OnlineSubtitle>> searchOnlineSubtitles({
    required String query,
    String? filePath,
    int? season,
    int? episode,
    String langCode = 'ara',
  }) async {
    final Map<String, OnlineSubtitle> resultsMap = {};

    // Strategy 0 (K-Lite MPC-HC style): Search by video file 64-bit hash for exact release match
    if (filePath != null && filePath.isNotEmpty) {
      final hashResults = await _searchByFileHash(filePath, langCode);
      for (final item in hashResults) {
        resultsMap[item.downloadUrl] = item;
      }
    }

    // Strategy 1: If season and episode are specified, search clean structured endpoint
    if (season != null && episode != null) {
      final cleanQuery = Uri.encodeComponent(query.trim().toLowerCase());
      final structuredUrl = 'https://rest.opensubtitles.org/search/query-$cleanQuery/season-$season/episode-$episode/sublanguageid-$langCode';
      final list1 = await _executeHttpJson(structuredUrl, langCode);
      for (final item in list1) {
        resultsMap[item.downloadUrl] = item;
      }
    }

    // Strategy 2: Direct full-text search with user's exact query
    final trimmed = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    final cleanFull = Uri.encodeComponent(trimmed.toLowerCase());
    final fullUrl = 'https://rest.opensubtitles.org/search/query-$cleanFull/sublanguageid-$langCode';
    final list2 = await _executeHttpJson(fullUrl, langCode);
    for (final item in list2) {
      resultsMap[item.downloadUrl] = item;
    }

    // Strategy 3: Query with plus instead of %20 if spaces exist
    if (trimmed.contains(' ')) {
      final plusQuery = trimmed.toLowerCase().replaceAll(' ', '+');
      final plusUrl = 'https://rest.opensubtitles.org/search/query-$plusQuery/sublanguageid-$langCode';
      final list3 = await _executeHttpJson(plusUrl, langCode);
      for (final item in list3) {
        resultsMap[item.downloadUrl] = item;
      }
    }

    // Strategy 4: Fallback to title only if results are empty and query contains SxxExx
    if (resultsMap.isEmpty && query.toLowerCase().contains('s0')) {
      final titleOnly = query.replaceAll(RegExp(r'[Ss]\d+.*'), '').trim();
      if (titleOnly.isNotEmpty) {
        final cleanTitle = Uri.encodeComponent(titleOnly.toLowerCase());
        final titleUrl = 'https://rest.opensubtitles.org/search/query-$cleanTitle/sublanguageid-$langCode';
        final list4 = await _executeHttpJson(titleUrl, langCode);
        for (final item in list4) {
          resultsMap[item.downloadUrl] = item;
        }
      }
    }

    // Sort by downloads & rating descending
    final list = resultsMap.values.toList();
    list.sort((a, b) {
      if (b.downloads != a.downloads) {
        return b.downloads.compareTo(a.downloads);
      }
      return (b.rating ?? 0.0).compareTo(a.rating ?? 0.0);
    });

    return list;
  }

  static Future<List<OnlineSubtitle>> _executeHttpJson(String urlString, String langCode) async {
    final client = HttpClient();
    client.userAgent = 'TemporaryUserAgent';
    client.autoUncompress = true;
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      final uri = Uri.parse(urlString);
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'TemporaryUserAgent');
      req.headers.set('Accept', 'application/json');

      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        if (body.isNotEmpty) {
          final dynamic data = json.decode(body);
          if (data is List) {
            return data.map((item) {
              final rawRating = item['SubRating'];
              double? parsedRating;
              if (rawRating is num) {
                parsedRating = rawRating.toDouble();
              } else if (rawRating != null) {
                parsedRating = double.tryParse(rawRating.toString());
              }

              return OnlineSubtitle(
                fileName: item['SubFileName'] ?? 'Subtitle.srt',
                releaseName: (item['MovieReleaseName'] as String?)?.trim() ?? item['SubFileName'] ?? '',
                languageName: item['LanguageName'] ?? (langCode == 'ara' ? 'Arabic' : 'English'),
                languageCode: item['SubLanguageID'] ?? langCode,
                downloadUrl: item['SubDownloadLink'] ?? '',
                rating: parsedRating,
                downloads: int.tryParse(item['SubDownloadsCnt']?.toString() ?? '0') ?? 0,
                format: item['InfoFormat'] ?? item['SubFormat'] ?? 'SRT',
              );
            }).where((sub) => sub.downloadUrl.isNotEmpty).toList();
          }
        }
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return [];
  }

  /// Download and decompress online subtitle (.gz to UTF-8 .srt)
  static Future<LocalSubtitleTrack?> downloadOnlineSubtitle(OnlineSubtitle onlineSub) async {
    final client = HttpClient();
    client.userAgent = 'TemporaryUserAgent';
    client.autoUncompress = false; // We decompress manually via gzip to handle raw or compressed streams
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final uri = Uri.parse(onlineSub.downloadUrl);
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'TemporaryUserAgent');

      final resp = await req.close();
      if (resp.statusCode == 200) {
        final bytes = await resp.fold<List<int>>([], (prev, element) => prev..addAll(element));

        List<int> uncompressed;
        try {
          uncompressed = gzip.decode(bytes);
        } catch (_) {
          uncompressed = bytes;
        }

        // Decode and convert to pure UTF-8
        final decodedText = decodeSubBytes(uncompressed);
        final utf8Bytes = utf8.encode(decodedText);

        final appDir = await getApplicationSupportDirectory();
        final subsDir = Directory(p.join(appDir.path, 'downloaded_subtitles'));
        if (!await subsDir.exists()) {
          await subsDir.create(recursive: true);
        }

        var fileName = onlineSub.fileName;
        if (!fileName.toLowerCase().endsWith('.srt') &&
            !fileName.toLowerCase().endsWith('.vtt') &&
            !fileName.toLowerCase().endsWith('.ass')) {
          fileName = '$fileName.srt';
        }

        final targetPath = p.join(subsDir.path, fileName);
        final file = File(targetPath);
        await file.writeAsBytes(utf8Bytes);

        return LocalSubtitleTrack(
          title: '${onlineSub.languageName} (${onlineSub.fileName})',
          path: targetPath,
        );
      }
    } catch (_) {
    } finally {
      client.close();
    }

    return null;
  }
}
