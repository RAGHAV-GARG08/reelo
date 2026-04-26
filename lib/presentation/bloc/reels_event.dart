import 'package:equatable/equatable.dart';

abstract class ReelsEvent extends Equatable {
  const ReelsEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on screen init or when user reaches pagination threshold.
/// [isInitialFetch] true = first load, false = load more (pagination).
class FetchVideos extends ReelsEvent {
  final bool isInitialFetch;

  const FetchVideos({this.isInitialFetch = false});

  @override
  List<Object?> get props => [isInitialFetch];
}

/// Dispatched by PageView whenever the visible video index changes.
/// The BLoC uses [visibleIndex] to pause/play controllers and trigger preloading.
class OnVideoVisibleChanged extends ReelsEvent {
  final int visibleIndex;

  const OnVideoVisibleChanged(this.visibleIndex);

  @override
  List<Object?> get props => [visibleIndex];
}
