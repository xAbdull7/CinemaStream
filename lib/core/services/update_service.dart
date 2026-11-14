import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../constants/app_colors.dart';
import '../theme/liquid_glass.dart';

class ReleaseInfo {
  final String tagName;
  final String version;
  final String changelog;
  final String downloadUrl;
  final String fileName;
  final int fileSize;
  final DateTime? publishedAt;

  const ReleaseInfo({
    required this.tagName,
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    required this.fileName,
    required this.fileSize,
    this.publishedAt,
  });
}

class UpdateService {
  static const String currentVersion = '1.3.1';
  static const String repoOwner = 'xAbdull7';
  static const String repoName = 'CinemaStream';
  static const String apiUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// Compare two semver strings: returns true if latest > current
  static bool isNewerVersion(String latest, String current) {
    try {
      final cleanLatest = latest.replaceAll(RegExp(r'[^0-9.]'), '');
      final cleanCurrent = current.replaceAll(RegExp(r'[^0-9.]'), '');

      final lParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (lParts.length < 3) {
        lParts.add(0);
      }
      while (cParts.length < 3) {
        cParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (lParts[i] > cParts[i]) return true;
        if (lParts[i] < cParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check GitHub Releases for newer version
  static Future<ReleaseInfo?> fetchLatestRelease() async {
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'CinemaStream-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final cleanVer = tagName.replaceAll(RegExp(r'^[vV]'), '');

      if (!isNewerVersion(cleanVer, currentVersion)) {
        return null; // Up to date
      }

      final body = data['body'] as String? ?? 'New update available with bug fixes and enhancements.';
      final assets = data['assets'] as List<dynamic>? ?? [];

      String? downloadUrl;
      String fileName = 'CinemaStream_Setup_v$cleanVer.exe';
      int fileSize = 0;

      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.toLowerCase().endsWith('.exe')) {
          downloadUrl = asset['browser_download_url'] as String?;
          fileName = name;
          fileSize = (asset['size'] as num?)?.toInt() ?? 0;
          break;
        }
      }

      if (downloadUrl == null) {
        return null;
      }

      DateTime? pubDate;
      if (data['published_at'] != null) {
        pubDate = DateTime.tryParse(data['published_at'] as String);
      }

      return ReleaseInfo(
        tagName: tagName,
        version: cleanVer,
        changelog: body,
        downloadUrl: downloadUrl,
        fileName: fileName,
        fileSize: fileSize,
        publishedAt: pubDate,
      );
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  /// Check and prompt update dialog
  static Future<void> checkAndPromptUpdate(BuildContext context, {bool isManual = false}) async {
    final release = await fetchLatestRelease();

    if (!context.mounted) return;

    if (release == null) {
      if (isManual) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                SizedBox(width: 12),
                Text('أنت تستخدم أحدث إصدار بالفعل (v$currentVersion) / You are on the latest version'),
              ],
            ),
            backgroundColor: Color(0xFF1E1E1E),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Show Liquid Glass update dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _UpdateDialog(release: release),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final ReleaseInfo release;
  const _UpdateDialog({required this.release});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = '';
  int _downloadedBytes = 0;
  int _totalBytes = 0;

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _statusMessage = 'جاري الاتصال بالسيرفر وتحميل التحديث...';
    });

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.release.downloadUrl));
      request.headers['User-Agent'] = 'CinemaStream-App';
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download update: HTTP ${response.statusCode}');
      }

      _totalBytes = response.contentLength ?? widget.release.fileSize;
      final tempDir = Directory.systemTemp;
      final targetFile = File(p.join(tempDir.path, widget.release.fileName));

      final sink = targetFile.openWrite();
      _downloadedBytes = 0;

      await response.stream.listen((chunk) {
        sink.add(chunk);
        _downloadedBytes += chunk.length;
        if (_totalBytes > 0 && mounted) {
          setState(() {
            _progress = (_downloadedBytes / _totalBytes).clamp(0.0, 1.0);
            final mbDone = (_downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
            final mbTotal = (_totalBytes / (1024 * 1024)).toStringAsFixed(1);
            _statusMessage = 'جاري التحميل: $mbDone MB / $mbTotal MB (${(_progress * 100).toInt()}%)';
          });
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      if (!mounted) return;

      setState(() {
        _statusMessage = 'اكتمل التحميل! جاري دمج التحديث وإعادة تشغيل التطبيق تلقائياً...';
      });

      await Future.delayed(const Duration(milliseconds: 600));

      // Launch installer completely silently in background (No wizard, no next/finish, auto-relaunch)
      await Process.start(
        targetFile.path,
        [
          '/VERYSILENT',
          '/SUPPRESSMSGBOXES',
          '/NORESTART',
          '/CLOSEAPPLICATIONS',
        ],
        mode: ProcessStartMode.detached,
      );

      // Close the current application gracefully so installer can overwrite and relaunch
      exit(0);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'فشل التحميل: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: LiquidGlassContainer(
          borderRadius: BorderRadius.circular(24),
          blur: 35,
          surfaceColor: const Color(0xFF0F0F14),
          borderColor: Colors.white.withOpacity(0.18),
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Mascot & Badges
                Row(
                  children: [
                    Image.asset(
                      'assets/images/app_logo.png',
                      width: 44,
                      height: 44,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.system_update_rounded,
                        color: AppColors.netflixRed,
                        size: 38,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تحديث جديد متوفر / New Update',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text(
                                'v${UpdateService.currentVersion}',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white38, size: 14),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.netflixRed.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.netflixRed.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'v${release.version}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!_isDownloading)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white60),
                        tooltip: 'إغلاق',
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Changelog header
                const Text(
                  'أبرز التحديثات والمميزات:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Changelog Card Box
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      release.changelog.trim().isNotEmpty
                          ? release.changelog
                          : '• تحسينات في الأداء وسرعة التشغيل\n• إصلاحات عامة وتحديث محرك التشغيل\n• General improvements and bug fixes',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Download Progress or Status
                if (_isDownloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.netflixRed),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else if (_statusMessage.isNotEmpty) ...[
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!_isDownloading) ...[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'تذكيري لاحقاً',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: _isDownloading ? null : _startDownloadAndInstall,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        _isDownloading ? 'جاري التحديث...' : 'تحديث وتثبيت الآن',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.netflixRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
