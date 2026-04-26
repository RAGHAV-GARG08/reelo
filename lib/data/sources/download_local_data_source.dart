import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/entities/video_entity.dart';

class DownloadLocalDataSource {
  final Dio _dio;

  DownloadLocalDataSource(this._dio);

  Future<Directory> get _downloadsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/reels_downloads');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<File> get _manifestFile async {
    final dir = await _downloadsDir;
    return File('${dir.path}/manifest.json');
  }

  Future<Map<String, dynamic>> _readManifest() async {
    try {
      final file = await _manifestFile;
      if (!file.existsSync()) return {};
      final content = file.readAsStringSync();
      if (content.isEmpty) return {};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeManifest(Map<String, dynamic> data) async {
    final file = await _manifestFile;
    file.writeAsStringSync(jsonEncode(data));
  }

  Future<List<DownloadEntity>> getDownloads() async {
    final manifest = await _readManifest();
    return manifest.values
        .map((e) => DownloadEntity.fromJson(e as Map<String, dynamic>))
        .where((d) => d.status == DownloadStatus.completed)
        .toList()
      ..sort((a, b) => (b.downloadedAt ?? DateTime(0))
          .compareTo(a.downloadedAt ?? DateTime(0)));
  }

  Stream<DownloadEntity> startDownload(VideoEntity video) {
    final ctrl = StreamController<DownloadEntity>();
    _performDownload(video, ctrl);
    return ctrl.stream;
  }

  Future<void> _performDownload(
    VideoEntity video,
    StreamController<DownloadEntity> ctrl,
  ) async {
    final dir = await _downloadsDir;
    final path = '${dir.path}/${video.url.hashCode}.mp4';

    var entity = DownloadEntity(
      id: video.id,
      videoId: video.id,
      videoUrl: video.url,
      username: video.username,
      caption: video.caption,
      status: DownloadStatus.downloading,
      progress: 0.0,
    );

    if (!ctrl.isClosed) ctrl.add(entity);

    try {
      await _dio.download(
        video.url,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0 && !ctrl.isClosed) {
            entity = entity.copyWith(progress: received / total);
            ctrl.add(entity);
          }
        },
      );

      entity = entity.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        localPath: path,
        downloadedAt: DateTime.now(),
      );

      final manifest = await _readManifest();
      manifest[video.id] = entity.toJson();
      await _writeManifest(manifest);

      if (!ctrl.isClosed) ctrl.add(entity);
    } catch (e) {
      final partial = File(path);
      if (partial.existsSync()) partial.deleteSync();

      entity = entity.copyWith(
        status: DownloadStatus.failed,
        progress: 0.0,
      );
      if (!ctrl.isClosed) ctrl.add(entity);
    } finally {
      ctrl.close();
    }
  }

  Future<void> deleteDownload(String videoId) async {
    final manifest = await _readManifest();
    final data = manifest[videoId];
    if (data != null) {
      final entity =
          DownloadEntity.fromJson(data as Map<String, dynamic>);
      if (entity.localPath != null) {
        final file = File(entity.localPath!);
        if (file.existsSync()) file.deleteSync();
      }
      manifest.remove(videoId);
      await _writeManifest(manifest);
    }
  }

  Future<bool> isDownloaded(String videoId) async {
    final manifest = await _readManifest();
    final data = manifest[videoId];
    if (data == null) return false;
    final entity = DownloadEntity.fromJson(data as Map<String, dynamic>);
    return entity.status == DownloadStatus.completed &&
        entity.localPath != null &&
        File(entity.localPath!).existsSync();
  }

  /// Returns the local file path for a downloaded video (by URL),
  /// so FilesystemVideoCacheService can look up by URL hash.
  Future<String?> getLocalPathByUrl(String url) async {
    final dir = await _downloadsDir;
    final file = File('${dir.path}/${url.hashCode}.mp4');
    return file.existsSync() ? file.path : null;
  }
}
