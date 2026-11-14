import 'dart:async';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/library_provider.dart';
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

  // Modern Popovers & Drawers State (Matches 100% Reference Design)
  bool _showSettingsPopover = false;
  bool _showSubtitlesPopover = false;
  bool _showEpisodesDrawer = false;
  bool _showSubCustomize = false;
  int _selectedSeason = 1;
  final ScrollController _episodeScrollController = ScrollController();

  // Subtitle search
  final TextEditingController _subSearchController = TextEditingController();
  final String _selectedSubLang = 'ara';

  // Scrubber Hover Preview (Trickplay)
  bool _isScrubberHovered = false;
  double _scrubberHoverFraction = 0.0;
  double _scrubberHoverLocalX = 0.0;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<PlayerProvider>();
      if (player.currentMedia?.seasonNumber != null) {
        setState(() {
          _selectedSeason = player.currentMedia!.seasonNumber!;
        });
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekOsdTimer?.cancel();
    _subSearchController.dispose();
    _focusNode.dispose();
    _searchFocusNode.dispose();
    _episodeScrollController.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted &&
          !_showSettingsPopover &&
          !_showSubtitlesPopover &&
          !_showEpisodesDrawer &&
          !_isScrubberHovered &&
          !_searchFocusNode.hasFocus) {
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

  void _toggleSettingsPopover() {
    setState(() {
      _showSettingsPopover = !_showSettingsPopover;
      _showSubtitlesPopover = false;
      _showEpisodesDrawer = false;
    });
    _onUserActivity();
  }

  void _toggleSubtitlesPopover() {
    setState(() {
      _showSubtitlesPopover = !_showSubtitlesPopover;
      _showSettingsPopover = false;
      _showEpisodesDrawer = false;
      _showSubCustomize = false;
    });
    if (_showSubtitlesPopover) {
      final player = context.read<PlayerProvider>();
      final media = player.currentMedia;
      String q = media?.seriesTitle ?? media?.title ?? '';
      if (media?.seasonNumber != null && media?.episodeNumber != null) {
        q = '$q S${media!.seasonNumber!.toString().padLeft(2, '0')}E${media.episodeNumber!.toString().padLeft(2, '0')}';
      }
      _subSearchController.text = q;
      if (player.onlineSubtitles.isEmpty && !player.isSearchingOnlineSubtitles) {
        player.searchOnlineSubtitles(q, lang: _selectedSubLang);
      }
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _showSubtitlesPopover) {
          _searchFocusNode.requestFocus();
        }
      });
    } else {
      _searchFocusNode.unfocus();
      _focusNode.requestFocus();
    }
    _onUserActivity();
  }

  void _toggleEpisodesDrawer() {
    setState(() {
      _showEpisodesDrawer = !_showEpisodesDrawer;
      _showSettingsPopover = false;
      _showSubtitlesPopover = false;
      if (_showEpisodesDrawer) {
        final player = context.read<PlayerProvider>();
        final currSeason = player.currentMedia?.seasonNumber;
        if (currSeason != null) {
          _selectedSeason = currSeason;
        }
      }
    });
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (_searchFocusNode.hasFocus) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
              setState(() => _showSubtitlesPopover = false);
              _searchFocusNode.unfocus();
              _focusNode.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          }
          if (event is KeyDownEvent) {
            _onUserActivity();
            if (event.logicalKey == LogicalKeyboardKey.space) {
              player.playPause();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              if (isArabic) {
                player.seekBackward10();
                _triggerSeekOsd('-10s');
              } else {
                player.seekForward10();
                _triggerSeekOsd('+10s');
              }
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              if (isArabic) {
                player.seekForward10();
                _triggerSeekOsd('+10s');
              } else {
                player.seekBackward10();
                _triggerSeekOsd('-10s');
              }
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              player.adjustVolume(5);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              player.adjustVolume(-5);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyF ||
                event.logicalKey == LogicalKeyboardKey.f11) {
              _toggleFullscreen();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
              player.toggleMute();
              _onUserActivity();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyZ) {
              player.adjustSubtitleDelay(-0.1);
              _triggerSeekOsd('Sub -100ms (${player.subtitleDelay > 0 ? "+" : ""}${player.subtitleDelay.toStringAsFixed(1)}s)');
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyX) {
              player.adjustSubtitleDelay(0.1);
              _triggerSeekOsd('Sub +100ms (${player.subtitleDelay > 0 ? "+" : ""}${player.subtitleDelay.toStringAsFixed(1)}s)');
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyB) {
              player.toggleDialogueBoost();
              _triggerSeekOsd(player.isDialogueBoostActive ? 'Dialogue Boost ON' : 'Dialogue Boost OFF');
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
              player.toggleRtxVsr();
              _triggerSeekOsd(player.isRtxVsrActive ? 'RTX VSR ON' : 'RTX VSR OFF');
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
              player.toggleAmbientGlow();
              _triggerSeekOsd(player.isAmbientGlowActive ? 'Ambient Glow ON' : 'Ambient Glow OFF');
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              if (_showSettingsPopover || _showSubtitlesPopover || _showEpisodesDrawer) {
                setState(() {
                  _showSettingsPopover = false;
                  _showSubtitlesPopover = false;
                  _showEpisodesDrawer = false;
                });
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
              // 0. Dynamic Ambient Theatre Glow (Ambilight Aura)
              if (player.isAmbientGlowActive)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.18,
                          colors: [
                            Colors.transparent,
                            player.isRtxVsrActive
                                ? const Color(0xFF76B900).withOpacity(0.04)
                                : player.isDialogueBoostActive
                                    ? const Color(0xFF00E5FF).withOpacity(0.04)
                                    : const Color(0xFFE50914).withOpacity(0.04),
                            const Color(0xFF101018).withOpacity(0.55),
                            Colors.black.withOpacity(0.92),
                          ],
                          stops: const [0.35, 0.72, 0.88, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

              // 1. Hardware Accelerated Video Player Surface
              Center(
                child: Video(
                  controller: player.videoController,
                  controls: NoVideoControls,
                  subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
                ),
              ),

              // 2. Custom Responsive Subtitle Overlay
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

              // 3. Background Click Gestures & Mouse-Wheel Volume
              Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent &&
                      !_showSettingsPopover &&
                      !_showSubtitlesPopover &&
                      !_showEpisodesDrawer) {
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
                    if (_showSettingsPopover || _showSubtitlesPopover || _showEpisodesDrawer) {
                      setState(() {
                        _showSettingsPopover = false;
                        _showSubtitlesPopover = false;
                        _showEpisodesDrawer = false;
                      });
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

              // 4. Seek OSD Pill Overlay (±10s)
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 5. Cinematic HUD Overlay Controls
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Stack(
                    children: [
                      // Top gradient shadow
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 120,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.75),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Bottom gradient shadow
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 170,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.85),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // CLEAN TOP BAR (Zero clutter! Back button + Title/Episode only)
                      Positioned(
                        top: 24,
                        left: 28,
                        right: 28,
                        child: Row(
                          children: [
                            _buildBarIconButton(
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
                          ],
                        ),
                      ),

                      // Center Transport Controls
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

                      // BOTTOM CONTROLS BAR (Matches 100% Image 4 Reference)
                      Positioned(
                        bottom: 24,
                        left: 28,
                        right: 28,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Sleek 3-Tier Scrubber
                            _build3TierRedScrubber(player, isArabic),
                            const SizedBox(height: 10),

                            // Controls Row
                            Row(
                              children: [
                                // Play / Pause Button
                                _buildBarIconButton(
                                  icon: player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  tooltip: player.isPlaying
                                      ? (isArabic ? 'إيقاف مؤقت' : 'Pause')
                                      : (isArabic ? 'تشغيل' : 'Play'),
                                  size: 26,
                                  onPressed: () {
                                    player.playPause();
                                  },
                                ),
                                const SizedBox(width: 6),

                                // Rewind 10s (↺10)
                                _buildBarIconButton(
                                  icon: Icons.replay_10_rounded,
                                  tooltip: isArabic ? 'تأخير 10 ثوانٍ' : 'Rewind 10s',
                                  size: 22,
                                  onPressed: () {
                                    player.seekBackward10();
                                    _triggerSeekOsd('-10s');
                                  },
                                ),
                                const SizedBox(width: 6),

                                // Forward 10s (↻10)
                                _buildBarIconButton(
                                  icon: Icons.forward_10_rounded,
                                  tooltip: isArabic ? 'تقديم 10 ثوانٍ' : 'Forward 10s',
                                  size: 22,
                                  onPressed: () {
                                    player.seekForward10();
                                    _triggerSeekOsd('+10s');
                                  },
                                ),
                                const SizedBox(width: 6),

                                // Next Episode Button (if available)
                                if (player.nextEpisode != null) ...[
                                  _buildBarIconButton(
                                    icon: Icons.skip_next_rounded,
                                    tooltip: isArabic
                                        ? 'الحلقة التالية (${player.nextEpisode!.title})'
                                        : 'Next Episode (${player.nextEpisode!.title})',
                                    size: 24,
                                    onPressed: () {
                                      player.playNextEpisode();
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                ],

                                // Volume Control (Icon + Slider + Percentage)
                                _buildVolumeControl(player),

                                const SizedBox(width: 14),

                                // Time (25:09 / 42:55)
                                Text(
                                  '${_formatDuration(player.position)} / ${_formatDuration(player.duration)}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),

                                const Spacer(),

                                // Episodes Drawer Button (Layers icon from Image 4)
                                if (player.seriesEpisodes.isNotEmpty || media?.seriesTitle != null) ...[
                                  _buildBarIconButton(
                                    icon: Icons.layers_rounded,
                                    tooltip: isArabic ? 'الحلقات' : 'Episodes',
                                    isActive: _showEpisodesDrawer,
                                    onPressed: _toggleEpisodesDrawer,
                                  ),
                                  const SizedBox(width: 10),
                                ],



                                // Subtitles Button (CC) - Active white circle when open
                                _buildBarIconButton(
                                  icon: Icons.closed_caption_rounded,
                                  tooltip: isArabic ? 'الترجمة' : 'Subtitles',
                                  isActive: _showSubtitlesPopover,
                                  iconColor: player.selectedSubtitle != null ? AppColors.netflixRed : Colors.white,
                                  onPressed: _toggleSubtitlesPopover,
                                ),
                                const SizedBox(width: 10),

                                // Settings Button (⚙️) - Active white circle when open
                                _buildBarIconButton(
                                  icon: Icons.settings_rounded,
                                  tooltip: isArabic ? 'الإعدادات' : 'Settings',
                                  isActive: _showSettingsPopover,
                                  onPressed: _toggleSettingsPopover,
                                ),
                                const SizedBox(width: 10),

                                // Fullscreen Button
                                _buildBarIconButton(
                                  icon: Icons.fullscreen_rounded,
                                  tooltip: isArabic ? 'ملء الشاشة' : 'Fullscreen (F)',
                                  size: 24,
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

              // 6. Skip Intro Floating Button
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

              // 7. Next Episode Prompt Card
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
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          player.nextEpisode!.title,
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.netflixRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              player.playNextEpisode();
                              _onUserActivity();
                            },
                            child: Text(
                              isArabic ? 'تشغيل الآن' : 'Play Now',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 8. Horizontal Episode Drawer (Shelf above scrubber matching Image 4)
              if (_showEpisodesDrawer)
                Positioned(
                  bottom: 84,
                  left: 28,
                  right: 28,
                  height: 235,
                  child: _buildEpisodesDrawer(player, isArabic),
                ),

              // 9. Settings Popover (Liquid Glass iOS 27 matching Image 2)
              if (_showSettingsPopover)
                Positioned(
                  bottom: 78,
                  right: 28,
                  width: 320,
                  child: _buildSettingsPopover(player, locale),
                ),

              // 10. Subtitles Popover (Liquid Glass iOS 27 matching Image 3)
              if (_showSubtitlesPopover)
                Positioned(
                  bottom: 78,
                  right: 76,
                  width: 340,
                  height: 490,
                  child: _buildSubtitlesPopover(player, locale),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Volume Control Widget (Icon + Slider + Percentage) ---
  Widget _buildVolumeControl(PlayerProvider player) {
    return Row(
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
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () {
            player.toggleMute();
            _onUserActivity();
          },
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 80,
          child: SliderTheme(
            data: const SliderThemeData(
              trackHeight: 3,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 9),
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
        const SizedBox(width: 4),
        SizedBox(
          width: 34,
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
    );
  }

  // --- Liquid Glass Bar Icon Button with Active White Circle Highlight ---
  Widget _buildBarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isActive = false,
    Color iconColor = Colors.white,
    double size = 22,
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
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? Colors.transparent : Colors.white.withOpacity(0.12),
                width: 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                icon,
                color: isActive ? Colors.black : iconColor,
                size: size,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Center Circle Button ---
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

  // --- 1. SETTINGS POPOVER (Matches Image 2 100%) ---
  Widget _buildSettingsPopover(PlayerProvider player, LocaleProvider locale) {
    final isArabic = locale.isArabic;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141418).withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.14), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2x2 Metric Tiles Grid
              Row(
                children: [
                  // Top-Left: QUALITY
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.high_quality_rounded,
                      label: isArabic ? 'الجودة' : 'QUALITY',
                      value: player.videoQualityLabel,
                      isActive: false,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Top-Right: RTX VSR (NVIDIA Green Glow when active)
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.bolt_rounded,
                      label: isArabic ? 'معالجة RTX' : 'RTX VSR',
                      value: player.hasRtxGpu ? (player.isRtxVsrActive ? 'Active' : 'Off') : 'N/A',
                      isActive: player.isRtxVsrActive,
                      activeColor: const Color(0xFF76B900),
                      onTap: () {
                        if (player.hasRtxGpu) {
                          player.toggleRtxVsr();
                          _onUserActivity();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Bottom-Left: SUBTITLES
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.closed_caption_rounded,
                      label: isArabic ? 'الترجمة' : 'SUBTITLES',
                      value: player.selectedSubtitle != null ? player.subtitleLabel : 'Off',
                      isActive: player.selectedSubtitle != null,
                      activeColor: AppColors.netflixRed,
                      onTap: () {
                        setState(() {
                          _showSettingsPopover = false;
                          _showSubtitlesPopover = true;
                        });
                        _onUserActivity();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bottom-Right: AUDIO
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.music_note_rounded,
                      label: isArabic ? 'الصوت' : 'AUDIO',
                      value: player.audioTrackLabel,
                      isActive: false,
                      onTap: () {
                        if (player.audioTracks.length > 1) {
                          final currIdx = player.selectedAudioTrack != null
                              ? player.audioTracks.indexOf(player.selectedAudioTrack!)
                              : 0;
                          final nextIdx = (currIdx + 1) % player.audioTracks.length;
                          player.selectAudioTrack(player.audioTracks[nextIdx]);
                          _onUserActivity();
                        }
                      },
                    ),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: Colors.white12, height: 1),
              ),

              // Dialogue Boost (Night Mode) Toggle Row
              _buildSettingsSwitchRow(
                icon: Icons.graphic_eq_rounded,
                title: isArabic ? 'مضخم الحوارات والصوت' : 'Dialogue Boost',
                value: player.isDialogueBoostActive,
                activeColor: const Color(0xFF00E5FF),
                onChanged: (val) {
                  player.toggleDialogueBoost();
                  _onUserActivity();
                },
              ),

              // Ambient Glow Toggle Row
              _buildSettingsSwitchRow(
                icon: Icons.auto_awesome_rounded,
                title: isArabic ? 'الإضاءة المحيطية السينمائية' : 'Ambient Glow',
                value: player.isAmbientGlowActive,
                activeColor: const Color(0xFFFFB300),
                onChanged: (val) {
                  player.toggleAmbientGlow();
                  _onUserActivity();
                },
              ),

              // Enable Subtitles Toggle Row
              _buildSettingsSwitchRow(
                icon: Icons.closed_caption_rounded,
                title: isArabic ? 'تفعيل الترجمة' : 'Enable Subtitles',
                value: player.selectedSubtitle != null,
                activeColor: AppColors.netflixRed,
                onChanged: (val) {
                  if (val) {
                    if (player.subtitles.isNotEmpty) {
                      player.selectSubtitle(player.subtitles.first);
                    } else {
                      player.pickAndLoadLocalSubtitle();
                    }
                  } else {
                    player.disableSubtitles();
                  }
                  _onUserActivity();
                },
              ),

              // Playback Speed Selector Row
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Icon(Icons.speed_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isArabic ? 'سرعة التشغيل' : 'Playback Speed',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: [0.75, 1.0, 1.25, 1.5].map((s) {
                        final isSel = player.playbackRate == s;
                        return InkWell(
                          onTap: () {
                            player.setPlaybackRate(s);
                            _onUserActivity();
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.netflixRed : Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${s}x',
                              style: TextStyle(
                                color: isSel ? Colors.white : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Audio Delay / Sync Row
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Icon(Icons.sync_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isArabic ? 'مزامنة الصوت' : 'Audio Sync',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => player.adjustAudioDelay(-0.1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('-100ms', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            player.audioDelay == 0.0
                                ? '0.0s'
                                : '${player.audioDelay > 0 ? "+" : ""}${player.audioDelay.toStringAsFixed(1)}s',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        InkWell(
                          onTap: () => player.adjustAudioDelay(0.1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('+100ms', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Subtitle Settings Navigation Row
              InkWell(
                onTap: () {
                  setState(() {
                    _showSettingsPopover = false;
                    _showSubtitlesPopover = true;
                    _showSubCustomize = true;
                  });
                  _onUserActivity();
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.format_size_rounded, color: Colors.white70, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isArabic ? 'تخصيص الخط والترجمة' : 'Subtitle Settings',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper metric tile for 2x2 grid
  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isActive,
    Color activeColor = const Color(0xFF76B900),
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withOpacity(0.15) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? activeColor.withOpacity(0.85) : Colors.white.withOpacity(0.09),
              width: 1.2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.35),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: isActive ? activeColor : Colors.white54, size: 13),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isActive ? activeColor : Colors.white60,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSwitchRow({
    required IconData icon,
    required String title,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: value ? activeColor : Colors.white70, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: value,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // --- 2. SUBTITLES POPOVER (Matches Image 3 100%) ---
  Widget _buildSubtitlesPopover(PlayerProvider player, LocaleProvider locale) {
    final isArabic = locale.isArabic;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141418).withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.14), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Subtitles & Customize
              Row(
                children: [
                  Text(
                    isArabic ? 'الترجمة' : 'Subtitles',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      setState(() => _showSubCustomize = !_showSubCustomize);
                      _onUserActivity();
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        _showSubCustomize
                            ? (isArabic ? 'تم' : 'Done')
                            : (isArabic ? 'تخصيص' : 'Customize'),
                        style: TextStyle(
                          color: _showSubCustomize ? AppColors.netflixRed : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Customize View (Font size, position, colors)
              if (_showSubCustomize) ...[
                Expanded(
                  child: ListView(
                    children: [
                      // Font size
                      Text(
                        '${isArabic ? "حجم الخط" : "Font Size"} (${player.subtitleFontSize.round()}px)',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
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
                      const SizedBox(height: 8),

                      // Position from bottom
                      Text(
                        '${isArabic ? "ارتفاع الترجمة عن الأسفل" : "Subtitle Position"} (${player.subtitleBottomPadding.round()}px)',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      SliderTheme(
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
                      const SizedBox(height: 8),

                      // Colors
                      Text(
                        isArabic ? 'لون الخط' : 'Font Color',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildColorChip(player, Colors.white, 'White'),
                          const SizedBox(width: 8),
                          _buildColorChip(player, const Color(0xFFFFEB3B), 'Yellow'),
                          const SizedBox(width: 8),
                          _buildColorChip(player, const Color(0xFF00E5FF), 'Cyan'),
                          const SizedBox(width: 8),
                          _buildColorChip(player, const Color(0xFF69F0AE), 'Green'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Background transparent toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isArabic ? 'خلفية شفافة' : 'Transparent Background',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: player.subtitleTransparentBackground,
                            activeColor: AppColors.netflixRed,
                            onChanged: (val) {
                              player.setSubtitleTransparentBackground(val);
                              _onUserActivity();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Option 1: Off (with green checkmark if no subtitle active)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    isArabic ? 'إيقاف الترجمة' : 'Off',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  trailing: player.selectedSubtitle == null
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF76B900), size: 20)
                      : null,
                  onTap: () {
                    player.disableSubtitles();
                    _onUserActivity();
                  },
                ),

                // Option 2: Upload subtitle file (with upload icon)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    isArabic ? 'رفع ملف ترجمة' : 'Upload subtitle file',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.upload_rounded, color: Colors.white70, size: 20),
                  onTap: () {
                    player.pickAndLoadLocalSubtitle();
                    _onUserActivity();
                  },
                ),

                // Option 3: Sync subtitle to audio
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isArabic ? 'مزامنة الترجمة' : 'Sync subtitle to audio',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      InkWell(
                        onTap: () => player.adjustSubtitleDelay(-0.5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('-0.5s', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          player.subtitleDelay == 0.0
                              ? '0.0s'
                              : '${player.subtitleDelay > 0 ? "+" : ""}${player.subtitleDelay.toStringAsFixed(1)}s',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      InkWell(
                        onTap: () => player.adjustSubtitleDelay(0.5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('+0.5s', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white12, height: 16),

                // Search Bar for OpenSubtitles
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _searchFocusNode.hasFocus
                          ? const Color(0xFF76B900)
                          : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _subSearchController,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    cursorColor: Colors.white,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: isArabic ? 'بحث في الترجمات...' : 'Search subtitles...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_subSearchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 16),
                              onPressed: () {
                                _subSearchController.clear();
                                setState(() {});
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF76B900), size: 18),
                            tooltip: isArabic ? 'بحث' : 'Search',
                            onPressed: () {
                              final query = _subSearchController.text.trim();
                              if (query.isNotEmpty) {
                                player.searchOnlineSubtitles(query, lang: _selectedSubLang);
                              }
                            },
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                    ),
                    onChanged: (text) => setState(() {}),
                    onSubmitted: (query) {
                      if (query.trim().isNotEmpty) {
                        player.searchOnlineSubtitles(query.trim(), lang: _selectedSubLang);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitles List (Local & Online)
                Expanded(
                  child: ListView(
                    children: [
                      // Local / Embedded tracks
                      if (player.subtitles.isNotEmpty) ...[
                        Text(
                          isArabic ? 'الترجمات المحلية المكتشفة' : 'Local Tracks',
                          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ...player.subtitles.map((track) {
                          final isSelected = player.selectedSubtitle?.path == track.path;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.subtitles_outlined,
                              color: isSelected ? const Color(0xFF76B900) : Colors.white54,
                              size: 18,
                            ),
                            title: Text(
                              track.title,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF76B900), size: 18)
                                : null,
                            onTap: () {
                              player.selectSubtitle(track);
                              _onUserActivity();
                            },
                          );
                        }),
                      ],

                      // Online OpenSubtitles search results
                      if (player.isSearchingOnlineSubtitles)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: AppColors.netflixRed, strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (player.onlineSubtitles.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          isArabic ? 'نتائج البحث أونلاين' : 'Online Results (OpenSubtitles)',
                          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ...player.onlineSubtitles.map((onlineSub) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              onlineSub.releaseName.isNotEmpty ? onlineSub.releaseName : onlineSub.fileName,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${onlineSub.languageName} • ${onlineSub.rating ?? 0.0} ★',
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.download_rounded, color: AppColors.netflixRed, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                await player.downloadAndApplyOnlineSubtitle(onlineSub);
                                _onUserActivity();
                              },
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorChip(PlayerProvider player, Color color, String name) {
    final isSelected = player.subtitleColor.value == color.value;
    return InkWell(
      onTap: () {
        player.setSubtitleColor(color);
        _onUserActivity();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
      ),
    );
  }

  // --- 3. HORIZONTAL EPISODE DRAWER (Matches Image 4 100%) ---
  Widget _buildEpisodesDrawer(PlayerProvider player, bool isArabic) {
    final library = context.read<LibraryProvider>();
    var allEpisodes = player.seriesEpisodes;
    if (allEpisodes.isEmpty && player.currentMedia != null) {
      final sTitle = player.currentMedia?.seriesTitle ?? player.currentMedia?.title;
      if (sTitle != null) {
        allEpisodes = library.seriesGrouped[sTitle] ?? [];
        if (allEpisodes.isEmpty) {
          for (final entry in library.seriesGrouped.entries) {
            if (entry.key.toLowerCase().trim() == sTitle.toLowerCase().trim()) {
              allEpisodes = entry.value;
              break;
            }
          }
        }
      }
    }

    final seasons = allEpisodes.map((e) => e.seasonNumber ?? 1).toSet().toList()..sort();
    final currentSeason = seasons.contains(_selectedSeason)
        ? _selectedSeason
        : (player.currentMedia?.seasonNumber != null && seasons.contains(player.currentMedia!.seasonNumber!)
            ? player.currentMedia!.seasonNumber!
            : (seasons.isNotEmpty ? seasons.first : 1));
    final seasonEpisodes = allEpisodes.where((e) => (e.seasonNumber ?? 1) == currentSeason).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF101014).withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.14), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drawer Bar: Season selector dropdown + Episode count + Close
              Row(
                children: [
                  PopupMenuButton<int>(
                    onSelected: (s) => setState(() => _selectedSeason = s),
                    color: const Color(0xFF1E1E24),
                    itemBuilder: (ctx) => seasons.map((s) {
                      return PopupMenuItem<int>(
                        value: s,
                        child: Text(
                          '${isArabic ? "الموسم" : "Season"} $s',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${isArabic ? "الموسم" : "Season"} $currentSeason',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '• ${seasonEpisodes.length} ${isArabic ? "حلقة" : "Episodes"}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _showEpisodesDrawer = false),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Horizontal Cards Row with Chevrons
              Expanded(
                child: Row(
                  children: [
                    // Left Chevron Scroll Button
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _episodeScrollController.animateTo(
                          (_episodeScrollController.offset - 300).clamp(0, _episodeScrollController.position.maxScrollExtent),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                    ),
                    const SizedBox(width: 6),

                    // Cards List
                    Expanded(
                      child: ListView.builder(
                        controller: _episodeScrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: seasonEpisodes.length,
                        itemBuilder: (context, idx) {
                          final ep = seasonEpisodes[idx];
                          final isCurrent = ep.filePath == player.currentMedia?.filePath;

                          return InkWell(
                            onTap: () {
                              final epIdx = seasonEpisodes.indexOf(ep);
                              final nextEp = (epIdx != -1 && epIdx < seasonEpisodes.length - 1)
                                  ? seasonEpisodes[epIdx + 1]
                                  : null;
                              player.openMedia(ep, nextEp: nextEp, seriesEpisodes: allEpisodes);
                              _onUserActivity();
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 210,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? Colors.white.withOpacity(0.12)
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCurrent
                                      ? const Color(0xFF76B900)
                                      : Colors.white.withOpacity(0.08),
                                  width: isCurrent ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 16:9 Thumbnail
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                                    child: Stack(
                                      children: [
                                        SizedBox(
                                          height: 95,
                                          width: double.infinity,
                                          child: (ep.backdropUrl != null || ep.posterUrl != null)
                                              ? Image.network(
                                                  ep.backdropUrl ?? ep.posterUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => _buildEpisodePlaceholder(),
                                                )
                                              : _buildEpisodePlaceholder(),
                                        ),
                                        // Badge over thumbnail
                                        Positioned(
                                          top: 6,
                                          left: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: isCurrent
                                                  ? const Color(0xFF76B900)
                                                  : Colors.black.withOpacity(0.75),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isCurrent
                                                  ? 'S${ep.seasonNumber ?? currentSeason}E${ep.episodeNumber ?? (idx + 1)} - Now Playing'
                                                  : 'S${ep.seasonNumber ?? currentSeason}E${ep.episodeNumber ?? (idx + 1)}',
                                              style: TextStyle(
                                                color: isCurrent ? Colors.black : Colors.white,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Details below thumbnail
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ep.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          (ep.overview != null && ep.overview!.isNotEmpty)
                                              ? ep.overview!
                                              : (isArabic ? 'انقر للتشغيل والمشاهدة' : 'Click to stream episode'),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 10,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Right Chevron Scroll Button
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _episodeScrollController.animateTo(
                          (_episodeScrollController.offset + 300).clamp(0, _episodeScrollController.position.maxScrollExtent),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF232332),
            Colors.black.withOpacity(0.9),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 28),
      ),
    );
  }

  // --- Custom 3-Tier Red Scrubber with Hover Trickplay Preview Tooltip ---
  Widget _build3TierRedScrubber(PlayerProvider player, bool isArabic) {
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

                  // Smart Chapter Divisor Notches
                  for (final ch in player.effectiveChapters)
                    if (durMs > 0 && ch.time > Duration.zero)
                      Positioned(
                        left: width * (ch.time.inMilliseconds / durMs).clamp(0.0, 1.0),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 2.5,
                          color: Colors.black.withOpacity(0.85),
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
                      left: (_scrubberHoverLocalX - 95).clamp(8.0, width - 198.0),
                      bottom: 26,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: 190,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14141E).withOpacity(0.92),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.6),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                                if (player.isRtxVsrActive)
                                  BoxShadow(
                                    color: const Color(0xFF76B900).withOpacity(0.2),
                                    blurRadius: 10,
                                  ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 16:9 Live Media Visual Snapshot Header
                                Container(
                                  height: 85,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24, width: 0.8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (player.currentMedia?.backdropUrl != null ||
                                            player.currentMedia?.posterUrl != null)
                                          Image.network(
                                            player.currentMedia!.backdropUrl ?? player.currentMedia!.posterUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _buildEpisodePlaceholder(),
                                          )
                                        else
                                          _buildEpisodePlaceholder(),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.85),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 4,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.85),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.white24, width: 0.8),
                                            ),
                                            child: Text(
                                              _formatDuration(hoverTime),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Chapter Badge
                                if (player.getChapterAt(hoverTime) != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.netflixRed.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.netflixRed.withOpacity(0.6), width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.bookmark_rounded, color: AppColors.netflixRed, size: 11),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            player.getChapterAt(hoverTime)!.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                ],
                                // Quick Jump hint
                                Text(
                                  isArabic ? 'انقر للقفز إلى هنا' : 'Click to jump here',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
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
}
