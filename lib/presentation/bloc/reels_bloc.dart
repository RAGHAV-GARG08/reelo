import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/usecases/get_reels_videos_usecase.dart';
import '../../services/video_cache_service.dart';
import 'reels_event.dart';
import 'reels_state.dart';

/// Orchestrates video fetching, controller lifecycle, preloading, and eviction.
class ReelsBloc extends Bloc<ReelsEvent, ReelsState> {
  final GetReelsVideosUseCase getReelsVideosUseCase;
  final VideoCacheService cacheService;

  /// Number of controllers to preload AHEAD of the current video.
  static const int _preloadWindow = 3;

  /// Number of controllers to KEEP BEHIND the current video before evicting.
  static const int _backBufferWindow = 2;

  String? _lastDocumentId;

  ReelsBloc({
    required this.getReelsVideosUseCase,
    required this.cacheService,
  }) : super(const ReelsInitial()) {
    on<FetchVideos>(_onFetchVideos);
    on<OnVideoVisibleChanged>(_onVideoVisibleChanged);
  }

  // ---------------------------------------------------------------------------
  // Event Handlers
  // ---------------------------------------------------------------------------

  Future<void> _onFetchVideos(
    FetchVideos event,
    Emitter<ReelsState> emit,
  ) async {
    if (event.isInitialFetch) {
      emit(const ReelsLoading());
      _lastDocumentId = null;

      final result = await getReelsVideosUseCase(
        const GetReelsParams(lastDocumentId: null),
      );

      await result.fold(
        (failure) async => emit(ReelsError(failure.message)),
        (videos) async {
          if (videos.isEmpty) {
            emit(const ReelsLoaded(
              videos: [],
              controllers: {},
              currentIndex: 0,
              hasMore: false,
            ));
            return;
          }

          _lastDocumentId = videos.last.id;

          final controllers = <int, VideoPlayerController>{};

          // Initialize all controllers in the preload window BEFORE emitting.
          // This eliminates the _schedulePreload microtask race where a fast
          // scroll would copy the state before the background task finished,
          // orphaning the preloaded controllers and producing an infinite spinner.
          for (int i = 0; i <= _preloadWindow && i < videos.length; i++) {
            await _initController(controllers, videos, i);
          }

          emit(ReelsLoaded(
            videos: videos,
            controllers: controllers,
            currentIndex: 0,
            hasMore: true,
          ));

          // Auto-play index 0 after the state is emitted.
          controllers[0]?.seekTo(Duration.zero);
          controllers[0]?.play();
        },
      );
      return;
    }

    // Pagination
    final currentState = state;
    if (currentState is! ReelsLoaded) return;
    if (!currentState.hasMore || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    final result = await getReelsVideosUseCase(
      GetReelsParams(lastDocumentId: _lastDocumentId),
    );

    result.fold(
      (failure) => emit(currentState.copyWith(isLoadingMore: false)),
      (newVideos) {
        if (newVideos.isEmpty) {
          emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
          return;
        }

        _lastDocumentId = newVideos.last.id;
        final allVideos = [...currentState.videos, ...newVideos];

        emit(currentState.copyWith(
          videos: allVideos,
          hasMore: newVideos.length >= 10,
          isLoadingMore: false,
        ));
      },
    );
  }

  Future<void> _onVideoVisibleChanged(
    OnVideoVisibleChanged event,
    Emitter<ReelsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ReelsLoaded) return;

    final newIndex = event.visibleIndex;
    if (newIndex == currentState.currentIndex) return;

    final controllers = Map<int, VideoPlayerController>.from(
      currentState.controllers,
    );

    // 1. Pause previous — fire-and-forget, no await needed.
    controllers[currentState.currentIndex]?.pause();

    // 2. Always ensure the current video's controller is initialized.
    //    _preloadAhead only covers newIndex+1 … newIndex+N, never newIndex
    //    itself. Without this, any scroll to an evicted or skipped position
    //    produces a null controller → infinite spinner with no recovery path.
    await _initController(controllers, currentState.videos, newIndex);

    // 3. Play the now-visible controller.
    final newCtrl = controllers[newIndex];
    if (newCtrl != null && newCtrl.value.isInitialized) {
      await newCtrl.seekTo(Duration.zero);
      await newCtrl.play();
    }

    // 4. Evict controllers too far behind.
    _evictBehind(controllers, newIndex);

    // 5. Trigger pagination if near the end.
    final distanceFromEnd = currentState.videos.length - 1 - newIndex;
    if (distanceFromEnd <= _preloadWindow && currentState.hasMore) {
      add(const FetchVideos());
    }

    // 6. Emit immediately — current video is guaranteed to be ready.
    emit(currentState.copyWith(
      controllers: controllers,
      currentIndex: newIndex,
    ));

    // 7. Preload ahead in background (non-blocking).
    //    Controllers are added to the just-emitted map (shared reference), so
    //    the next scroll event will find them already initialized and skip the
    //    network call. If a new scroll event fires before preloading finishes,
    //    step 2 above re-initializes the missing controller on demand.
    _preloadAheadBackground(currentState.videos, controllers, newIndex);
  }

  // ---------------------------------------------------------------------------
  // Preload & Eviction
  // ---------------------------------------------------------------------------

  Future<void> _initController(
    Map<int, VideoPlayerController> controllers,
    List<VideoEntity> videos,
    int index,
  ) async {
    if (index < 0 || index >= videos.length) return;
    if (controllers.containsKey(index)) return;

    final video = videos[index];
    final cachedPath = await cacheService.getCachedPath(video.url);

    VideoPlayerController controller;

    if (cachedPath != null) {
      controller = VideoPlayerController.contentUri(Uri.file(cachedPath));
      try {
        await controller.initialize();
      } catch (_) {
        // Cached file is missing or corrupt — fall back to network.
        await controller.dispose();
        controller = VideoPlayerController.networkUrl(
          Uri.parse(video.url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
        await controller.initialize();
        cacheService.cacheVideo(video.url).ignore();
      }
    } else {
      controller = VideoPlayerController.networkUrl(
        Uri.parse(video.url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await controller.initialize();
      cacheService.cacheVideo(video.url).ignore();
    }

    controller.setLooping(true);
    controllers[index] = controller;
  }

  /// Initializes the next [_preloadWindow] controllers in the background.
  /// Runs as a microtask so it never blocks the scroll event handler.
  /// Controllers are added directly to [controllers] (the map already stored
  /// in the emitted state), so the next scroll event finds them pre-initialized
  /// without requiring another emit.
  void _preloadAheadBackground(
    List<VideoEntity> videos,
    Map<int, VideoPlayerController> controllers,
    int currentIndex,
  ) {
    Future.microtask(() async {
      for (int i = currentIndex + 1;
          i <= currentIndex + _preloadWindow && i < videos.length;
          i++) {
        await _initController(controllers, videos, i);
      }
    });
  }

  void _evictBehind(
    Map<int, VideoPlayerController> controllers,
    int currentIndex,
  ) {
    final evictBefore = currentIndex - _backBufferWindow - 1;
    final toEvict = controllers.keys.where((k) => k < evictBefore).toList();
    for (final key in toEvict) {
      controllers[key]?.dispose();
      controllers.remove(key);
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  Future<void> close() async {
    if (state is ReelsLoaded) {
      final loadedState = state as ReelsLoaded;
      for (final controller in loadedState.controllers.values) {
        await controller.dispose();
      }
    }
    return super.close();
  }
}
