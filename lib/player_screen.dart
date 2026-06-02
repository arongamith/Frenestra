import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';
import 'package:desktop_drop/desktop_drop.dart';
import 'settings_panel.dart';
import 'playlist_panel.dart';


class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
  
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  final FocusNode _focusNode = FocusNode();

  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100;
  bool _isFullscreen = false;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  String? _currentFile;
  double _subtitleDelay = 0.0;
  bool _subtitlesEnabled = true;
  bool _settingsPanelOpen = false;
  List<String> _playlist = [];
  int _currentIndex = -1;
  LoopMode _loopMode = LoopMode.none;
  bool _shuffle = false;
  bool _playlistOpen = false;
  double _audioDelay = 0.0;
  List<AudioTrack> _audioTracks = [];
  AudioTrack? _currentAudioTrack;
  List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack? _currentSubtitleTrack;
  double _volumeBoost = 100.0; // 100 = no boost, 200 = max boost

  Widget _controlButton(IconData icon, VoidCallback onTap,
      {double size = 22, Color color = Colors.white70}) {
    return _HoverIconButton(icon: icon, onTap: onTap, size: size, color: color);
  }

  final List<double> _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    _player.stream.playing.listen((playing) {
      setState(() => _isPlaying = playing);
    });
    _player.stream.position.listen((position) {
      setState(() => _position = position);
    });
    _player.stream.duration.listen((duration) {
      setState(() => _duration = duration);
    });
    _player.stream.tracks.listen((tracks) {
      setState(() {
        _audioTracks = tracks.audio;
        _subtitleTracks = tracks.subtitle;
      });
    });
    _player.stream.track.listen((track) {
      setState(() {
        _currentAudioTrack = track.audio;
        _currentSubtitleTrack = track.subtitle;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _hideTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (_isPlaying) setState(() => _controlsVisible = false);
    });
  }

  void _adjustAudioDelay(double value) {
    setState(() => _audioDelay = value);
    (_player.platform as NativePlayer)
        .setProperty('audio-delay', value.toStringAsFixed(1));
  }

  void _applyVolume() {
    final effective = _isMuted ? 0.0 : (_volume * _volumeBoost / 100).clamp(0.0, 200.0);
    _player.setVolume(effective);
  }

  Future<void> _openFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (result != null) {
      final paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
      setState(() {
        _playlist.addAll(paths);
        _currentIndex = _playlist.length - paths.length;
      });
      await _playIndex(_currentIndex);
    }
  }

  Future<void> _loadFile(String path) async {
    await _player.open(Media(path));
    setState(() => _currentFile = path.split('/').last.split('\\').last);
    await windowManager.setTitle('Fenestra — $_currentFile');
  }
  
  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    setState(() => _currentIndex = index);
    await _loadFile(_playlist[index]);
  }

  Future<void> _loadSubtitle() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'ass', 'ssa', 'vtt', 'sub'],
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      await _player.setSubtitleTrack(
        SubtitleTrack.uri(
          'file://${result.files.single.path!}',
          title: result.files.single.name,
        ),
      );
      _showOSD('Subtitle loaded');
    }
  }
  
  void _adjustSubtitleDelay(double value) {
    setState(() => _subtitleDelay = value);
    (_player.platform as NativePlayer).setProperty('sub-delay', value.toStringAsFixed(1));
  }
  
  void _toggleSubtitles() {
    _subtitlesEnabled = !_subtitlesEnabled;
    if (_subtitlesEnabled) {
      _player.setSubtitleTrack(_player.state.tracks.subtitle.first);
    } else {
      _player.setSubtitleTrack(SubtitleTrack.no());
    }
    setState(() {});
    _showOSD(_subtitlesEnabled ? 'Subtitles on' : 'Subtitles off');
  }

  void _seek(Duration offset) {
    final newPosition = _position + offset;
    _player.seek(newPosition.isNegative ? Duration.zero : newPosition);
    _showControls();
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _player.setRate(speed);
    _showOSD('${speed}x');
  }

  String? _osdMessage;
  Timer? _osdTimer;

  void _showOSD(String message) {
    setState(() => _osdMessage = message);
    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(seconds: 1), () {
      setState(() => _osdMessage = null);
    });
  }

  void _toggleMute() {
    _isMuted = !_isMuted;
    _applyVolume();
    setState(() {});
    _showOSD(_isMuted ? 'Muted' : 'Unmuted');
  }

  void _toggleFullscreen() async {
    _isFullscreen = !_isFullscreen;
    await windowManager.setFullScreen(_isFullscreen);
    setState(() {});
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _player.playOrPause();
        _showControls();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowRight:
        _seek(const Duration(seconds: 5));
        _showOSD('▶▶ 5s');
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowLeft:
        _seek(const Duration(seconds: -5));
        _showOSD('◀◀ 5s');
        return KeyEventResult.handled;

        case LogicalKeyboardKey.arrowUp:
          final newVol = (_volume + 10).clamp(0.0, 100.0);
          setState(() => _volume = newVol);
          _applyVolume();
          _showOSD('Volume ${newVol.toInt()}%');
          _showControls();
          return KeyEventResult.handled;
        
        case LogicalKeyboardKey.arrowDown:
          final newVol = (_volume - 10).clamp(0.0, 100.0);
          setState(() => _volume = newVol);
          _applyVolume();
          _showOSD('Volume ${newVol.toInt()}%');
          _showControls();
          return KeyEventResult.handled;

      case LogicalKeyboardKey.keyF:
        _toggleFullscreen();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyM:
        _toggleMute();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyO:
        _openFile();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.bracketRight:
        final idx = _speeds.indexOf(_playbackSpeed);
        if (idx < _speeds.length - 1) _changeSpeed(_speeds[idx + 1]);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.bracketLeft:
        final idx = _speeds.indexOf(_playbackSpeed);
        if (idx > 0) _changeSpeed(_speeds[idx - 1]);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.backspace:
        _changeSpeed(1.0);
        return KeyEventResult.handled;

        case LogicalKeyboardKey.keyS:
          _toggleSubtitles();
          return KeyEventResult.handled;
        
        case LogicalKeyboardKey.keyZ:
          _adjustSubtitleDelay(-0.1);
          return KeyEventResult.handled;
        
        case LogicalKeyboardKey.keyX:
          _adjustSubtitleDelay(0.1);
          return KeyEventResult.handled;

          case LogicalKeyboardKey.keyN:
            if (_currentIndex < _playlist.length - 1) {
              _playIndex(_currentIndex + 1);
            }
            return KeyEventResult.handled;
          
          case LogicalKeyboardKey.keyP:
            if (_currentIndex > 0) {
              _playIndex(_currentIndex - 1);
            }
            return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DropTarget(
        onDragDone: (details) {
          final paths = details.files.map((f) => f.path).toList();
          setState(() {
            _playlist.addAll(paths);
            _currentIndex = _playlist.length - paths.length;
          });
          _playIndex(_currentIndex);
        },
          child:Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          onHover: (_) => _showControls(),
          onEnter: (_) => _showControls(),
          cursor: _controlsVisible
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          child: GestureDetector(
            onTap: () {
              _focusNode.requestFocus();
              _player.playOrPause();
              _showControls();
            },
            onDoubleTap: _toggleFullscreen,
            child: Stack(
              children: [
                // Video
                Positioned.fill(
                  child: Video(
                    controller: _controller,
                    controls: NoVideoControls,
                  ),
                ),

                // Empty state
                if (_duration == Duration.zero)
                  Center(
                    child: GestureDetector(
                      onTap: _openFile,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_outline,
                              color: Colors.white24, size: 80),
                          const SizedBox(height: 16),
                          const Text('Open a video file',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w300)),
                          const SizedBox(height: 8),
                          const Text('or press O',
                              style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300)),
                        ],
                      ),
                    ),
                  ),

                // OSD message
                if (_osdMessage != null)
                  Positioned(
                    top: 56,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _osdMessage!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),

                // Controls overlay
                AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _buildControls(),
                ),
                
                // Settings panel
                if (_settingsPanelOpen)
                  Positioned.fill(
                    child: SettingsPanel(
                      subtitleDelay: _subtitleDelay,
                      subtitlesEnabled: _subtitlesEnabled,
                      onClose: () => setState(() => _settingsPanelOpen = false),
                      onLoadSubtitle: () {
                        _loadSubtitle();
                        setState(() => _settingsPanelOpen = false);
                      },
                      subtitleTracks: _subtitleTracks,
                      currentSubtitleTrack: _currentSubtitleTrack,
                      onSubtitleTrackChanged: (track) {
                        _player.setSubtitleTrack(track);
                        setState(() => _currentSubtitleTrack = track);
                      },
                      onSubtitleDelayChanged: _adjustSubtitleDelay,
                      onSubtitlesToggled: (value) {
                        setState(() => _subtitlesEnabled = value);
                        if (value) {
                          _player.setSubtitleTrack(_player.state.tracks.subtitle.isNotEmpty
                              ? _player.state.tracks.subtitle.first
                              : SubtitleTrack.no());
                        } else {
                          _player.setSubtitleTrack(SubtitleTrack.no());
                        }
                      },
                      audioDelay: _audioDelay,
                      volume: _volumeBoost,
                      audioTracks: _audioTracks,
                      currentAudioTrack: _currentAudioTrack,
                      onAudioTrackChanged: (track) {
                        _player.setAudioTrack(track);
                        setState(() => _currentAudioTrack = track);
                      },
                      onAudioDelayChanged: _adjustAudioDelay,
                      onVolumeChanged: (value) {
                        setState(() => _volumeBoost = value);
                        _applyVolume();
                      },
                    ),
                  ),
                  // Playlist panel
                  if (_playlistOpen)
                    Positioned.fill(
                      child: PlaylistPanel(
                        playlist: _playlist,
                        currentIndex: _currentIndex,
                        loopMode: _loopMode,
                        shuffle: _shuffle,
                        onClose: () => setState(() => _playlistOpen = false),
                        onAddFiles: _openFile,
                        onPlayItem: _playIndex,
                        onRemoveItem: (index) {
                          setState(() {
                            _playlist.removeAt(index);
                            if (_currentIndex >= _playlist.length) {
                              _currentIndex = _playlist.length - 1;
                            }
                          });
                        },
                        onLoopModeChanged: (mode) => setState(() => _loopMode = mode),
                        onShuffleChanged: (val) => setState(() => _shuffle = val),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        // Titlebar
        GestureDetector(
          onPanStart: (_) => windowManager.startDragging(),
          child: Container(
            height: 40,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xAA000000), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 80),
                const Spacer(),

                // Speed indicator
                if (_playbackSpeed != 1.0)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      '${_playbackSpeed}x',
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Bottom controls
        Container(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
          child: Column(
            children: [
              // Seek bar
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                ),
                child: Slider(
                  value: _duration.inSeconds > 0
                      ? _position.inSeconds
                          .toDouble()
                          .clamp(0, _duration.inSeconds.toDouble())
                      : 0,
                  min: 0,
                  max: _duration.inSeconds > 0
                      ? _duration.inSeconds.toDouble()
                      : 1,
                  onChanged: (value) {
                    _player.seek(Duration(seconds: value.toInt()));
                  },
                ),
              ),

              const SizedBox(height: 4),

              Row(
                children: [
                  // Time — fixed width so it never shifts anything
                  SizedBox(
                    width: 110,
                    child: Text(
                      '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w400),
                    ),
                  ),
              
                  const Spacer(),
              
                  // Previous file
                  if (_playlist.length > 1)
                    _controlButton(Icons.skip_previous, () => _playIndex(_currentIndex - 1),
                        color: _currentIndex > 0 ? Colors.white70 : Colors.white24),
                  if (_playlist.length > 1) const SizedBox(width: 4),
                  
                  // Skip back
                  _controlButton(Icons.replay_10, () => _seek(const Duration(seconds: -10))),
                  const SizedBox(width: 8),
                  
                  // Play/Pause
                  _controlButton(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    _player.playOrPause,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  
                  // Skip forward
                  _controlButton(Icons.forward_10, () => _seek(const Duration(seconds: 10))),
                  const SizedBox(width: 4),
                  
                  // Next file
                  if (_playlist.length > 1)
                    _controlButton(Icons.skip_next, () => _playIndex(_currentIndex + 1),
                        color: _currentIndex < _playlist.length - 1 ? Colors.white70 : Colors.white24),
                  const Spacer(),
              
                  // Speed
                  _SpeedButton(
                    speed: _playbackSpeed,
                    speeds: _speeds,
                    onChanged: _changeSpeed,
                  ),
                  const SizedBox(width: 4),
              
                  // Volume
                  _controlButton(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    _toggleMute,
                    size: 18,
                  ),
                  SizedBox(
                    width: 80,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 10),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white24,
                      ),
                      child: Slider(
                        value: (_isMuted ? 0.0 : _volume).clamp(0.0, 100.0),
                        min: 0,
                        max: 100,
                        onChanged: (value) {
                          setState(() {
                            _volume = value;
                            _isMuted = false;
                          });
                          _applyVolume();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
              
                  // Subtitles
                  _controlButton(
                    _subtitlesEnabled ? Icons.subtitles : Icons.subtitles_off,
                    () => setState(() => _settingsPanelOpen = !_settingsPanelOpen),
                    color: _settingsPanelOpen ? Colors.white : Colors.white70,
                  ),
                  const SizedBox(width: 4),

                  _controlButton(
                    Icons.queue_music,
                    () => setState(() => _playlistOpen = !_playlistOpen),
                    color: _playlistOpen ? Colors.white : Colors.white70,
                  ),
                  const SizedBox(width: 4),
              
                  // Open file
                  _controlButton(Icons.folder_open, _openFile),
                  const SizedBox(width: 4),
              
                  // Fullscreen
                  _controlButton(
                    _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    _toggleFullscreen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget _windowButton(IconData icon, VoidCallback onTap) {
  //   return _HoverButton(icon: icon, onTap: onTap);
  // }
}

class _HoverButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HoverButton({required this.icon, required this.onTap});

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _pressed
                ? Colors.white12
                : _hovered
                    ? Colors.white10
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            color: _pressed
                ? Colors.white70
                : _hovered
                    ? Colors.white54
                    : Colors.white24,
            size: 14,
          ),
        ),
      ),
    );
  }
}

class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color;

  const _HoverIconButton({
    required this.icon,
    required this.onTap,
    this.size = 22,
    this.color = Colors.white70,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _pressed
                ? Colors.white12
                : _hovered
                    ? Colors.white10
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            color: _pressed
                ? Colors.white
                : _hovered
                    ? Colors.white
                    : widget.color,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}

class _SpeedButton extends StatefulWidget {
  final double speed;
  final List<double> speeds;
  final ValueChanged<double> onChanged;

  const _SpeedButton({
    required this.speed,
    required this.speeds,
    required this.onChanged,
  });

  @override
  State<_SpeedButton> createState() => _SpeedButtonState();
}

class _SpeedButtonState extends State<_SpeedButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: PopupMenuButton<double>(
        color: const Color(0xFF1E1E1E),
        onSelected: widget.onChanged,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? Colors.white10 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${widget.speed}x',
            style: TextStyle(
              color: _hovered ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        itemBuilder: (context) => widget.speeds
            .map((s) => PopupMenuItem(
                  value: s,
                  child: Text(
                    '${s}x',
                    style: TextStyle(
                      color: widget.speed == s ? Colors.white : Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}