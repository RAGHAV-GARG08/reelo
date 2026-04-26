import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../data/repositories/video_repository_impl.dart';
import '../../data/sources/download_local_data_source.dart';
import '../../data/sources/video_remote_data_source.dart';
import '../../domain/repositories/download_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../../domain/usecases/delete_download_usecase.dart';
import '../../domain/usecases/get_downloads_usecase.dart';
import '../../domain/usecases/get_reels_videos_usecase.dart';
import '../../domain/usecases/start_download_usecase.dart';
import '../../presentation/bloc/download_bloc.dart';
import '../../presentation/bloc/reels_bloc.dart';
import '../../services/video_cache_service.dart';

/// Global service locator instance.
final GetIt sl = GetIt.instance;

/// Register all dependencies. Called once in main() before runApp.
///
/// To activate production Firebase:
///   1. Add firebase_core + cloud_firestore imports
///   2. Replace StubVideoRemoteDataSource with FirestoreVideoDataSource(FirebaseFirestore.instance)
Future<void> initDependencies() async {
  // Core
  sl.registerLazySingleton<Dio>(() => Dio());

  // Services — FilesystemVideoCacheService uses the downloads dir first,
  // then a temp cache dir, so downloaded videos are always played locally.
  sl.registerLazySingleton<VideoCacheService>(
    () => FilesystemVideoCacheService(sl<Dio>()),
  );

  // Data Sources
  sl.registerLazySingleton<VideoRemoteDataSource>(
    () => StubVideoRemoteDataSource(),
  );
  sl.registerLazySingleton<DownloadLocalDataSource>(
    () => DownloadLocalDataSource(sl<Dio>()),
  );

  // Repositories
  sl.registerLazySingleton<VideoRepository>(
    () => VideoRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<DownloadRepository>(
    () => DownloadRepositoryImpl(sl<DownloadLocalDataSource>()),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetReelsVideosUseCase(sl()));
  sl.registerLazySingleton(() => StartDownloadUseCase(sl()));
  sl.registerLazySingleton(() => GetDownloadsUseCase(sl()));
  sl.registerLazySingleton(() => DeleteDownloadUseCase(sl()));

  // BLoC — factory ensures a fresh ReelsBloc per screen mount;
  // DownloadBloc is a singleton (shared across Reels + Downloads tabs).
  sl.registerFactory(
    () => ReelsBloc(
      getReelsVideosUseCase: sl(),
      cacheService: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => DownloadBloc(
      startDownloadUseCase: sl(),
      getDownloadsUseCase: sl(),
      deleteDownloadUseCase: sl(),
    ),
  );
}
