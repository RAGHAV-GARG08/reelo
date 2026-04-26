import '../entities/download_entity.dart';
import '../entities/video_entity.dart';
import '../repositories/download_repository.dart';

class StartDownloadUseCase {
  final DownloadRepository repository;
  StartDownloadUseCase(this.repository);

  Stream<DownloadEntity> call(VideoEntity video) =>
      repository.startDownload(video);
}
