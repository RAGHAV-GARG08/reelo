import '../entities/download_entity.dart';
import '../entities/video_entity.dart';

abstract class DownloadRepository {
  Future<List<DownloadEntity>> getDownloads();
  Stream<DownloadEntity> startDownload(VideoEntity video);
  Future<void> deleteDownload(String videoId);
  Future<bool> isDownloaded(String videoId);
}
