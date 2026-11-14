import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/media_item.dart';
import '../core/services/gpu_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/subtitle_service.dart';
import '../core/services/windows_wakelock.dart';

class MediaChapter {
  final String title;
  final Duration time;

  const MediaChapter({required this.title, required this.time});
}

class PlayerProvider extends ChangeNotifier {
  static const String _volumePrefKey = 'cinema_stream_saved_volume';

  late final Player _player;
  late final VideoController _videoController;

  MediaItem? _currentMedia;
  MediaItem? _nextEpisode;
  List<MediaItem> _seriesEpisodes = [];
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  double _volume = 70.0; // Default 70%
  bool _isMuted = false;
  double _playbackRate = 1.0;

  // Subtitles
  List<LocalSubtitleTrack> _subtitles = [];
  LocalSubtitleTrack? _selectedSubtitle;
  bool _isSearchingOnlineSubtitles = false;
  List<OnlineSubtitle> _onlineSubtitles = [];
  String? _autoSubtitleNotification;
  double _subtitleDelay = 0.0; // Seconds offset
  double _subtitleFontSize = 26.0; // Flutter subtitle font size
  double _subtitleBottomPadding = 85.0; // Distance from bottom (height adjustment)
  bool _subtitleTransparentBackground = true; // Transparent vs dark box
  Color _subtitleColor = Colors.white;

  // Audio Tracks & Enhancement
  List<AudioTrack> _audioTracks = [];
  AudioTrack? _selectedAudioTrack;
  bool _isDialogueBoostActive = false;
  double _audioDelay = 0.0; // Seconds offset

  // Ambient Glow / Ambilight
  bool _isAmbientGlowActive = true;

  // Media Chapters
  final List<MediaChapter> _chapters = [];

  // NVIDIA RTX Video Super Resolution (VSR)
  bool _isRtxVsrEnabled = true;
  bool _isRtxVsrActive = false;
  bool _hasRtxGpu = false;

  // Next Episode Countdown
  bool _showNextEpisodePrompt = false;
  int _nextEpisodeCountdown = 10;
  Timer? _countdownTimer;

  Timer? _progressSaveTimer;

  Player get player => _player;
  VideoController get videoController => _videoController;
  MediaItem? get currentMedia => _currentMedia;
  MediaItem? get nextEpisode => _nextEpisode;
  List<MediaItem> get seriesEpisodes => _seriesEpisodes;

  String get videoQualityLabel {
    final h = _player.state.videoParams.h ?? _player.state.videoParams.dh ?? 0;
    if (h >= 2160) return '4K UHD';
    if (h >= 1440) return '1440p';
    if (h >= 1080) return '1080p';
    if (h >= 720) return '720p';
    if (h > 0) return '${h}p';
    final name = _currentMedia?.rawFileName.toLowerCase() ?? '';
    if (name.contains('2160p') || name.contains('4k')) return '4K UHD';
    if (name.contains('1080p')) return '1080p';
    if (name.contains('720p')) return '720p';
    return '1080p';
  }

  Future<void> playMedia(MediaItem item, {MediaItem? nextEp, List<MediaItem>? seriesEpisodes}) =>
      openMedia(item, nextEp: nextEp, seriesEpisodes: seriesEpisodes);

  String get audioTrackLabel {
    if (_selectedAudioTrack != null) {
      final t = _selectedAudioTrack!.title ?? _selectedAudioTrack!.language ?? 'Track';
      return t.toUpperCase();
    }
    if (_audioTracks.isNotEmpty) {
      final t = _audioTracks.first.title ?? _audioTracks.first.language ?? 'Stereo 2.0';
      return t.toUpperCase();
    }
    return 'STEREO 2.0';
  }

  String get subtitleLabel {
    if (_selectedSubtitle != null) {
      return _selectedSubtitle!.title;
    }
    return 'Off';
  }

  String get rtxVsrLabel {
    if (!_hasRtxGpu) return 'Unavailable';
    return _isRtxVsrActive ? 'Active' : 'Off';
  }

  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get buffer => _buffer;
  double get volume => _volume;
  bool get isMuted => _isMuted;
  double get playbackRate => _playbackRate;

  List<LocalSubtitleTrack> get subtitles => _subtitles;
  LocalSubtitleTrack? get selectedSubtitle => _selectedSubtitle;
  bool get isSearchingOnlineSubtitles => _isSearchingOnlineSubtitles;
  List<OnlineSubtitle> get onlineSubtitles => _onlineSubtitles;
  String? get autoSubtitleNotification => _autoSubtitleNotification;
  double get subtitleDelay => _subtitleDelay;
  double get subtitleFontSize => _subtitleFontSize;
  double get subtitleBottomPadding => _subtitleBottomPadding;
  bool get subtitleTransparentBackground => _subtitleTransparentBackground;
  Color get subtitleColor => _subtitleColor;

  List<AudioTrack> get audioTracks => _audioTracks;
  AudioTrack? get selectedAudioTrack => _selectedAudioTrack;
  bool get isDialogueBoostActive => _isDialogueBoostActive;
  double get audioDelay => _audioDelay;
  bool get isAmbientGlowActive => _isAmbientGlowActive;
  List<MediaChapter> get chapters => _chapters;

  List<MediaChapter> get effectiveChapters {
    if (_chapters.isNotEmpty) return _chapters;
    if (_duration <= const Duration(minutes: 5)) return [];
    final durSec = _duration.inSeconds;
    return [
      const MediaChapter(title: 'المقدمة • Opening Scene', time: Duration.zero),
      MediaChapter(title: 'المشهد الأول • Act I', time: Duration(seconds: (durSec * 0.08).round())),
      MediaChapter(title: 'المشهد الثاني • Act II', time: Duration(seconds: (durSec * 0.32).round())),
      MediaChapter(title: 'ذروة الأحداث • Climax', time: Duration(seconds: (durSec * 0.65).round())),
      MediaChapter(title: 'الخاتمة وتتر النهاية • Credits', time: Duration(seconds: (durSec * 0.90).round())),
    ];
  }

  MediaChapter? getChapterAt(Duration time) {
    final list = effectiveChapters;
    if (list.isEmpty) return null;
    MediaChapter? matched;
    for (final ch in list) {
      if (time >= ch.time) {
        matched = ch;
      } else {
        break;
      }
    }
    return matched;
  }

  bool get isRtxVsrEnabled => _isRtxVsrEnabled;
  bool get isRtxVsrActive => _isRtxVsrActive;
  bool get hasRtxGpu => _hasRtxGpu;

  bool get showNextEpisodePrompt => _showNextEpisodePrompt;
  int get nextEpisodeCountdown => _nextEpisodeCountdown;
  bool get isNearEnd =>
      _nextEpisode != null &&
      _duration.inSeconds > 20 &&
      ((_duration.inSeconds - _position.inSeconds) <= 35 || _position >= _duration);

  /// Returns true when in the series intro window (first 85 seconds)
  bool get canSkipIntro {
    if (_duration.inSeconds < 120) return false;
    final sec = _position.inSeconds;
    final isSeries = _currentMedia?.type == MediaType.seriesEpisode || _currentMedia?.seasonNumber != null;
    return isSeries && sec >= 5 && sec <= 85;
  }

  PlayerProvider() {
    _player = Player(
      configuration: const PlayerConfiguration(
        pitch: true, // Pitch correction for smooth playback at any speed
        bufferSize: 32 * 1024 * 1024, // 32MB cache for instant scrubbing
      ),
    );
    _videoController = VideoController(_player);

    _configureHardwareAcceleration();
    _loadSavedVolume();
    _initListeners();
  }

  Future<void> setMpvProperty(String property, String value) async {
    try {
      await (_player.platform as dynamic).command(['set', property, value]);
    } catch (_) {}
  }

  Future<String?> getMpvProperty(String property) async {
    try {
      return await (_player.platform as dynamic).getProperty(property);
    } catch (_) {
      return null;
    }
  }

  Future<void> toggleDialogueBoost() async {
    _isDialogueBoostActive = !_isDialogueBoostActive;
    if (_isDialogueBoostActive) {
      // Dynamic audio normalizer: raises low dialogue volume, compresses loud blasts smoothly
      await setMpvProperty('af', 'lavfi=[dynaudnorm=f=150:g=15:m=10:p=0.95]');
    } else {
      await setMpvProperty('af', '');
    }
    notifyListeners();
  }

  Future<void> setAudioDelay(double delaySeconds) async {
    _audioDelay = double.parse(delaySeconds.clamp(-5.0, 5.0).toStringAsFixed(2));
    await setMpvProperty('audio-delay', _audioDelay.toStringAsFixed(3));
    notifyListeners();
  }

  Future<void> adjustAudioDelay(double deltaSeconds) async {
    await setAudioDelay(_audioDelay + deltaSeconds);
  }

  Future<void> resetAudioDelay() async {
    await setAudioDelay(0.0);
  }

  void toggleAmbientGlow() {
    _isAmbientGlowActive = !_isAmbientGlowActive;
    notifyListeners();
  }

  Future<void> _loadChapters() async {
    _chapters.clear();
    try {
      final countStr = await getMpvProperty('chapters');
      final count = int.tryParse(countStr ?? '0') ?? 0;
      for (int i = 0; i < count; i++) {
        final title = await getMpvProperty('chapter-list/$i/title');
        final timeStr = await getMpvProperty('chapter-list/$i/time');
        final timeSec = double.tryParse(timeStr ?? '0') ?? 0.0;
        _chapters.add(MediaChapter(
          title: (title != null && title.trim().isNotEmpty) ? title.trim() : 'Chapter ${i + 1}',
          time: Duration(milliseconds: (timeSec * 1000).round()),
        ));
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _configureHardwareAcceleration() async {
    _hasRtxGpu = await GpuService.hasNvidiaRtx();
    final prefs = await SharedPreferences.getInstance();
    _isRtxVsrEnabled = prefs.getBool('rtx_vsr_enabled') ?? true;

    if (_hasRtxGpu && _isRtxVsrEnabled) {
      try {
        await setMpvProperty('gpu-api', 'd3d11');
        await setMpvProperty('hwdec', 'd3d11va');
        await setMpvProperty('d3d11-adapter', 'NVIDIA');
        // Direct3D 11 Video Processor with NVIDIA RTX Video Super Resolution
        await setMpvProperty('vf', 'd3d11vpp=scale=2:scaling-mode=nvidia');
        // High-precision GPU upscaling & adaptive sharpness
        await setMpvProperty('scale', 'ewa_lanczossharp');
        await setMpvProperty('cscale', 'spline36');
        await setMpvProperty('sharpen', '1.2');
        _isRtxVsrActive = true;
      } catch (_) {
        await setMpvProperty('hwdec', 'auto-safe');
        await setMpvProperty('vf', '');
        await setMpvProperty('scale', 'bilinear');
        await setMpvProperty('sharpen', '0.0');
        _isRtxVsrActive = false;
      }
    } else {
      await setMpvProperty('hwdec', 'auto-safe');
      await setMpvProperty('vf', '');
      await setMpvProperty('scale', 'bilinear');
      await setMpvProperty('sharpen', '0.0');
      _isRtxVsrActive = false;
    }
    notifyListeners();
  }

  Future<void> setRtxVsrEnabled(bool enable) async {
    _isRtxVsrEnabled = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rtx_vsr_enabled', enable);
    await _configureHardwareAcceleration();
  }

  Future<void> toggleRtxVsr() async {
    await setRtxVsrEnabled(!_isRtxVsrEnabled);
  }

  Future<void> _loadSavedVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_volumePrefKey);
      if (saved != null) {
        _volume = saved.clamp(0.0, 100.0);
      } else {
        _volume = 70.0;
      }
      _player.setVolume(_volume);
      notifyListeners();
    } catch (_) {}
  }

  void _initListeners() {
    _player.stream.playing.listen((playing) {
      _isPlaying = playing;
      if (playing) {
        WindowsWakelock.enable();
      } else {
        WindowsWakelock.disable();
      }
      notifyListeners();
    });

    _player.stream.position.listen((pos) {
      if (pos.inSeconds != _position.inSeconds) {
        _position = pos;

        // When near end of episode (< 35 seconds left) OR at end, trigger prompt
        final secondsLeft = _duration.inSeconds - pos.inSeconds;
        if (_nextEpisode != null && _duration.inSeconds > 30 && secondsLeft <= 35) {
          if (!_showNextEpisodePrompt) {
            _triggerNextEpisodeCountdown();
          }
        }
        notifyListeners();
      } else {
        _position = pos;
      }
    });

    _player.stream.duration.listen((dur) {
      _duration = dur;
      notifyListeners();
    });

    _player.stream.buffer.listen((buf) {
      _buffer = buf;
      notifyListeners();
    });

    _player.stream.tracks.listen((tracks) {
      _audioTracks = tracks.audio;
      notifyListeners();
    });

    _player.stream.track.listen((track) {
      _selectedAudioTrack = track.audio;
      notifyListeners();
    });

    _player.stream.completed.listen((completed) {
      if (completed && _currentMedia != null) {
        StorageService.updatePlaybackProgress(
          filePath: _currentMedia!.filePath,
          stoppedAtSeconds: _duration.inSeconds,
          durationSeconds: _duration.inSeconds,
        );

        if (_nextEpisode != null) {
          if (!_showNextEpisodePrompt) {
            _triggerNextEpisodeCountdown();
          }
        }
      }
    });

    // Save progress to database every 5 seconds
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveCurrentProgress();
    });
  }

  Future<void> openMedia(
    MediaItem item, {
    MediaItem? nextEp,
    List<MediaItem>? seriesEpisodes,
  }) async {
    _currentMedia = item;
    _nextEpisode = nextEp;
    _showNextEpisodePrompt = false;
    _countdownTimer?.cancel();
    _onlineSubtitles = [];
    _seriesEpisodes = (seriesEpisodes != null && seriesEpisodes.isNotEmpty)
        ? List<MediaItem>.from(seriesEpisodes)
        : [];
    _subtitleDelay = 0.0;
    _playbackRate = 1.0;
    _buffer = Duration.zero;
    notifyListeners();

    // Auto-discover episodes & next episode if series
    final isSeries = item.type == MediaType.seriesEpisode || item.seasonNumber != null || item.seriesTitle != null;
    if (isSeries) {
      if (_seriesEpisodes.isEmpty) {
        await _autoDiscoverNextEpisode(item);
      } else if (_nextEpisode == null) {
        String norm(String p) => p.replaceAll('\\', '/').trim().toLowerCase();
        final itemNormPath = norm(item.filePath);
        int idx = _seriesEpisodes.indexWhere((e) => norm(e.filePath) == itemNormPath);
        if (idx == -1 && item.seasonNumber != null && item.episodeNumber != null) {
          idx = _seriesEpisodes.indexWhere((e) =>
              e.seasonNumber == item.seasonNumber &&
              e.episodeNumber == item.episodeNumber);
        }
        if (idx != -1 && idx < _seriesEpisodes.length - 1) {
          _nextEpisode = _seriesEpisodes[idx + 1];
          notifyListeners();
        }
      }
    }

    // 1. Fetch fresh record from SQLite to get exact resume point
    final freshItem = await StorageService.getItemByPath(item.filePath) ?? item;
    final resumeSec = freshItem.stoppedAtSeconds;
    final Duration? startPosition = (resumeSec > 3 && !freshItem.isWatched)
        ? Duration(seconds: resumeSec)
        : null;

    // 2. Open directly with native start offset and start playback immediately
    await _configureHardwareAcceleration();
    await _player.open(Media(item.filePath, start: startPosition), play: true);

    // 3. Ensure saved volume is strictly applied
    await _player.setVolume(_isMuted ? 0.0 : _volume);

    // 3.1 Audio Delay & Dialogue Boost initialization
    _audioDelay = 0.0;
    if (_isDialogueBoostActive) {
      await setMpvProperty('af', 'lavfi=[dynaudnorm=f=150:g=15:m=10:p=0.95]');
    }

    // 3.2 Load MKV/MP4 media chapters
    Future.delayed(const Duration(milliseconds: 700), () => _loadChapters());

    // 4. Secondary resume guarantee: if mpv started at 0 despite startPosition, seek when ready
    if (startPosition != null) {
      StreamSubscription? resumeSub;
      resumeSub = _player.stream.duration.listen((dur) {
        if (dur > Duration.zero) {
          resumeSub?.cancel();
          if (_position.inSeconds < (resumeSec - 2)) {
            _player.seek(startPosition);
          }
        }
      });
      Timer(const Duration(seconds: 4), () {
        resumeSub?.cancel();
      });
    }

    // 5. Find local subtitles
    _subtitles = await SubtitleService.findLocalSubtitles(item.filePath);
    if (_subtitles.isNotEmpty) {
      final defaultSub = _subtitles.firstWhere(
        (s) => s.isDefault,
        orElse: () => _subtitles.first,
      );
      selectSubtitle(defaultSub);
    } else {
      _selectedSubtitle = null;
      // 6. Auto-fetch Arabic subtitle online in background if no local subtitle
      _autoFetchArabicSubtitle(item);
    }

    notifyListeners();
  }

  Future<void> _autoDiscoverNextEpisode(MediaItem item) async {
    try {
      final sTitle = item.seriesTitle ?? item.title;
      final allEps = await StorageService.getAllEpisodes();
      
      String norm(String p) => p.replaceAll('\\', '/').trim().toLowerCase();
      final itemNormPath = norm(item.filePath);

      // Match episodes belonging to this series
      var seriesEps = allEps
          .where((e) {
            final eSeries = (e.seriesTitle ?? e.title).trim().toLowerCase();
            final targetSeries = sTitle.trim().toLowerCase();
            return eSeries == targetSeries ||
                   eSeries.contains(targetSeries) ||
                   targetSeries.contains(eSeries);
          })
          .toList();

      // If nothing matched by seriesTitle, try matching by parent directory
      if (seriesEps.isEmpty) {
        final parentDir = File(item.filePath).parent.path.replaceAll('\\', '/').toLowerCase();
        seriesEps = allEps.where((e) {
          final eParent = File(e.filePath).parent.path.replaceAll('\\', '/').toLowerCase();
          return eParent == parentDir;
        }).toList();
      }

      seriesEps.sort((a, b) {
        final sComp = (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
        if (sComp != 0) return sComp;
        return (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
      });

      if (seriesEps.isEmpty) return;
      _seriesEpisodes = seriesEps;

      // Find current episode by normalized path first, or by season & episode number
      int idx = seriesEps.indexWhere((e) => norm(e.filePath) == itemNormPath);
      if (idx == -1 && item.seasonNumber != null && item.episodeNumber != null) {
        idx = seriesEps.indexWhere((e) =>
            e.seasonNumber == item.seasonNumber &&
            e.episodeNumber == item.episodeNumber);
      }

      if (idx != -1 && idx < seriesEps.length - 1 && _nextEpisode == null) {
        _nextEpisode = seriesEps[idx + 1];
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _autoFetchArabicSubtitle(MediaItem item) async {
    final query = item.seriesTitle ?? item.title;
    try {
      final results = await SubtitleService.searchOnlineSubtitles(
        query: query,
        filePath: item.filePath,
        season: item.seasonNumber,
        episode: item.episodeNumber,
        langCode: 'ara',
      );

      if (results.isNotEmpty && _currentMedia?.filePath == item.filePath) {
        final bestMatch = results.first;
        final downloaded = await SubtitleService.downloadOnlineSubtitle(bestMatch);
        if (downloaded != null && _currentMedia?.filePath == item.filePath) {
          _subtitles.add(downloaded);
          await selectSubtitle(downloaded);
          _autoSubtitleNotification = 'تم العثور على ترجمة عربية وتفعيلها تلقائياً';
          notifyListeners();
          Future.delayed(const Duration(seconds: 4), () {
            _autoSubtitleNotification = null;
            notifyListeners();
          });
        }
      }
    } catch (_) {}
  }

  void _triggerNextEpisodeCountdown() {
    _showNextEpisodePrompt = true;
    _nextEpisodeCountdown = 10;
    notifyListeners();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_nextEpisodeCountdown > 1) {
        _nextEpisodeCountdown--;
        notifyListeners();
      } else {
        timer.cancel();
        playNextEpisode();
      }
    });
  }

  void cancelNextEpisodeCountdown() {
    _showNextEpisodePrompt = false;
    _countdownTimer?.cancel();
    notifyListeners();
  }

  Future<void> playNextEpisode() async {
    if (_nextEpisode == null) return;
    _countdownTimer?.cancel();
    _showNextEpisodePrompt = false;
    final ep = _nextEpisode!;
    await openMedia(ep);
  }

  void playPause() {
    _player.playOrPause();
  }

  void seek(Duration target) {
    _player.seek(target);
  }

  void seekForward10() {
    final target = _position + const Duration(seconds: 10);
    seek(target < _duration ? target : _duration);
  }

  void seekBackward10() {
    final target = _position - const Duration(seconds: 10);
    seek(target > Duration.zero ? target : Duration.zero);
  }

  void skipIntro() {
    seek(const Duration(seconds: 85));
  }

  Future<void> setPlaybackRate(double rate) async {
    _playbackRate = rate;
    await _player.setRate(rate);
    notifyListeners();
  }

  void setVolume(double val) {
    _volume = val.clamp(0.0, 100.0);
    _player.setVolume(_isMuted ? 0.0 : _volume);
    notifyListeners();

    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble(_volumePrefKey, _volume);
    }).catchError((_) {});
  }

  void adjustVolume(double delta) {
    setVolume(_volume + delta);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _player.setVolume(_isMuted ? 0.0 : _volume);
    notifyListeners();
  }

  // --- Subtitles ---
  Future<void> selectSubtitle(LocalSubtitleTrack track) async {
    _selectedSubtitle = track;
    try {
      final file = File(track.path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final content = SubtitleService.decodeSubBytes(bytes);
        await _player.setSubtitleTrack(SubtitleTrack.data(content, title: track.title, language: 'ara'));
      } else {
        await _player.setSubtitleTrack(SubtitleTrack.uri(track.path, title: track.title));
      }
    } catch (_) {
      await _player.setSubtitleTrack(SubtitleTrack.uri(track.path, title: track.title));
    }
    notifyListeners();
  }

  Future<void> disableSubtitles() async {
    _selectedSubtitle = null;
    await _player.setSubtitleTrack(SubtitleTrack.no());
    notifyListeners();
  }

  void setSubtitleFontSize(double size) {
    _subtitleFontSize = size;
    notifyListeners();
  }

  void setSubtitleBottomPadding(double padding) {
    _subtitleBottomPadding = padding;
    notifyListeners();
  }

  void setSubtitleTransparentBackground(bool transparent) {
    _subtitleTransparentBackground = transparent;
    notifyListeners();
  }

  void setSubtitleColor(Color color) {
    _subtitleColor = color;
    notifyListeners();
  }

  Future<void> pickAndLoadLocalSubtitle() async {
    final picked = await SubtitleService.pickLocalSubtitleFile();
    if (picked != null) {
      _subtitles.add(picked);
      await selectSubtitle(picked);
    }
  }

  Future<void> searchOnlineSubtitles(String query, {String lang = 'ara'}) async {
    _isSearchingOnlineSubtitles = true;
    notifyListeners();

    var cleanTitle = query.trim();
    int? s = _currentMedia?.seasonNumber;
    int? e = _currentMedia?.episodeNumber;

    final match = RegExp(r'^(.*?)\s+[Ss](\d+)[Ee](\d+)', caseSensitive: false).firstMatch(cleanTitle);
    if (match != null) {
      final parsedTitle = match.group(1)?.trim();
      if (parsedTitle != null && parsedTitle.isNotEmpty) {
        cleanTitle = parsedTitle;
      }
      s = int.tryParse(match.group(2)!) ?? s;
      e = int.tryParse(match.group(3)!) ?? e;
    }

    _onlineSubtitles = await SubtitleService.searchOnlineSubtitles(
      query: cleanTitle.isNotEmpty ? cleanTitle : query.trim(),
      filePath: _currentMedia?.filePath,
      season: s,
      episode: e,
      langCode: lang,
    );

    _isSearchingOnlineSubtitles = false;
    notifyListeners();
  }

  Future<void> stopPlayback() async {
    WindowsWakelock.disable();
    _countdownTimer?.cancel();
    _showNextEpisodePrompt = false;
    await saveProgressNow();
    await _player.pause();
    await _player.stop();
    notifyListeners();
  }

  Future<void> saveProgressNow() async {
    if (_currentMedia != null && _position.inSeconds > 0) {
      final dur = _duration.inSeconds > 0 ? _duration.inSeconds : _player.state.duration.inSeconds;
      await StorageService.updatePlaybackProgress(
        filePath: _currentMedia!.filePath,
        stoppedAtSeconds: _position.inSeconds,
        durationSeconds: dur,
      );
    }
  }

  Future<bool> downloadAndApplyOnlineSubtitle(OnlineSubtitle sub) async {
    final downloaded = await SubtitleService.downloadOnlineSubtitle(sub);
    if (downloaded != null) {
      _subtitles.add(downloaded);
      await selectSubtitle(downloaded);
      return true;
    }
    return false;
  }

  Future<void> adjustSubtitleDelay(double delta) async {
    _subtitleDelay = double.parse((_subtitleDelay + delta).toStringAsFixed(1));
    await setMpvProperty('sub-delay', _subtitleDelay.toString());
    notifyListeners();
  }

  Future<void> resetSubtitleDelay() async {
    _subtitleDelay = 0.0;
    await setMpvProperty('sub-delay', '0');
    notifyListeners();
  }

  // --- Audio Tracks ---
  Future<void> selectAudioTrack(AudioTrack track) async {
    _selectedAudioTrack = track;
    await _player.setAudioTrack(track);
    notifyListeners();
  }

  void _saveCurrentProgress() {
    if (_currentMedia != null && _duration.inSeconds > 0) {
      StorageService.updatePlaybackProgress(
        filePath: _currentMedia!.filePath,
        stoppedAtSeconds: _position.inSeconds,
        durationSeconds: _duration.inSeconds,
      );
    }
  }

  @override
  void dispose() {
    WindowsWakelock.disable();
    _saveCurrentProgress();
    _progressSaveTimer?.cancel();
    _countdownTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}
