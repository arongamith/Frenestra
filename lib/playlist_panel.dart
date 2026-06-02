import 'package:flutter/material.dart';

enum LoopMode { none, one, all }

class PlaylistPanel extends StatefulWidget {
  final List<String> playlist;
  final int currentIndex;
  final LoopMode loopMode;
  final bool shuffle;
  final VoidCallback onAddFiles;
  final ValueChanged<int> onPlayItem;
  final ValueChanged<int> onRemoveItem;
  final ValueChanged<LoopMode> onLoopModeChanged;
  final ValueChanged<bool> onShuffleChanged;
  final VoidCallback onClose;

  const PlaylistPanel({
    super.key,
    required this.playlist,
    required this.currentIndex,
    required this.loopMode,
    required this.shuffle,
    required this.onAddFiles,
    required this.onPlayItem,
    required this.onRemoveItem,
    required this.onLoopModeChanged,
    required this.onShuffleChanged,
    required this.onClose,
  });

  @override
  State<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends State<PlaylistPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(_animController);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _fileName(String path) => path.split('/').last.split('\\').last;

  IconData get _loopIcon {
    switch (widget.loopMode) {
      case LoopMode.none:
        return Icons.repeat;
      case LoopMode.one:
        return Icons.repeat_one;
      case LoopMode.all:
        return Icons.repeat;
    }
  }

  // Color get _loopColor {
  //   return widget.loopMode == LoopMode.none ? Colors.white30 : Colors.white;
  // }

  void _cycleLoopMode() {
    switch (widget.loopMode) {
      case LoopMode.none:
        widget.onLoopModeChanged(LoopMode.all);
        break;
      case LoopMode.all:
        widget.onLoopModeChanged(LoopMode.one);
        break;
      case LoopMode.one:
        widget.onLoopModeChanged(LoopMode.none);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 300,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xE6141414),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 24,
                  offset: const Offset(-4, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 52),

                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Text(
                        'Playlist',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.playlist.length}',
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: const Icon(Icons.close,
                            color: Colors.white38, size: 18),
                      ),
                    ],
                  ),
                ),

                // Controls row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Add files
                      _PanelButton(
                        icon: Icons.add,
                        label: 'Add',
                        onTap: widget.onAddFiles,
                      ),
                      const Spacer(),

                      // Shuffle
                      _IconToggle(
                        icon: Icons.shuffle,
                        active: widget.shuffle,
                        onTap: () =>
                            widget.onShuffleChanged(!widget.shuffle),
                      ),
                      const SizedBox(width: 8),

                      // Loop
                      _IconToggle(
                        icon: _loopIcon,
                        active: widget.loopMode != LoopMode.none,
                        onTap: _cycleLoopMode,
                        label: widget.loopMode == LoopMode.one ? '1' : null,
                      ),
                    ],
                  ),
                ),

                Container(height: 1, color: Colors.white10),

                // Playlist items
                Expanded(
                  child: widget.playlist.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.queue_music,
                                  color: Colors.white12, size: 48),
                              const SizedBox(height: 12),
                              const Text(
                                'No items in playlist',
                                style: TextStyle(
                                    color: Colors.white24, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              _PanelButton(
                                icon: Icons.add,
                                label: 'Add files',
                                onTap: widget.onAddFiles,
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: widget.playlist.length,
                          onReorder: (oldIndex, newIndex) {
                            // reorder handled in parent
                          },
                          itemBuilder: (context, index) {
                            final isCurrent = index == widget.currentIndex;
                            return _PlaylistItem(
                              key: ValueKey(widget.playlist[index]),
                              index: index,
                              name: _fileName(widget.playlist[index]),
                              isCurrent: isCurrent,
                              onTap: () => widget.onPlayItem(index),
                              onRemove: () => widget.onRemoveItem(index),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistItem extends StatefulWidget {
  final int index;
  final String name;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PlaylistItem({
    super.key,
    required this.index,
    required this.name,
    required this.isCurrent,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_PlaylistItem> createState() => _PlaylistItemState();
}

class _PlaylistItemState extends State<_PlaylistItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isCurrent
                ? Colors.white12
                : _hovered
                    ? Colors.white.withOpacity(0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              // Index or playing indicator
              SizedBox(
                width: 20,
                child: widget.isCurrent
                    ? const Icon(Icons.equalizer,
                        color: Colors.white, size: 14)
                    : Text(
                        '${widget.index + 1}',
                        style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
              ),
              const SizedBox(width: 10),

              // File name
              Expanded(
                child: Text(
                  widget.name,
                  style: TextStyle(
                    color:
                        widget.isCurrent ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: widget.isCurrent
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Remove button
              if (_hovered)
                GestureDetector(
                  onTap: widget.onRemove,
                  child: const Icon(Icons.close,
                      color: Colors.white38, size: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PanelButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_PanelButton> createState() => _PanelButtonState();
}

class _PanelButtonState extends State<_PanelButton> {
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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _pressed
                ? Colors.white.withOpacity(0.16)
                : _hovered
                    ? Colors.white12
                    : Colors.white10,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 5),
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconToggle extends StatefulWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String? label;

  const _IconToggle({
    required this.icon,
    required this.active,
    required this.onTap,
    this.label,
  });

  @override
  State<_IconToggle> createState() => _IconToggleState();
}

class _IconToggleState extends State<_IconToggle> {
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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hovered ? Colors.white10 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                widget.icon,
                color: widget.active ? Colors.white : Colors.white30,
                size: 18,
              ),
              if (widget.label != null)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      widget.label!,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 7,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}