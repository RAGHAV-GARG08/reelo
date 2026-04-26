import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/usecase/usecase.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/usecases/delete_download_usecase.dart';
import '../../domain/usecases/get_downloads_usecase.dart';
import '../../domain/usecases/start_download_usecase.dart';
import 'download_event.dart';
import 'download_state.dart';

/// Internal event: routes stream progress updates back through the BLoC.
/// Defined here (not in download_event.dart) so it stays private to this file.
class _ProgressUpdated extends DownloadEvent {
  final DownloadEntity entity;
  const _ProgressUpdated(this.entity);
  @override
  List<Object?> get props => [entity];
}

class DownloadBloc extends Bloc<DownloadEvent, DownloadState> {
  final StartDownloadUseCase startDownloadUseCase;
  final GetDownloadsUseCase getDownloadsUseCase;
  final DeleteDownloadUseCase deleteDownloadUseCase;

  DownloadBloc({
    required this.startDownloadUseCase,
    required this.getDownloadsUseCase,
    required this.deleteDownloadUseCase,
  }) : super(const DownloadState()) {
    on<LoadDownloads>(_onLoad);
    on<StartDownload>(_onStart);
    on<DeleteDownload>(_onDelete);
    on<_ProgressUpdated>(_onProgress);
  }

  Future<void> _onLoad(
    LoadDownloads event,
    Emitter<DownloadState> emit,
  ) async {
    final result = await getDownloadsUseCase(NoParams());
    result.fold(
      (_) {},
      (list) => emit(state.copyWith(
        downloads: {for (final d in list) d.videoId: d},
      )),
    );
  }

  Future<void> _onStart(
    StartDownload event,
    Emitter<DownloadState> emit,
  ) async {
    // Ignore if already downloaded or currently downloading.
    final existing = state.downloads[event.video.id];
    if (existing != null &&
        (existing.status == DownloadStatus.completed ||
            existing.status == DownloadStatus.downloading)) {
      return;
    }

    // Subscribe in background — progress is routed through _ProgressUpdated
    // so multiple concurrent downloads don't block each other.
    startDownloadUseCase(event.video).listen(
      (entity) => add(_ProgressUpdated(entity)),
    );
  }

  Future<void> _onProgress(
    _ProgressUpdated event,
    Emitter<DownloadState> emit,
  ) async {
    emit(state.copyWith(
      downloads: {...state.downloads, event.entity.videoId: event.entity},
    ));
  }

  Future<void> _onDelete(
    DeleteDownload event,
    Emitter<DownloadState> emit,
  ) async {
    await deleteDownloadUseCase(event.videoId);
    final updated = Map<String, DownloadEntity>.from(state.downloads)
      ..remove(event.videoId);
    emit(state.copyWith(downloads: updated));
  }
}

// Make _ProgressUpdated usable as a type argument by ensuring it's exported
// from this library file — it's referenced only within this file.
// Dart private identifiers starting with _ are library-private, not file-private,
// so registering on<_ProgressUpdated> works because DownloadBloc is in the same library.
