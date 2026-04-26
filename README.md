# Reelo — Flutter Reels App

A production-structured Flutter application that replicates the Instagram/TikTok Reels experience. Built with **Clean Architecture**, **BLoC state management**, and a purpose-built **sliding-window preload + cache system** to ensure smooth, jank-free vertical video scrolling.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Tech Stack & Dependencies](#2-tech-stack--dependencies)
3. [Architecture](#3-architecture)
4. [Folder Structure](#4-folder-structure)
5. [Layer-by-Layer Walkthrough](#5-layer-by-layer-walkthrough)
   - [Domain Layer](#51-domain-layer)
   - [Data Layer](#52-data-layer-stub)
   - [Service Layer](#53-service-layer)
   - [BLoC Layer](#54-bloc-layer)
   - [Presentation Layer](#55-presentation-layer)
6. [Video Preloading — Deep Dive](#6-video-preloading--deep-dive)
   - [The Sliding Window Model](#61-the-sliding-window-model)
   - [Initial Load Sequence](#62-initial-load-sequence)
   - [On Scroll — Step by Step](#63-on-scroll--step-by-step)
   - [Pagination Trigger](#64-pagination-trigger)
   - [Controller Eviction](#65-controller-eviction)
7. [Video Caching — Deep Dive](#7-video-caching--deep-dive)
   - [Cache Interface Design](#71-cache-interface-design)
   - [How Caching Integrates with Preloading](#72-how-caching-integrates-with-preloading)
   - [Current Implementation (In-Memory Stub)](#73-current-implementation-in-memory-stub)
   - [Production Implementation Path](#74-production-implementation-path)
8. [BLoC Events & States](#8-bloc-events--states)
9. [UI Architecture](#9-ui-architecture)
10. [Data Flow Diagram](#10-data-flow-diagram)
11. [Download Feature — Design Plan](#11-download-feature--design-plan)
12. [Firebase Integration Guide](#12-firebase-integration-guide)
13. [Running the App](#13-running-the-app)

---

## 1. Project Overview

Reelo demonstrates how to build a high-performance, fullscreen vertical video feed — the core of any short-video platform. Key capabilities:

| Feature | Detail |
|---|---|
| Vertical feed | `PageView.builder` with `ClampingScrollPhysics` — one video snaps per swipe |
| Auto-play/pause | BLoC drives `VideoPlayerController.play()` / `.pause()` on index change |
| Preloading | Next **3** video controllers initialized ahead of current position |
| Back buffer | Previous **2** controllers kept alive for instant backward swipe |
| Eviction | Controllers beyond back buffer are disposed to free native decoder memory |
| Caching | Interface-first design; in-memory stub today, filesystem-backed tomorrow |
| Pagination | Background fetch triggers when within 3 videos of the last loaded item |
| Navigation | 3-tab `BottomNavigationBar` backed by `IndexedStack` (BLoC state preserved) |

---

## 2. Tech Stack & Dependencies

```yaml
# State management
flutter_bloc: ^9.1.1   # BlocProvider, BlocBuilder, context.read
bloc: ^9.0.0           # Bloc base class, Emitter
equatable: ^2.0.8      # Value equality for entities and states

# Video
video_player: ^2.10.1  # Native platform video decoder (ExoPlayer / AVPlayer)

# Dependency injection
get_it: ^9.2.1         # Service locator, no code generation

# Functional error handling
dartz: ^0.10.1         # Either<Failure, T> — explicit error propagation

# Visibility
visibility_detector: ^0.4.0+2  # Fraction-based widget visibility callbacks

# Firebase (commented out — enable when ready)
# firebase_core: ^4.7.0
# cloud_firestore: ^6.3.0

# Testing
bloc_test: ^10.0.0
mocktail: ^1.0.4
```

**Why `dartz`?** Every use case returns `Either<Failure, T>` instead of throwing. This forces the BLoC to handle both paths at compile time — no silent swallowed exceptions.

**Why `get_it` over `injectable`?** No build runner needed. Swapping stub implementations for production ones is a single line change in `injection_container.dart`.

**Why `IndexedStack` over Navigator tabs?** Navigator would dispose the Reels subtree on every tab switch, destroying all `VideoPlayerController` instances and losing scroll position. `IndexedStack` keeps all three screens alive simultaneously.

---

## 3. Architecture

```
┌─────────────────────────────────────────────────┐
│                Presentation Layer               │
│  Screens · Widgets · BLoC (events/states/bloc)  │
│         Depends on → Domain only                │
└───────────────────┬─────────────────────────────┘
                    │ UseCase calls
┌───────────────────▼─────────────────────────────┐
│                 Domain Layer                    │
│     Entities · Repository contracts · UseCases  │
│         Pure Dart — zero Flutter imports        │
└───────────────────┬─────────────────────────────┘
                    │ Implements
┌───────────────────▼─────────────────────────────┐
│                  Data Layer                     │
│   Models · DataSources · RepositoryImpl (stub)  │
│   Swap StubDataSource → FirestoreDataSource     │
└─────────────────────────────────────────────────┘
```

The **Domain layer owns all contracts**. The Data layer implements them. The Presentation layer only ever touches Domain entities and use cases — never data models or Firebase types.

---

## 4. Folder Structure

```
lib/
│
├── main.dart                          # Entry point: DI init → runApp
│
├── app/
│   └── main_app.dart                  # MaterialApp (dark) + MainNavigation (IndexedStack)
│
├── core/
│   ├── error/
│   │   └── failures.dart              # Failure · ServerFailure · NetworkFailure · CacheFailure
│   ├── usecase/
│   │   └── usecase.dart               # abstract UseCase<T, P> + NoParams
│   └── di/
│       └── injection_container.dart   # get_it registrations — single swap point for prod
│
├── domain/
│   ├── entities/
│   │   └── video_entity.dart          # VideoEntity (id, url, username, caption, likes)
│   ├── repositories/
│   │   └── video_repository.dart      # abstract VideoRepository — owned by domain
│   └── usecases/
│       └── get_reels_videos_usecase.dart  # GetReelsVideosUseCase + GetReelsParams
│
├── data/
│   ├── models/
│   │   └── video_model.dart           # VideoModel extends VideoEntity + fromJson/toJson
│   ├── sources/
│   │   └── video_remote_data_source.dart  # abstract + StubVideoRemoteDataSource
│   └── repositories/
│       └── video_repository_impl.dart # VideoRepositoryImpl — wraps source in Either
│
├── services/
│   └── video_cache_service.dart       # abstract VideoCacheService + InMemoryVideoCacheService
│
└── presentation/
    ├── bloc/
    │   ├── reels_event.dart           # FetchVideos · OnVideoVisibleChanged
    │   ├── reels_state.dart           # ReelsInitial · Loading · Loaded · Error
    │   └── reels_bloc.dart            # All orchestration: preload, evict, paginate
    │
    ├── screens/
    │   ├── home_screen.dart           # Placeholder
    │   ├── reels_screen.dart          # BlocProvider + PageView + pagination loader
    │   └── downloads_screen.dart      # Placeholder (Coming Soon)
    │
    └── widgets/
        └── video_player_item.dart     # Fullscreen video + overlay (username/caption/likes)
```

---

## 5. Layer-by-Layer Walkthrough

### 5.1 Domain Layer

**`VideoEntity`** — pure Dart, extends `Equatable` for value equality used by BLoC state comparisons:

```dart
class VideoEntity extends Equatable {
  final String id;
  final String url;
  final String username;
  final String caption;
  final int likes;
}
```

**`VideoRepository`** — the contract the data layer must satisfy. Domain owns this; data implements it:

```dart
abstract class VideoRepository {
  Future<Either<Failure, List<VideoEntity>>> getVideos({
    String? lastDocumentId,
    int limit = 10,
  });
}
```

**`GetReelsVideosUseCase`** — the only door between Presentation and Domain:

```dart
class GetReelsVideosUseCase extends UseCase<List<VideoEntity>, GetReelsParams> {
  Future<Either<Failure, List<VideoEntity>>> call(GetReelsParams params) =>
      repository.getVideos(lastDocumentId: params.lastDocumentId, limit: params.limit);
}
```

### 5.2 Data Layer (Stub)

**`VideoModel`** extends `VideoEntity` (Liskov Substitution Principle). The repository can return `VideoModel` instances directly as `VideoEntity` — no mapper needed:

```dart
class VideoModel extends VideoEntity {
  factory VideoModel.fromJson(String docId, Map<String, dynamic> json) { ... }
  Map<String, dynamic> toJson() { ... }
}
```

**`StubVideoRemoteDataSource`** returns 20 hardcoded `VideoModel` objects with a simulated 800ms delay. The `FirestoreVideoDataSource` production implementation is shown as commented-out code in the same file — switching it on requires only a one-line change in `injection_container.dart`.

**`VideoRepositoryImpl`** wraps any data-source exception in `Left(ServerFailure(...))`:

```dart
try {
  final models = await remoteDataSource.getVideos(...);
  return Right(models);      // VideoModel IS-A VideoEntity
} catch (e) {
  return Left(ServerFailure(e.toString()));
}
```

### 5.3 Service Layer

**`VideoCacheService`** — interface-first design:

```dart
abstract class VideoCacheService {
  Future<bool>    isCached(String url);       // check before init
  Future<String?> getCachedPath(String url);  // get local path
  Future<void>    cacheVideo(String url, {    // download in background
    void Function(double progress)? onProgress,
  });
  Future<void>    clearCache();               // free all storage
  Future<void>    evict(String url);          // free one entry
}
```

### 5.4 BLoC Layer

Two events drive everything:

| Event | When dispatched | What it causes |
|---|---|---|
| `FetchVideos(isInitialFetch: true)` | Screen mount | Full reset, load page 1, init controller 0, schedule preload 1–3 |
| `FetchVideos(isInitialFetch: false)` | Near end of list | Append next page in background |
| `OnVideoVisibleChanged(index)` | `PageView.onPageChanged` | Pause prev, play new, preload ahead, evict behind |

### 5.5 Presentation Layer

**`ReelsScreen`** creates the BLoC via `BlocProvider` (scoped, auto-disposed) and immediately fires `FetchVideos(isInitialFetch: true)`.

**`PageView.builder`** handles the scroll. Its `onPageChanged` callback is the only scroll listener — it fires once per settled page, not on every pixel, making it the ideal hook for visibility events.

**`VideoPlayerItem`** accepts a nullable `VideoPlayerController?`. When null (controller not yet initialized), it shows a spinner. This decouples the widget from controller lifecycle — the BLoC is the sole owner.

---

## 6. Video Preloading — Deep Dive

This is the core performance feature of the app. The goal is that when the user swipes to the next video, that video's native decoder has already been initialized and is buffering — so playback starts instantly with no spinner.

### 6.1 The Sliding Window Model

The BLoC maintains a sliding window of initialized `VideoPlayerController` instances. Two constants control its size:

```dart
static const int _preloadWindow    = 3;  // controllers AHEAD of current
static const int _backBufferWindow = 2;  // controllers BEHIND before eviction
```

At any given time the active window looks like this (user is at index 4):

```
Index:  [0]      [1]      [2]      [3]      [4]      [5]      [6]      [7]
State: EVICTED  EVICTED  KEEP     KEEP    [PLAY]   READY    READY    READY
                          ←back buffer→   ↑current  ←preload window→
```

- Total controllers alive at once: `_backBufferWindow + 1 + _preloadWindow = 6`
- This is intentional — each `VideoPlayerController` allocates a native decoder thread and a GPU texture ID. Keeping more than ~6 simultaneously on mid-range Android devices causes memory pressure.

### 6.2 Initial Load Sequence

When the screen mounts:

```
1. BlocProvider creates ReelsBloc
2. ReelsBloc immediately receives FetchVideos(isInitialFetch: true)
3. _onFetchVideos:
   a. emit(ReelsLoading)                        → shows spinner
   b. await GetReelsVideosUseCase(page 1)       → 800ms simulated delay
   c. await _initController(controllers, 0)     → index 0 initialized BEFORE emit
   d. emit(ReelsLoaded)                         → PageView renders with index 0 ready
   e. _schedulePreload(videos, controllers, 0)  → runs in Future.microtask (background)
4. _schedulePreload:
   a. Initializes controllers for indices 1, 2, 3 sequentially
   b. After all preloads done, plays controller[0] if not already playing
```

Step (c) is critical: controller 0 is initialized **synchronously before the state is emitted**. This means the first frame the user sees already has a playable video — no spinner on the Reels screen after the initial load.

Step (e) uses `Future.microtask` so the UI thread renders the first frame immediately, then preloading begins. Preloads 1–3 happen sequentially (each `initialize()` must complete before the next begins) to avoid overloading the network layer.

### 6.3 On Scroll — Step by Step

When the user swipes from index N to index N+1, `PageView.onPageChanged` fires and dispatches `OnVideoVisibleChanged(N+1)`. The BLoC handles it in order:

```
_onVideoVisibleChanged(newIndex = N+1):

Step 1 — PAUSE previous
  controllers[N].pause()
  (Releases audio focus and stops the decoder from consuming CPU)

Step 2 — PLAY new
  if controllers[N+1] exists and is initialized:
    controllers[N+1].seekTo(Duration.zero)
    controllers[N+1].play()
  else:
    Widget shows spinner until controller initializes asynchronously

Step 3 — PRELOAD AHEAD
  for i in [N+2, N+3, N+4]:
    _initController(controllers, videos, i)
    (skipped if already exists — idempotent)

Step 4 — EVICT BEHIND
  evictBefore = (N+1) - _backBufferWindow - 1 = N - 2
  for each key < evictBefore:
    controllers[key].dispose()   ← releases native decoder + GPU texture
    controllers.remove(key)

Step 5 — TRIGGER PAGINATION (if near end)
  distanceFromEnd = videos.length - 1 - (N+1)
  if distanceFromEnd <= 3 and hasMore:
    add(FetchVideos())           ← background page fetch, no UI disruption

Step 6 — EMIT updated state
  emit(ReelsLoaded.copyWith(controllers, currentIndex: N+1))
```

### 6.4 Pagination Trigger

The pagination trigger in Step 5 ensures the feed never runs dry. If the user is at index 17 in a 20-item list:

```
distanceFromEnd = 20 - 1 - 17 = 2  ← <= _preloadWindow (3)
→ FetchVideos() dispatched
→ next 10 videos appended to state.videos
→ preload window naturally extends into new items on next scroll
```

The user experiences this as an infinite feed — the list simply grows invisibly in the background.

### 6.5 Controller Eviction

`_evictBehind` is called on every scroll. It computes the eviction threshold:

```dart
final evictBefore = currentIndex - _backBufferWindow - 1;
// At index 5: evictBefore = 5 - 2 - 1 = 2
// Controllers at index 0 and 1 get disposed
```

`VideoPlayerController.dispose()` does three things:
1. Signals the platform plugin to release the native decoder (ExoPlayer/AVPlayer)
2. Releases the GPU texture ID
3. Cancels any pending HTTP range requests for that URL

Without eviction, scrolling through 50 videos would keep 50 native decoders alive simultaneously — guaranteed OOM crash on most devices.

---

## 7. Video Caching — Deep Dive

### 7.1 Cache Interface Design

The `VideoCacheService` interface is designed around the fundamental property of `VideoPlayerController`: it can play from either a **network URL** or a **local file URI**. Local file playback skips HTTP entirely — the platform decoder reads directly from the filesystem buffer.

```
Network URL path:
  HTTP range requests → decoder buffer → decoded frames → GPU
  (subject to network latency, rebuffering, rate limits)

Cached file path:
  File.read() → decoder buffer → decoded frames → GPU
  (reads at disk speed ~500MB/s on modern flash — no rebuffering)
```

The interface captures exactly this workflow:

```dart
abstract class VideoCacheService {
  Future<bool>    isCached(String url);       // check before init
  Future<String?> getCachedPath(String url);  // get local path if available
  Future<void>    cacheVideo(String url, {    // download to local file
    void Function(double progress)? onProgress,
  });
  Future<void>    clearCache();               // free all storage
  Future<void>    evict(String url);          // free one entry
}
```

### 7.2 How Caching Integrates with Preloading

Inside `_initController` — called for every video being preloaded — the cache is checked first:

```dart
Future<void> _initController(
  Map<int, VideoPlayerController> controllers,
  List<VideoEntity> videos,
  int index,
) async {
  if (controllers.containsKey(index)) return;   // idempotent guard

  final video = videos[index];

  // ① Check cache
  final cachedPath = await cacheService.getCachedPath(video.url);

  final VideoPlayerController controller;

  if (cachedPath != null) {
    // ② Cache HIT — play from local file (fast path)
    controller = VideoPlayerController.contentUri(Uri.file(cachedPath));

  } else {
    // ③ Cache MISS — play from network
    controller = VideoPlayerController.networkUrl(
      Uri.parse(video.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    // ④ Fire-and-forget background download
    //    Does NOT block controller initialization
    //    Next time this video is visited, it will hit the cache
    cacheService.cacheVideo(video.url).ignore();
  }

  await controller.initialize();
  controller.setLooping(true);
  controllers[index] = controller;
}
```

The key design decision at step ④: `cacheVideo` is called with `.ignore()` — it runs entirely in the background. The controller initialization does not wait for the download to complete. This means:

- **First visit**: plays from network while simultaneously downloading in parallel
- **Subsequent visits** (if evicted and re-initialized): plays from local cache — no network call

The cache and the preload window work together across time like this:

```
User at index 0:
  controllers initialized: {0: network, 1: network, 2: network, 3: network}
  cache downloads running:  {url_0, url_1, url_2, url_3} → writing to disk

User swipes to index 3:
  controllers[4] initialized → getCachedPath(url_4) = null → network + cacheVideo fires
  controllers[0] evicted     → controller[0].dispose()

User scrolls back to index 0 (after re-init):
  getCachedPath(url_0) → "/tmp/cache/xxxx.mp4"  (download completed while user scrolled)
  controller = VideoPlayerController.contentUri(Uri.file(path))
  → Plays instantly from disk, no buffering spinner
```

### 7.3 Current Implementation (In-Memory Stub)

`InMemoryVideoCacheService` simulates the full interface with a `Map<String, String>`:

```dart
class InMemoryVideoCacheService implements VideoCacheService {
  final Map<String, String> _cache = {};

  @override
  Future<String?> getCachedPath(String url) async => _cache[url];

  @override
  Future<void> cacheVideo(String url, {void Function(double)? onProgress}) async {
    // Simulates chunked download progress (0%, 25%, 50%, 75%, 100%)
    for (double p = 0.0; p <= 1.0; p += 0.25) {
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress?.call(p);
    }
    // Stores a fake path — real file doesn't exist in this stub
    _cache[url] = '/tmp/cache/${url.hashCode}.mp4';
  }
}
```

In this stub, the cache-hit path in `_initController` will never actually be reached in practice because the stored path points to a non-existent file. All controllers use the network URL path. This is the expected behavior for the stub — it validates the interface contract without requiring any file I/O.

### 7.4 Production Implementation Path

The `FilesystemVideoCacheService` is provided as commented-out code in `lib/services/video_cache_service.dart`. It requires two additional packages:

```yaml
dependencies:
  dio: ^5.8.0              # Chunked HTTP download with progress + CancelToken
  path_provider: ^2.1.0    # Resolves device-appropriate storage directory
```

Key properties of the production implementation:

| Property | Detail |
|---|---|
| Storage location | `getTemporaryDirectory()/reels_cache/` — persists across sessions, OS can reclaim under memory pressure |
| File naming | `${url.hashCode}.mp4` — deterministic, collision-resistant for distinct URLs |
| Memory index | `Map<String, String>` in-memory mirror of disk state for O(1) lookups without disk I/O |
| Download progress | `dio.download(onReceiveProgress)` streams `received / total` as a double |
| Eviction policy | LRU by access timestamp stored in `SharedPreferences`; trigger at 500 MB threshold |
| Cancellation | `CancelToken` per active download — cancelled on `evict()` if download is in-flight |

To activate it, replace one line in `injection_container.dart`:

```dart
// Before (stub):
sl.registerLazySingleton<VideoCacheService>(() => InMemoryVideoCacheService());

// After (production):
sl.registerLazySingleton<VideoCacheService>(
  () => FilesystemVideoCacheService(Dio()),
);
```

No other code needs to change — the BLoC calls `cacheService.getCachedPath()` and `cacheService.cacheVideo()` through the abstract interface, completely unaware of which implementation is active.

---

## 8. BLoC Events & States

### Events

```
ReelsEvent
├── FetchVideos
│   └── isInitialFetch: bool
│       true  → emit Loading, reset cursor, load page 1
│       false → emit isLoadingMore, append next page
│
└── OnVideoVisibleChanged
    └── visibleIndex: int
        → pause prev, play new, preload ahead, evict behind
```

### States

```
ReelsState
├── ReelsInitial      → black screen before first fetch resolves
├── ReelsLoading      → full-screen CircularProgressIndicator
├── ReelsLoaded
│   ├── videos: List<VideoEntity>             all pages loaded so far
│   ├── controllers: Map<int, VPC>            sliding window only (max 6)
│   ├── currentIndex: int                     currently visible/playing
│   ├── hasMore: bool                         false when server returns 0 items
│   └── isLoadingMore: bool                   shows subtle bottom spinner
└── ReelsError
    └── message: String                       retry button shown in UI
```

`ReelsLoaded.copyWith` is used on every scroll event — creates a new state referencing the updated controllers map without reallocating the full videos list.

---

## 9. UI Architecture

```
MainNavigation (IndexedStack — all 3 screens always alive)
├── index 0: HomeScreen          (placeholder)
├── index 1: ReelsScreen
│   └── BlocProvider<ReelsBloc>
│       └── _ReelsView (StatefulWidget holds PageController)
│           └── BlocBuilder<ReelsBloc, ReelsState>
│               ├── ReelsLoading → CircularProgressIndicator
│               ├── ReelsError   → Error icon + message + Retry button
│               └── ReelsLoaded → Stack
│                   ├── PageView.builder (vertical, ClampingScrollPhysics)
│                   │   └── VideoPlayerItem per index
│                   │       ├── FittedBox(cover) > VideoPlayer (fullscreen)
│                   │       ├── Tap overlay: play/pause icon (auto-hide 2s)
│                   │       ├── Bottom-left: username (bold) + caption (2-line)
│                   │       └── Right column: likes count · comment · share
│                   └── Positioned: isLoadingMore spinner (bottom center)
└── index 2: DownloadsScreen     (placeholder)
```

**`FittedBox(fit: BoxFit.cover)`** wrapping `VideoPlayer` achieves TikTok-style full-bleed scaling. The inner `SizedBox` is sized to the video's native aspect ratio; `FittedBox.cover` scales it to fill the entire viewport, clipping sides on non-matching aspect ratios.

**`ValueKey(video.id)`** on `VideoPlayerItem` ensures Flutter's reconciler recognizes each item as a distinct widget keyed to its data, preventing controller–widget mismatches during list mutations.

**`ClampingScrollPhysics`** on `PageView` prevents overscroll bounce on Android. The `PageView` snaps to exactly one item per gesture, matching TikTok/Instagram behavior.

---

## 10. Data Flow Diagram

```
┌─────────┐  FetchVideos(initial)   ┌───────────┐
│  Screen  │ ──────────────────────► │ ReelsBloc │
└─────────┘                         └─────┬─────┘
                                          │ GetReelsVideosUseCase(params)
                                    ┌─────▼──────────┐
                                    │ VideoRepository │  (domain contract)
                                    └─────┬──────────┘
                                          │ implements
                                    ┌─────▼──────────────┐
                                    │ VideoRepositoryImpl │
                                    └─────┬──────────────┘
                                          │ getVideos()
                                    ┌─────▼───────────────────────┐
                                    │ StubVideoRemoteDataSource    │
                                    │ (→ FirestoreDataSource prod) │
                                    └─────┬───────────────────────┘
                                          │ List<VideoModel>
                                          │ Right(models)
                                    ┌─────▼─────┐
                                    │ ReelsBloc │
                                    │           │ _initController(0)
                                    │           │──► getCachedPath() → null
                                    │           │──► networkUrl(url)
                                    │           │──► controller.initialize()
                                    │           │──► cacheVideo() [background]
                                    │           │
                                    │           │ emit(ReelsLoaded)
                                    │           │
                                    │           │ _schedulePreload(1,2,3)
                                    └─────┬─────┘    [Future.microtask]
                                          │ ReelsLoaded state
                                    ┌─────▼─────┐
                                    │  PageView  │ renders index 0, plays
                                    └─────┬─────┘
                                          │ onPageChanged(1)
                                    ┌─────▼─────┐
                            dispatch │ ReelsBloc │ OnVideoVisibleChanged(1)
                                    │           │──► pause [0]
                                    │           │──► play  [1]
                                    │           │──► init  [2][3][4]
                                    │           │──► evict [nothing yet]
                                    └───────────┘
```

---

## 11. Download Feature — Design Plan

> Not yet implemented. This section documents the planned architecture for the Downloads tab.

### New Domain

```dart
// lib/domain/entities/download_entity.dart
enum DownloadStatus { pending, downloading, done, failed }

class DownloadEntity extends Equatable {
  final String id;
  final String videoId;
  final String videoUrl;
  final String localPath;
  final DownloadStatus status;
  final double progress;  // 0.0 → 1.0
}

// lib/domain/repositories/download_repository.dart
abstract class DownloadRepository {
  Future<Either<Failure, void>>                saveDownload(DownloadEntity entity);
  Future<Either<Failure, List<DownloadEntity>>> getDownloads();
  Future<Either<Failure, void>>                deleteDownload(String id);
}

// lib/domain/usecases/download_video_usecase.dart
// Returns a Stream so the BLoC can emit incremental progress states
Stream<Either<Failure, double>> call(DownloadVideoParams params);
```

### New BLoC

```
DownloadEvent
├── StartDownload(VideoEntity video)
├── CancelDownload(String downloadId)
└── RemoveDownload(String downloadId)

DownloadState
├── DownloadIdle
├── DownloadInProgress(String downloadId, double progress)
├── DownloadComplete(DownloadEntity entity)
└── DownloadError(String message)
```

`DownloadBloc._onStartDownload` listens to the `Stream<Either<Failure, double>>` from the use case and emits `DownloadInProgress(progress)` on each event. A `CancelToken` (from `dio`) is stored as a BLoC field and cancelled on `CancelDownload`.

### Storage Strategy

| Concern | Solution |
|---|---|
| Metadata persistence | `hive` box — key-value, no schema migrations, fast reads |
| File storage | `getApplicationDocumentsDirectory()` — survives app restarts, not cleared by OS temp purge |
| File naming | `{videoId}_{timestamp}.mp4` — no collisions on re-download |
| Background download (Android) | `workmanager` package + WorkManager one-time task |
| Background download (iOS) | `background_fetch` + `BGProcessingTask` entitlement |
| Storage cap | 2 GB soft limit; LRU eviction by `createdAt` timestamp |

### Downloads Screen Update

```
DownloadsScreen
└── BlocProvider<DownloadBloc>
    └── BlocBuilder
        └── ListView
            └── DownloadTile (per DownloadEntity)
                ├── Title: username + caption (truncated)
                ├── DownloadInProgress → LinearProgressIndicator
                ├── DownloadComplete   → file size + checkmark
                ├── DownloadFailed     → error icon + retry tap
                └── Trailing: delete → RemoveDownload event
```

---

## 12. Firebase Integration Guide

The app runs entirely off stub data. To switch to live Firestore:

**Step 1** — Uncomment Firebase in `pubspec.yaml`:
```yaml
firebase_core: ^4.7.0
cloud_firestore: ^6.3.0
```

**Step 2** — Add platform config files:
- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

**Step 3** — Uncomment in `main.dart`:
```dart
import 'package:firebase_core/firebase_core.dart';
// ...
await Firebase.initializeApp();
```

**Step 4** — Swap the data source in `injection_container.dart`:
```dart
// Remove:
sl.registerLazySingleton<VideoRemoteDataSource>(
  () => StubVideoRemoteDataSource(),
);

// Add:
sl.registerLazySingleton<VideoRemoteDataSource>(
  () => FirestoreVideoDataSource(FirebaseFirestore.instance),
);
```

**Step 5** — Create the Firestore `reels` collection with this document shape:
```json
{
  "url":       "https://...",
  "username":  "@handle",
  "caption":   "Caption text",
  "likes":     1200,
  "createdAt": "<Timestamp>"
}
```

The `FirestoreVideoDataSource` implementation (with `startAfterDocument` cursor pagination) is already written as commented-out code in `lib/data/sources/video_remote_data_source.dart`.

---

## 13. Running the App

```bash
# Install dependencies
flutter pub get

# Check for issues
flutter analyze

# Run on connected device / emulator
flutter run

# Run in release mode (better video performance on device)
flutter run --release
```

**Android requirement:** `minSdkVersion 21` — ExoPlayer (used by `video_player`) requires API 21+. Confirm in `android/app/build.gradle`:
```gradle
defaultConfig {
    minSdkVersion 21
}
```

**Internet permission** — required for network video playback. Confirm in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

---

## Preloading & Caching — Quick Reference

```
App launch
  └─ FetchVideos(initial=true)
      ├─ init controller[0]          ← sync, blocks before emit
      ├─ emit ReelsLoaded            ← first frame shows index 0 immediately
      └─ microtask: init [1][2][3] + play [0]

User swipes index N → N+1
  └─ OnVideoVisibleChanged(N+1)
      ├─ pause  [N]
      ├─ play   [N+1]
      ├─ init   [N+2][N+3][N+4]     ← extend preload window forward
      ├─ evict  [< N-2]             ← release native decoders behind buffer
      └─ if near end → FetchVideos() (pagination, no UI freeze)

_initController(index)
  ├─ getCachedPath(url)
  │   ├─ HIT  → contentUri(localFile)   [plays from disk, instant]
  │   └─ MISS → networkUrl(url)         [streams from network]
  │             + cacheVideo(url)       [background download, fire-and-forget]
  └─ controller.initialize() + setLooping(true)
```
