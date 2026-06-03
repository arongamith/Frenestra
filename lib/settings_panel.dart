import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class SettingsPanel extends StatefulWidget {
  final double subtitleDelay;
  final bool subtitlesEnabled;
  final VoidCallback onLoadSubtitle;
  final ValueChanged<double> onSubtitleDelayChanged;
  final ValueChanged<bool> onSubtitlesToggled;
  final double audioDelay;
  final double volume;
  final List<AudioTrack> audioTracks;
  final AudioTrack? currentAudioTrack;
  final ValueChanged<AudioTrack> onAudioTrackChanged;
  final ValueChanged<double> onAudioDelayChanged;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onClose;
  final List<SubtitleTrack> subtitleTracks;
  final SubtitleTrack? currentSubtitleTrack;
  final ValueChanged<SubtitleTrack> onSubtitleTrackChanged;

  const SettingsPanel({
    super.key,
    required this.subtitleDelay,
    required this.subtitlesEnabled,
    required this.onLoadSubtitle,
    required this.onSubtitleDelayChanged,
    required this.onSubtitlesToggled,
    required this.audioDelay,
    required this.volume,
    required this.audioTracks,
    required this.currentAudioTrack,
    required this.onAudioTrackChanged,
    required this.onAudioDelayChanged,
    required this.onVolumeChanged,
    required this.onClose,
    required this.subtitleTracks,
    required this.currentSubtitleTrack,
    required this.onSubtitleTrackChanged,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late TextEditingController _subDelayController;
  late TextEditingController _audioDelayController;
  late TextEditingController _volumeController;
  late double _localSubDelay;
  late double _localAudioDelay;
  late double _localVolume;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _localSubDelay = widget.subtitleDelay;
    _localAudioDelay = widget.audioDelay;
    _localVolume = widget.volume;
    _subDelayController =
        TextEditingController(text: _localSubDelay.toStringAsFixed(1));
    _audioDelayController =
        TextEditingController(text: _localAudioDelay.toStringAsFixed(1));
    _volumeController =
        TextEditingController(text: _localVolume.toInt().toString());
  }

  @override
  void didUpdateWidget(SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volume != widget.volume) {
      setState(() {
        _localVolume = widget.volume;
        _volumeController.text = widget.volume.toInt().toString();
      });
    }
    if (oldWidget.subtitleDelay != widget.subtitleDelay) {
      setState(() {
        _localSubDelay = widget.subtitleDelay;
        _subDelayController.text = widget.subtitleDelay.toStringAsFixed(1);
      });
    }
    if (oldWidget.audioDelay != widget.audioDelay) {
      setState(() {
        _localAudioDelay = widget.audioDelay;
        _audioDelayController.text = widget.audioDelay.toStringAsFixed(1);
      });
    }
  }

  @override
  void dispose() {
    _subDelayController.dispose();
    _audioDelayController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  void _updateSubDelay(double value) {
    final clamped = double.parse(value.clamp(-30.0, 30.0).toStringAsFixed(1));
    setState(() {
      _localSubDelay = clamped;
      _subDelayController.text = clamped.toStringAsFixed(1);
    });
    widget.onSubtitleDelayChanged(clamped);
  }

  void _updateAudioDelay(double value) {
    final clamped = double.parse(value.clamp(-30.0, 30.0).toStringAsFixed(1));
    setState(() {
      _localAudioDelay = clamped;
      _audioDelayController.text = clamped.toStringAsFixed(1);
    });
    widget.onAudioDelayChanged(clamped);
  }

  void _updateVolume(double value) {
    final clamped = value.clamp(100.0, 200.0);
    setState(() {
      _localVolume = clamped;
      _volumeController.text = clamped.toInt().toString();
    });
    widget.onVolumeChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 300,
        height: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xE6141414),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 24,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 52),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Text('Settings',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3)),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Icon(Icons.close,
                        color: Colors.white38, size: 18),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _Tab(
                      label: 'Audio',
                      selected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0)),
                  const SizedBox(width: 8),
                  _Tab(
                      label: 'Subtitles',
                      selected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1)),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white10),
            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: SingleChildScrollView(
                child: _selectedTab == 0
                    ? _buildAudioTab()
                    : _buildSubtitleTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('TRACK'),
        const SizedBox(height: 12),

        if (widget.audioTracks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('No audio tracks',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          )
        else
          ...widget.audioTracks.map((track) {
            final isSelected = widget.currentAudioTrack?.id == track.id;
            return _TrackItem(
              label: track.title ?? track.language ?? 'Track ${track.id}',
              selected: isSelected,
              onTap: () => widget.onAudioTrackChanged(track),
            );
          }),

        const SizedBox(height: 24),
        _sectionHeader('VOLUME BOOST'),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Boost',
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w400)),
                  const Spacer(),
                  _NumberInput(
                    controller: _volumeController,
                    suffix: '%',
                    onSubmitted: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null) _updateVolume(parsed);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white12,
                ),
                child: Slider(
                  value: _localVolume.clamp(100.0, 200.0),
                  min: 100,
                  max: 200,
                  divisions: 100,
                  onChanged: _updateVolume,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('100%',
                      style:
                          TextStyle(color: Colors.white24, fontSize: 10)),
                  Text('150%',
                      style:
                          TextStyle(color: Colors.white24, fontSize: 10)),
                  Text('200%',
                      style:
                          TextStyle(color: Colors.white24, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _quickButton('Off', () => _updateVolume(100)),
                  const SizedBox(width: 6),
                  _quickButton('+25%', () => _updateVolume(125)),
                  const SizedBox(width: 6),
                  _quickButton('+50%', () => _updateVolume(150)),
                  const SizedBox(width: 6),
                  _quickButton('Max', () => _updateVolume(200)),
                ],
              ),
              const SizedBox(height: 8),
              if (_localVolume > 100)
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 13),
                    SizedBox(width: 6),
                    Text('High boost may cause distortion',
                        style:
                            TextStyle(color: Colors.amber, fontSize: 11)),
                  ],
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _sectionHeader('AUDIO DELAY'),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Delay',
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w400)),
                  const Spacer(),
                  _NumberInput(
                    controller: _audioDelayController,
                    suffix: 's',
                    onSubmitted: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null) _updateAudioDelay(parsed);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white12,
                ),
                child: Slider(
                  value: _localAudioDelay.clamp(-30.0, 30.0),
                  min: -30,
                  max: 30,
                  divisions: 600,
                  onChanged: _updateAudioDelay,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('-30s',
                      style:
                          TextStyle(color: Colors.white24, fontSize: 10)),
                  Text('0',
                      style:
                          TextStyle(color: Colors.white24, fontSize: 10)),
                  Text('+30s',
                      style:
                          TextStyle(color: Colors.white24, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _quickButton('-1s',
                      () => _updateAudioDelay(_localAudioDelay - 1)),
                  const SizedBox(width: 6),
                  _quickButton('-0.1s',
                      () => _updateAudioDelay(_localAudioDelay - 0.1)),
                  const SizedBox(width: 6),
                  _quickButton('Reset', () => _updateAudioDelay(0)),
                  const SizedBox(width: 6),
                  _quickButton('+0.1s',
                      () => _updateAudioDelay(_localAudioDelay + 0.1)),
                  const SizedBox(width: 6),
                  _quickButton('+1s',
                      () => _updateAudioDelay(_localAudioDelay + 1)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSubtitleTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('TRACK'),
        const SizedBox(height: 12),

        if (widget.subtitleTracks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text('No subtitle tracks',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          )
        else
          ...widget.subtitleTracks.map((track) {
            final isSelected =
                widget.currentSubtitleTrack?.id == track.id;
            return _TrackItem(
              label: track.title ?? track.language ?? 'Track ${track.id}',
              selected: isSelected,
              onTap: () => widget.onSubtitleTrackChanged(track),
            );
          }),

        const SizedBox(height: 16),
        _sectionHeader('VISIBILITY'),
        const SizedBox(height: 12),

        _settingRow(
          label: 'Enabled',
          trailing: Switch(
            value: widget.subtitlesEnabled,
            onChanged: widget.onSubtitlesToggled,
            activeColor: Colors.white,
            activeTrackColor: Colors.white30,
            inactiveTrackColor: Colors.white12,
            inactiveThumbColor: Colors.white38,
          ),
        ),

        _settingRow(
          label: 'Load file',
          trailing: GestureDetector(
            onTap: widget.onLoadSubtitle,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Browse',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),
          ),
        ),

        const SizedBox(height: 20),
        _sectionHeader('SUBTITLE DELAY'),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Delay',
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w400)),
                  const Spacer(),
                  _NumberInput(
                    controller: _subDelayController,
                    suffix: 's',
                    onSubmitted: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null) _updateSubDelay(parsed);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white12,
                ),
                child: Slider(
                  value: _localSubDelay.clamp(-30.0, 30.0),
                  min: -30,
                  max: 30,
                  divisions: 600,
                  onChanged: _updateSubDelay,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('-30s',
                      style:
                          TextStyle(color: Colors.white24, fontSize: 10)),
                  Text('0',
                      style:
                          TextStyle(color: Colors.white24, fontSize: 10)),
                  Text('+30s',
                      style:
                          TextStyle(color: Colors.white24, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _quickButton(
                      '-1s', () => _updateSubDelay(_localSubDelay - 1)),
                  const SizedBox(width: 6),
                  _quickButton('-0.1s',
                      () => _updateSubDelay(_localSubDelay - 0.1)),
                  const SizedBox(width: 6),
                  _quickButton('Reset', () => _updateSubDelay(0)),
                  const SizedBox(width: 6),
                  _quickButton('+0.1s',
                      () => _updateSubDelay(_localSubDelay + 0.1)),
                  const SizedBox(width: 6),
                  _quickButton(
                      '+1s', () => _updateSubDelay(_localSubDelay + 1)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title,
          style: const TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2)),
    );
  }

  Widget _settingRow({required String label, required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w400)),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }

  Widget _quickButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.selected, required this.onTap});

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.white12
                : _hovered
                    ? Colors.white10
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(widget.label,
              style: TextStyle(
                  color: widget.selected ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: widget.selected
                      ? FontWeight.w500
                      : FontWeight.w400)),
        ),
      ),
    );
  }
}

class _TrackItem extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TrackItem(
      {required this.label, required this.selected, required this.onTap});

  @override
  State<_TrackItem> createState() => _TrackItemState();
}

class _TrackItemState extends State<_TrackItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: _hovered
              ? Colors.white.withOpacity(0.04)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                widget.selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: widget.selected ? Colors.white : Colors.white30,
                size: 14,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.label,
                    style: TextStyle(
                        color: widget.selected
                            ? Colors.white
                            : Colors.white60,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String suffix;
  final ValueChanged<String> onSubmitted;

  const _NumberInput({
    required this.controller,
    required this.suffix,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              onSubmitted: onSubmitted,
              onTapOutside: (_) => onSubmitted(controller.text),
            ),
          ),
          Text(suffix,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}