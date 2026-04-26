import 'package:equatable/equatable.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/video_entity.dart';

abstract class ReelsState extends Equatable {
  const ReelsState();

  @override
  List<Object?> get props => [];
}

/// App just launched — no data, no request made yet.
class ReelsInitial extends ReelsState {
  const ReelsInitial();
}

/// First-page fetch in progress (show full-screen loader).
class ReelsLoading extends ReelsState {
  const ReelsLoading();
}

/// Videos available. Also used for pagination updates and play/pause changes.
class ReelsLoaded extends ReelsState {
  final List<VideoEntity> videos;

  /// Maps video index → its initialized VideoPlayerController.
  /// Only indices within the preload window exist in this map.
  final Map<int, VideoPlayerController> controllers;

  final int currentIndex;
  final bool hasMore;

  /// True while a background pagination request is running.
  final bool isLoadingMore;

  const ReelsLoaded({
    required this.videos,
    required this.controllers,
    required this.currentIndex,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  ReelsLoaded copyWith({
    List<VideoEntity>? videos,
    Map<int, VideoPlayerController>? controllers,
    int? currentIndex,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ReelsLoaded(
      videos: videos ?? this.videos,
      controllers: controllers ?? this.controllers,
      currentIndex: currentIndex ?? this.currentIndex,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
        videos,
        controllers,
        currentIndex,
        hasMore,
        isLoadingMore,
      ];
}

/// A fatal error that prevents displaying any feed.
class ReelsError extends ReelsState {
  final String message;

  const ReelsError(this.message);

  @override
  List<Object?> get props => [message];
}
