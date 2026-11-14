import 'dart:async';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';

class PlayerView extends StatefulWidget {
  const PlayerView({super.key});

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> with SingleTickerProviderStateMixin {
  // HUD Visibility & Mouse Cursor
  bool _showControls = true;
  Timer? _hideTimer;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  // Seek OSD overlay
  bool _showSeekOsd = false;
  String _seekOsdText = '+10s';
  Timer? _seekOsdTimer;

  // Floating Pop-Out Menu (Audio, Subtitles, Speed)
  bool _showMenu = false;
  int _activeMenuTab = 0; // 0: Subtitles, 1: Audio, 2: Speed
  final TextEditingController _subSearchController = TextEditingController();
  String _selectedSubLang = 'ara';

  // Scrubber Hover Preview (Trickplay)
  bool _isScrubberHovered = false;
  double _scrubberHoverFraction = 0.0;
  double _scrubberHoverLocalX = 0.0;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekOsdTimer?.cancel();
    _subSearchController.dispose();
    _focusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    // Auto-hide controls and cursor after 3 seconds of inactivity
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_showMenu && !_isScrubberHovered && !_searchFocusNode.hasFocus) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onUserActivity() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _startHideTimer();
  }

  void _triggerSeekOsd(String text) {
    setState(() {
      _showSeekOsd = true;
      _seekOsdText = text;
    });
    _seekOsdTimer?.cancel();
    _seekOsdTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showSeekOsd = false);
    });
    _onUserActivity();
  }

  Future<void> _onEscapePressed() async {
    final isFull = await windowManager.isFullScreen();
    if (isFull) {
      await windowManager.setFullScreen(false);
    } else if (mounted) {
      await _handleExit(context);
    }
  }

  Future<void> _toggleFullscreen() async {
    final isFull = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!isFull);
    _onUserActivity();
  }

  void _toggleMenu({int tabIndex = 0}) {
    setState(() {
      if (_showMenu && _activeMenuTab == tabIndex) {
        _showMenu = false;
      } else {
        _showMenu = true;
        _activeMenuTab = tabIndex;
      }
    });

    if (_showMenu && tabIndex == 0) {
      final player = context.read<PlayerProvider>();
      final media = player.currentMedia;
      String q = media?.seriesTitle ?? media?.title ?? '';
      if (media?.seasonNumber != null && media?.episodeNumber != null) {
        final s = media!.seasonNumber!;
        final e = media.episodeNumber!;
        q = '$q S${s.toString().padLeft(2, '0')}E${e.toString().padLeft(2, '0')}';
      }
      _subSearchController.text = q;
      _selectedSubLang = 'ara';
      if (player.onlineSubtitles.isEmpty && !player.isSearchingOnlineSubtitles) {
        player.searchOnlineSubtitles(q, lang: _selectedSubLang);
      }
    }
    _onUserActivity();
  }

  Future<void> _handleExit(BuildContext context) async {
    final player = context.read<PlayerProvider>();
    final isFull = await windowManager.isFullScreen();
    if (isFull) {
      await windowManager.setFullScreen(false);
    }
    await player.stopPlayback();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final locale = context.watch<LocaleProvider>();
    final isArabic = locale.isArabic;
    final media = player.currentMedia;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        player.stopPlayback();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            // When typing inside the subtitle search box, DO NOT intercept keys
            if (_searchFocusNode.hasFocus) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                _searchFocusNode.unfocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }

            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.space) {
                player.playPause();
                _onUserActivity();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                player.seekForward10();
                _triggerSeekOsd('+10s');
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                player.seekBackward10();
                _triggerSeekOsd('-10s');
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                player.adjustVolume(5);
                _onUserActivity();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                player.adjustVolume(-5);
                _onUserActivity();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyF ||
                  event.logicalKey == LogicalKeyboardKey.f11) {
                _toggleFullscreen();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
                player.toggleMute();
                _onUserActivity();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                if (_showMenu) {
                  setState(() => _showMenu = false);
                  _onUserActivity();
                  return KeyEventResult.handled;
                }
                _onEscapePressed();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            cursor: _showControls ? SystemMouseCursors.basic : SystemMouseCursors.none,
            onHover: (_) => _onUserActivity(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Hardware Accelerated Video Player Surface
                Center(
                  child: Video(
                    controller: player.videoController,
                    controls: NoVideoControls,
                    subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
                  ),
                ),

                // 2. Custom Responsive Subtitle Overlay (100% Dynamic Height, Size, Color & Background)
                Positioned(
                  left: 48,
                  right: 48,
                  bottom: player.subtitleBottomPadding,
                  child: IgnorePointer(
                    child: StreamBuilder<List<String>>(
                      stream: player.player.stream.subtitle,
                      initialData: player.player.state.subtitle,
                      builder: (context, snapshot) {
                        final lines = snapshot.data ?? [];
                        final text = lines.where((l) => l.trim().isNotEmpty).join('\n').trim();
                        if (text.isEmpty || player.selectedSubtitle == null) {
                          return const SizedBox.shrink();
                        }
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: player.subtitleTransparentBackground
                                  ? Colors.transparent
                                  : const Color(0xCC000000),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: isArabic ? 'Tajawal' : 'NetflixSans',
                                fontSize: player.subtitleFontSize,
                                color: player.subtitleColor,
                                fontWeight: FontWeight.bold,
                                height: 1.35,
                                shadows: const [
                                  Shadow(offset: Offset(2.0, 2.0), blurRadius: 4.0, color: Colors.black),
                                  Shadow(offset: Offset(-2.0, -2.0), blurRadius: 4.0, color: Colors.black),
                                  Shadow(offset: Offset(2.0, -2.0), blurRadius: 4.0, color: Colors.black),
                                  Shadow(offset: Offset(-2.0, 2.0), blurRadius: 4.0, color: Colors.black),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 2. Video Background Gestures & Mouse-Wheel Volume (Isolated to Background Only)
                Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent && !_showMenu) {
                      if (pointerSignal.scrollDelta.dy < 0) {
                        player.adjustVolume(5);
                      } else if (pointerSignal.scrollDelta.dy > 0) {
                        player.adjustVolume(-5);
                      }
                      _onUserActivity();
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (_showMenu) {
                        setState(() => _showMenu = false);
                        _searchFocusNode.unfocus();
                        _onUserActivity();
                      } else {
                        player.playPause();
                        _onUserActivity();
                      }
                    },
                    onDoubleTap: () => _toggleFullscreen(),
                  ),
                ),

                // 3. Seek OSD Pill Overlay (±10s)
                if (_showSeekOsd)
                  Center(
                    child: AnimatedOpacity(
                      opacity: _showSeekOsd ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _seekOsdText.startsWith('+') ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                              color: AppColors.netflixRed,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _seekOsdText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 4. Vignette Gradients & Main HUD Controls
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 280),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Top Vignette Gradient
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 140,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.92),
                                  Colors.black.withOpacity(0.6),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Bottom Vignette Gradient
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 190,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.95),
                                  Colors.black.withOpacity(0.65),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Top Navigation Bar
                        Positioned(
                          top: 24,
                          left: 28,
                          right: 28,
                          child: Row(
                            children: [
                              _buildIconButton(
                                icon: Icons.arrow_back_rounded,
                                tooltip: isArabic ? 'خروج' : 'Exit',
                                onPressed: () => _handleExit(context),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      media?.title ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (media?.seriesTitle != null && media?.seasonNumber != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '${media!.seriesTitle} • S${media.seasonNumber.toString().padLeft(2, '0')}E${(media.episodeNumber ?? 1).toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (player.nextEpisode != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: _buildQuickChip(
                                    label: isArabic ? 'الحلقة التالية' : 'Next Ep',
                                    icon: Icons.skip_next_rounded,
                                    onPressed: () {
                                      player.playNextEpisode();
                                      _onUserActivity();
                                    },
                                  ),
                                ),
                              if (player.isRtxVsrActive)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Tooltip(
                                    message: isArabic
                                        ? 'تقنية تحسين الفيديو بالذكاء الاصطناعي نشطة (NVIDIA RTX VSR)'
                                        : 'NVIDIA RTX Video Super Resolution Active (AI Upscaled)',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF76B900).withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF76B900).withOpacity(0.85),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF76B900).withOpacity(0.4),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.bolt_rounded, color: Color(0xFF76B900), size: 15),
                                          SizedBox(width: 4),
                                          Text(
                                            'RTX VSR',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              _buildQuickChip(
                                label: '${player.playbackRate}x',
                                icon: Icons.speed_rounded,
                                onPressed: () => _toggleMenu(tabIndex: 2),
                              ),
                              const SizedBox(width: 10),
                              _buildIconButton(
                                icon: Icons.tune_rounded,
                                tooltip: isArabic ? 'الصوت والترجمة' : 'Audio & Subtitles',
                                onPressed: () => _toggleMenu(tabIndex: 0),
                              ),
                            ],
                          ),
                        ),

                        // Center Transport Controls (Quick Jump ±10s & Large Play/Pause)
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildCenterCircleButton(
                                icon: Icons.replay_10_rounded,
                                size: 52,
                                iconSize: 28,
                                tooltip: isArabic ? 'تأخير 10 ثوانٍ' : '-10 Seconds',
                                onPressed: () {
                                  player.seekBackward10();
                                  _triggerSeekOsd('-10s');
                                },
                              ),
                              const SizedBox(width: 32),
                              _buildCenterCircleButton(
                                icon: player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 74,
                                iconSize: 44,
                                isPrimary: true,
                                tooltip: player.isPlaying
                                    ? (isArabic ? 'إيقاف مؤقت' : 'Pause')
                                    : (isArabic ? 'تشغيل' : 'Play'),
                                onPressed: () {
                                  player.playPause();
                                  _onUserActivity();
                                },
                              ),
                              const SizedBox(width: 32),
                              _buildCenterCircleButton(
                                icon: Icons.forward_10_rounded,
                                size: 52,
                                iconSize: 28,
                                tooltip: isArabic ? 'تقديم 10 ثوانٍ' : '+10 Seconds',
                                onPressed: () {
                                  player.seekForward10();
                                  _triggerSeekOsd('+10s');
                                },
                              ),
                            ],
                          ),
                        ),

                        // Bottom Bar with 3-Tier Red Scrubber & Media Controls
                        Positioned(
                          bottom: 20,
                          left: 32,
                          right: 32,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Custom 3-Tier Red Scrubber with Hover Trickplay Preview Tooltip
                              _build3TierRedScrubber(player),
                              const SizedBox(height: 10),

                              // Controls Bottom Row
                              Row(
                                children: [
                                  // Play/Pause icon button
                                  IconButton(
                                    icon: Icon(
                                      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                    onPressed: () {
                                      player.playPause();
                                      _onUserActivity();
                                    },
                                  ),

                                  // Next Episode button in bottom bar
                                  if (player.nextEpisode != null)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.skip_next_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      tooltip: isArabic
                                          ? 'الحلقة التالية (${player.nextEpisode!.title})'
                                          : 'Next Episode (${player.nextEpisode!.title})',
                                      onPressed: () {
                                        player.playNextEpisode();
                                        _onUserActivity();
                                      },
                                    ),

                                  // Time Remaining / Elapsed
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      '${_formatDuration(player.position)} / ${_formatDuration(player.duration)}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),

                                  const Spacer(),

                                  // Volume Slider & Mute
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          player.isMuted
                                              ? Icons.volume_off_rounded
                                              : (player.volume > 50
                                                  ? Icons.volume_up_rounded
                                                  : (player.volume > 0
                                                      ? Icons.volume_down_rounded
                                                      : Icons.volume_mute_rounded)),
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        onPressed: () {
                                          player.toggleMute();
                                          _onUserActivity();
                                        },
                                      ),
                                      SizedBox(
                                        width: 90,
                                        child: SliderTheme(
                                          data: const SliderThemeData(
                                            trackHeight: 3,
                                            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                                            overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
                                            activeTrackColor: Colors.white,
                                            inactiveTrackColor: Colors.white24,
                                            thumbColor: Colors.white,
                                          ),
                                          child: Slider(
                                            value: player.isMuted ? 0.0 : player.volume,
                                            min: 0.0,
                                            max: 100.0,
                                            onChanged: (val) {
                                              player.setVolume(val);
                                              _onUserActivity();
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 36,
                                        child: Text(
                                          '${player.volume.round()}%',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.start,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(width: 14),

                                  // Subtitle Pop-Out Menu Button
                                  _buildIconButton(
                                    icon: Icons.subtitles_rounded,
                                    tooltip: isArabic ? 'الترجمة' : 'Subtitles',
                                    color: player.selectedSubtitle != null ? AppColors.netflixRed : Colors.white,
                                    onPressed: () => _toggleMenu(tabIndex: 0),
                                  ),

                                  // Audio Track Button
                                  _buildIconButton(
                                    icon: Icons.audiotrack_rounded,
                                    tooltip: isArabic ? 'مسارات الصوت' : 'Audio Tracks',
                                    onPressed: () => _toggleMenu(tabIndex: 1),
                                  ),

                                  // Playback Speed Button
                                  _buildIconButton(
                                    icon: Icons.speed_rounded,
                                    tooltip: isArabic ? 'سرعة التشغيل' : 'Playback Speed',
                                    color: player.playbackRate != 1.0 ? AppColors.netflixRed : Colors.white,
                                    onPressed: () => _toggleMenu(tabIndex: 2),
                                  ),

                                  // Fullscreen Button
                                  _buildIconButton(
                                    icon: Icons.fullscreen_rounded,
                                    tooltip: isArabic ? 'ملء الشاشة' : 'Fullscreen (F)',
                                    onPressed: () => _toggleFullscreen(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. Smart Skip Intro Floating Button (Bottom Right)
                if (player.canSkipIntro)
                  Positioned(
                    bottom: 95,
                    right: 36,
                    child: AnimatedOpacity(
                      opacity: player.canSkipIntro ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            player.skipIntro();
                            _onUserActivity();
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  isArabic ? 'تخطي المقدمة' : 'Skip Intro',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 6. Seamless Next Episode Prompt Card (Bottom Right)
                if (player.nextEpisode != null && (player.showNextEpisodePrompt || player.isNearEnd))
                  Positioned(
                    bottom: 95,
                    right: 36,
                    child: Container(
                      width: 320,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.netflixRed.withOpacity(0.7), width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.skip_next_rounded, color: AppColors.netflixRed, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                isArabic ? 'الحلقة التالية' : 'Next Episode',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (player.showNextEpisodePrompt)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.netflixRed.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${player.nextEpisodeCountdown}s',
                                    style: const TextStyle(
                                      color: AppColors.netflixRed,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            player.nextEpisode!.title,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    player.playNextEpisode();
                                    _onUserActivity();
                                  },
                                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                  label: Text(isArabic ? 'تشغيل الآن' : 'Play Now'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  player.cancelNextEpisodeCountdown();
                                  _onUserActivity();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white60,
                                ),
                                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // 7. Floating Menu Pop Out (Compact Floating Card above bottom bar)
                if (_showMenu)
                  Positioned(
                    bottom: 74,
                    right: 28,
                    width: 390,
                    height: 490,
                    child: _buildPopOutMenu(player, locale),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Custom 3-Tier Red Scrubber with Hover Trickplay Preview Tooltip ---
  Widget _build3TierRedScrubber(PlayerProvider player) {
    final durMs = player.duration.inMilliseconds;
    final posMs = player.position.inMilliseconds.clamp(0, durMs > 0 ? durMs : 0);
    final bufMs = player.buffer.inMilliseconds.clamp(0, durMs > 0 ? durMs : 0);

    final double posFraction = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;
    final double bufFraction = durMs > 0 ? (bufMs / durMs).clamp(0.0, 1.0) : 0.0;

    return MouseRegion(
      onEnter: (e) {
        setState(() {
          _isScrubberHovered = true;
          _scrubberHoverLocalX = e.localPosition.dx;
        });
      },
      onHover: (e) {
        setState(() {
          _isScrubberHovered = true;
          _scrubberHoverLocalX = e.localPosition.dx;
        });
      },
      onExit: (_) {
        setState(() => _isScrubberHovered = false);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          _scrubberHoverFraction = width > 0 ? (_scrubberHoverLocalX / width).clamp(0.0, 1.0) : 0.0;
          final hoverTime = Duration(milliseconds: (durMs * _scrubberHoverFraction).round());

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final frac = width > 0 ? (details.localPosition.dx / width).clamp(0.0, 1.0) : 0.0;
              final target = Duration(milliseconds: (durMs * frac).round());
              player.seek(target);
              _onUserActivity();
            },
            onHorizontalDragUpdate: (details) {
              final frac = width > 0 ? (details.localPosition.dx / width).clamp(0.0, 1.0) : 0.0;
              final target = Duration(milliseconds: (durMs * frac).round());
              player.seek(target);
              _onUserActivity();
            },
            child: Container(
              height: 32,
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // Track Base Bar (Remaining / Dark Gray)
                  Container(
                    height: _isScrubberHovered ? 7 : 4,
                    width: width,
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  // Buffered Bar (Light Gray)
                  Container(
                    height: _isScrubberHovered ? 7 : 4,
                    width: width * bufFraction,
                    decoration: BoxDecoration(
                      color: const Color(0xFF757575),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  // Elapsed Bar (Netflix Red)
                  Container(
                    height: _isScrubberHovered ? 7 : 4,
                    width: width * posFraction,
                    decoration: BoxDecoration(
                      color: AppColors.netflixRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  // Glowing Circular Thumb
                  Positioned(
                    left: (width * posFraction) - (_isScrubberHovered ? 8 : 5),
                    child: Container(
                      width: _isScrubberHovered ? 16 : 10,
                      height: _isScrubberHovered ? 16 : 10,
                      decoration: BoxDecoration(
                        color: AppColors.netflixRed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.netflixRed.withOpacity(0.6),
                            blurRadius: _isScrubberHovered ? 8 : 4,
                            spreadRadius: _isScrubberHovered ? 2 : 0,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Hover Trickplay Timecode Tooltip & Needle
                  if (_isScrubberHovered && durMs > 0) ...[
                    Positioned(
                      left: _scrubberHoverLocalX.clamp(0.0, width) - 1,
                      top: 4,
                      bottom: 4,
                      child: Container(
                        width: 2,
                        color: Colors.white70,
                      ),
                    ),
                    Positioned(
                      left: (_scrubberHoverLocalX - 40).clamp(0.0, width - 80),
                      bottom: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24, width: 1),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
                          ],
                        ),
                        child: Text(
                          _formatDuration(hoverTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Floating Pop Out Menu Card ---
  Widget _buildPopOutMenu(PlayerProvider player, LocaleProvider locale) {
    final isArabic = locale.isArabic;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B).withOpacity(0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Title & Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
                child: Row(
                  children: [
                    Text(
                      isArabic ? 'إعدادات المشغل' : 'Player Settings',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() => _showMenu = false);
                        _searchFocusNode.unfocus();
                        _onUserActivity();
                      },
                    ),
                  ],
                ),
              ),

              // Segmented Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildMenuTabItem(
                        title: isArabic ? 'الترجمة' : 'Subtitles',
                        icon: Icons.subtitles_rounded,
                        index: 0,
                      ),
                      _buildMenuTabItem(
                        title: isArabic ? 'الصوت' : 'Audio',
                        icon: Icons.audiotrack_rounded,
                        index: 1,
                      ),
                      _buildMenuTabItem(
                        title: isArabic ? 'السرعة' : 'Speed',
                        icon: Icons.speed_rounded,
                        index: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white12, height: 1),

              // Tab Content View
              Expanded(
                child: IndexedStack(
                  index: _activeMenuTab,
                  children: [
                    _buildSubtitlesTab(player, locale),
                    _buildAudioTab(player, locale),
                    _buildSpeedTab(player, locale),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTabItem({required String title, required IconData icon, required int index}) {
    final isSelected = _activeMenuTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _activeMenuTab = index);
          _onUserActivity();
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.netflixRed : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.white60, size: 15),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Subtitles Tab Content ---
  Widget _buildSubtitlesTab(PlayerProvider player, LocaleProvider locale) {
    final isArabic = locale.isArabic;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Subtitles Master Switch (Off / On)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(
            player.selectedSubtitle != null ? Icons.subtitles_rounded : Icons.subtitles_off_rounded,
            color: player.selectedSubtitle != null ? AppColors.netflixRed : Colors.white38,
            size: 20,
          ),
          title: Text(
            isArabic ? 'إيقاف الترجمة' : 'Off (No Subtitles)',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          trailing: player.selectedSubtitle == null
              ? const Icon(Icons.check_rounded, color: AppColors.netflixRed, size: 20)
              : null,
          onTap: () {
            player.disableSubtitles();
            _onUserActivity();
          },
        ),
        const Divider(color: Colors.white12, height: 16),

        // 1. Vertical Subtitle Height (ارتفاع الترجمة عن أسفل الشاشة)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'ارتفاع الترجمة (عن الأسفل)' : 'Subtitle Height (Position)',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              '${player.subtitleBottomPadding.round()}px',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.vertical_align_bottom_rounded, color: Colors.white54, size: 18),
            Expanded(
              child: SliderTheme(
                data: const SliderThemeData(
                  trackHeight: 3,
                  thumbColor: AppColors.netflixRed,
                  activeTrackColor: AppColors.netflixRed,
                  inactiveTrackColor: Colors.white24,
                ),
                child: Slider(
                  value: player.subtitleBottomPadding,
                  min: 20.0,
                  max: 260.0,
                  divisions: 24,
                  onChanged: (val) {
                    player.setSubtitleBottomPadding(val);
                    _onUserActivity();
                  },
                ),
              ),
            ),
            const Icon(Icons.vertical_align_top_rounded, color: Colors.white54, size: 18),
          ],
        ),
        const SizedBox(height: 6),

        // 2. Subtitle Background Transparency (خلفية شفافة / داكنة)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'خلفية الخط' : 'Subtitle Background',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                _buildBgOption(
                  label: isArabic ? 'شفافة' : 'Transparent',
                  isSelected: player.subtitleTransparentBackground,
                  onTap: () {
                    player.setSubtitleTransparentBackground(true);
                    _onUserActivity();
                  },
                ),
                const SizedBox(width: 8),
                _buildBgOption(
                  label: isArabic ? 'داكنة' : 'Dark Box',
                  isSelected: !player.subtitleTransparentBackground,
                  onTap: () {
                    player.setSubtitleTransparentBackground(false);
                    _onUserActivity();
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 3. Subtitle Font Size (حجم الخط)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'حجم الخط' : 'Font Size',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              '${player.subtitleFontSize.round()}px',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SliderTheme(
          data: const SliderThemeData(
            trackHeight: 3,
            thumbColor: AppColors.netflixRed,
            activeTrackColor: AppColors.netflixRed,
            inactiveTrackColor: Colors.white24,
          ),
          child: Slider(
            value: player.subtitleFontSize,
            min: 18.0,
            max: 48.0,
            divisions: 15,
            onChanged: (val) {
              player.setSubtitleFontSize(val);
              _onUserActivity();
            },
          ),
        ),
        const SizedBox(height: 6),

        // 4. Subtitle Font Color (لون الخط)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'لون الخط' : 'Font Color',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                _buildColorOption(player, Colors.white, 'White'),
                const SizedBox(width: 8),
                _buildColorOption(player, const Color(0xFFFFEB3B), 'Yellow'),
                const SizedBox(width: 8),
                _buildColorOption(player, const Color(0xFF00E5FF), 'Cyan'),
                const SizedBox(width: 8),
                _buildColorOption(player, const Color(0xFF69F0AE), 'Green'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 5. Subtitle Sync Offset (-0.5s / Reset / +0.5s)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'مزامنة التوقيت (Sync)' : 'Subtitle Sync',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => player.adjustSubtitleDelay(-0.5),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: const Size(40, 28),
                  ),
                  child: const Text('-0.5s', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => player.resetSubtitleDelay(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: const Size(40, 28),
                  ),
                  child: Text(
                    player.subtitleDelay == 0.0 ? '0.0s' : '${player.subtitleDelay > 0 ? '+' : ''}${player.subtitleDelay}s',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => player.adjustSubtitleDelay(0.5),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: const Size(40, 28),
                  ),
                  child: const Text('+0.5s', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
        const Divider(color: Colors.white12, height: 18),

        // Detected Local Subtitles
        if (player.subtitles.isNotEmpty) ...[
          Text(
            isArabic ? 'ملفات الترجمة المتوفرة' : 'Available Subtitles',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ...player.subtitles.map((sub) {
            final isSelected = player.selectedSubtitle?.path == sub.path;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.subtitles_outlined,
                color: isSelected ? AppColors.netflixRed : Colors.white54,
                size: 18,
              ),
              title: Text(
                sub.title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.netflixRed, size: 18) : null,
              onTap: () {
                player.selectSubtitle(sub);
                _onUserActivity();
              },
            );
          }),
          const SizedBox(height: 8),
        ],

        // Browse Local File Button
        OutlinedButton.icon(
          onPressed: () {
            player.pickAndLoadLocalSubtitle();
            _onUserActivity();
          },
          icon: const Icon(Icons.folder_open_rounded, size: 16),
          label: Text(
            isArabic ? 'فتح ملف ترجمة (.srt / .vtt)' : 'Load Subtitle File (.srt/.vtt)',
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),

        const SizedBox(height: 14),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 10),

        // Online Subtitles Search Bar with Clear Button & Dedicated FocusNode
        Text(
          isArabic ? 'البحث أونلاين (OpenSubtitles)' : 'Search Online Subtitles',
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _subSearchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: isArabic ? 'اسم الفيلم أو الحلقة...' : 'Title or S01E01...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  suffixIcon: _subSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white54),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _subSearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) {
                  setState(() {});
                },
                onSubmitted: (q) {
                  player.searchOnlineSubtitles(q, lang: _selectedSubLang);
                  _onUserActivity();
                },
              ),
            ),
            const SizedBox(width: 6),
            DropdownButton<String>(
              value: _selectedSubLang,
              dropdownColor: const Color(0xFF222222),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: const [
                DropdownMenuItem(value: 'ara', child: Text('عربي')),
                DropdownMenuItem(value: 'eng', child: Text('Eng')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedSubLang = val);
                  player.searchOnlineSubtitles(_subSearchController.text, lang: val);
                  _onUserActivity();
                }
              },
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: () {
                player.searchOnlineSubtitles(_subSearchController.text, lang: _selectedSubLang);
                _onUserActivity();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.netflixRed,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                minimumSize: const Size(36, 36),
              ),
              child: const Icon(Icons.search_rounded, color: Colors.white, size: 16),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Online Subtitles Results
        if (player.isSearchingOnlineSubtitles)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.netflixRed, strokeWidth: 2.5),
            ),
          )
        else if (player.onlineSubtitles.isNotEmpty)
          ...player.onlineSubtitles.map((onlineSub) {
            return Card(
              color: Colors.white.withOpacity(0.05),
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              child: ListTile(
                dense: true,
                title: Text(
                  onlineSub.fileName,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${onlineSub.languageName} • ⬇ ${onlineSub.downloads} downloads',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.download_rounded, color: AppColors.netflixRed, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    final ok = await player.downloadAndApplyOnlineSubtitle(onlineSub);
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isArabic ? 'تم تحميل وتفعيل الترجمة' : 'Subtitle downloaded & applied!'),
                          backgroundColor: Colors.green[800],
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBgOption({required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.netflixRed : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildColorOption(PlayerProvider player, Color color, String name) {
    final isSelected = player.subtitleColor == color;
    return GestureDetector(
      onTap: () {
        player.setSubtitleColor(color);
        _onUserActivity();
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.red : Colors.white30,
            width: isSelected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }

  // --- Audio Tracks Tab Content ---
  Widget _buildAudioTab(PlayerProvider player, LocaleProvider locale) {
    final isArabic = locale.isArabic;

    if (player.audioTracks.isEmpty) {
      return Center(
        child: Text(
          isArabic ? 'لا توجد مسارات صوتية بديلة' : 'No alternative audio tracks found',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: player.audioTracks.length,
      itemBuilder: (context, index) {
        final track = player.audioTracks[index];
        final isSelected = player.selectedAudioTrack?.id == track.id;
        final title = track.title ?? track.language ?? 'Audio Track #${index + 1}';

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.audiotrack_rounded,
            color: isSelected ? AppColors.netflixRed : Colors.white38,
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.netflixRed, size: 18) : null,
          onTap: () {
            player.selectAudioTrack(track);
            _onUserActivity();
          },
        );
      },
    );
  }

  // --- Playback Speed Tab Content ---
  Widget _buildSpeedTab(PlayerProvider player, LocaleProvider locale) {
    final isArabic = locale.isArabic;
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          isArabic ? 'سرعة العرض (مع الحفاظ على نبرة الصوت)' : 'Playback Speed (Pitch Corrected)',
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...speeds.map((s) {
          final isSelected = player.playbackRate == s;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.speed_rounded,
              color: isSelected ? AppColors.netflixRed : Colors.white38,
              size: 20,
            ),
            title: Text(
              s == 1.0 ? (isArabic ? '1.0x (السرعة الطبيعية)' : '1.0x (Normal)') : '${s}x',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.netflixRed, size: 18) : null,
            onTap: () {
              player.setPlaybackRate(s);
              _onUserActivity();
            },
          );
        }),
        if (player.hasRtxGpu) ...[
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF76B900).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFF76B900), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'NVIDIA RTX Super Resolution' : 'NVIDIA RTX Video Super Resolution',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic ? 'معالجة ومضاعفة الجودة بالذكاء الاصطناعي (Tensor Cores)' : 'AI Real-time Upscaling via Tensor Cores',
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Switch(
                value: player.isRtxVsrEnabled,
                activeColor: const Color(0xFF76B900),
                onChanged: (val) {
                  player.setRtxVsrEnabled(val);
                  _onUserActivity();
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  // --- Helper UI Widgets ---
  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = Colors.white,
    double size = 24,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onPressed();
            _onUserActivity();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, color: color, size: size),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onPressed();
          _onUserActivity();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterCircleButton({
    required IconData icon,
    required double size,
    required double iconSize,
    required String tooltip,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onPressed();
            _onUserActivity();
          },
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isPrimary ? AppColors.netflixRed : Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: isPrimary ? AppColors.netflixRed : Colors.white.withOpacity(0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isPrimary ? AppColors.netflixRed : Colors.black).withOpacity(0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}
