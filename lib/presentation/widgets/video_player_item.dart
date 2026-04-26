import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/video_entity.dart';
import '../bloc/download_bloc.dart';
import '../bloc/download_event.dart';
import '../bloc/download_state.dart';

/// Renders a single full-screen video with metadata overlay.
///
/// [controller] may be null while the BLoC is still initializing it.
/// In that case a loading spinner is shown.
class VideoPlayerItem extends StatefulWidget {
  final VideoEntity video;
  final VideoPlayerController? controller;
  final bool isActive;

  const VideoPlayerItem({
    super.key,
    required this.video,
    required this.controller,
    required this.isActive,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  bool _showControls = false;

  void _toggleControls() {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;

    // Toggle playback.
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }

    // Show the overlay briefly so the user sees the play/pause indicator.
    setState(() => _showControls = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isReady = controller != null && controller.value.isInitialized;

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video / Loading indicator
          if (isReady)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white54,
                  strokeWidth: 2,
                ),
              ),
            ),

          // Tap-to-pause overlay
          if (_showControls && isReady)
            Center(
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),

          // Metadata overlay (bottom-left)
          Positioned(
            bottom: 80,
            left: 16,
            right: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.video.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.video.caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Right-side action buttons
          Positioned(
            bottom: 80,
            right: 12,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => Share.share(widget.video.url),
                  child: const _ActionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                  ),
                ),
                const SizedBox(height: 20),
                // Download button — reacts to DownloadBloc state
                BlocBuilder<DownloadBloc, DownloadState>(
                  builder: (context, dlState) {
                    final videoId = widget.video.id;

                    if (dlState.isDownloaded(videoId)) {
                      return GestureDetector(
                        onLongPress: () {
                          context
                              .read<DownloadBloc>()
                              .add(DeleteDownload(videoId));
                        },
                        child: const _ActionButton(
                          icon: Icons.download_done,
                          label: 'Saved',
                        ),
                      );
                    }

                    if (dlState.isDownloading(videoId)) {
                      final prog = dlState.progress(videoId);
                      return Column(
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              value: prog,
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(prog * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              shadows: [
                                Shadow(blurRadius: 4, color: Colors.black54),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return GestureDetector(
                      onTap: () => context
                          .read<DownloadBloc>()
                          .add(StartDownload(widget.video)),
                      child: const _ActionButton(
                        icon: Icons.download_outlined,
                        label: 'Save',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 32,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
        ),
      ],
    );
  }
}
