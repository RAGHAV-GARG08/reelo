import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection_container.dart';
import '../bloc/reels_bloc.dart';
import '../bloc/reels_event.dart';
import '../bloc/reels_state.dart';
import '../widgets/video_player_item.dart';

class ReelsScreen extends StatelessWidget {
  final bool isActive;

  const ReelsScreen({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ReelsBloc>(
      create: (_) => sl<ReelsBloc>()..add(const FetchVideos(isInitialFetch: true)),
      child: _ReelsView(isActive: isActive),
    );
  }
}

class _ReelsView extends StatefulWidget {
  final bool isActive;
  const _ReelsView({required this.isActive});

  @override
  State<_ReelsView> createState() => _ReelsViewState();
}

class _ReelsViewState extends State<_ReelsView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(_ReelsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pause when the tab is hidden; resume when it becomes active again.
    if (oldWidget.isActive != widget.isActive) {
      context.read<ReelsBloc>().add(
            ReelsTabVisibility(isVisible: widget.isActive),
          );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReelsBloc, ReelsState>(
      builder: (context, state) {
        if (state is ReelsLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (state is ReelsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  state.message,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<ReelsBloc>().add(
                        const FetchVideos(isInitialFetch: true),
                      ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is ReelsLoaded) {
          if (state.videos.isEmpty) {
            return const Center(
              child: Text(
                'No reels available.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const ClampingScrollPhysics(),
                itemCount: state.videos.length,
                onPageChanged: (index) {
                  context.read<ReelsBloc>().add(OnVideoVisibleChanged(index));
                },
                itemBuilder: (context, index) {
                  final video = state.videos[index];
                  final controller = state.controllers[index];

                  return VideoPlayerItem(
                    key: ValueKey(video.id),
                    video: video,
                    controller: controller,
                    isActive: index == state.currentIndex,
                  );
                },
              ),
              if (state.isLoadingMore)
                const Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
