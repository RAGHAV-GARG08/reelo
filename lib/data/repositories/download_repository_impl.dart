import '../../domain/entities/download_entity.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/repositories/download_repository.dart';
import '../sources/download_local_data_source.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  final DownloadLocalDataSource dataSource;

  DownloadRepositoryImpl(this.dataSource);

  @override
  Future<List<DownloadEntity>> getDownloads() => dataSource.getDownloads();

  @override
  Stream<DownloadEntity> startDownload(VideoEntity video) =>
      dataSource.startDownload(video);

  @override
  Future<void> deleteDownload(String videoId) =>
      dataSource.deleteDownload(videoId);

  @override
  Future<bool> isDownloaded(String videoId) =>
      dataSource.isDownloaded(videoId);
}
