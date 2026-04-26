import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Contract for video caching operations.
abstract class VideoCacheService {
  Future<bool> isCached(String url);
  Future<String?> getCachedPath(String url);
  Future<void> cacheVideo(String url, {void Function(double progress)? onProgress});
  Future<void> clearCache();
  Future<void> evict(String url);
}

/// In-memory stub — always returns null. Replaced by FilesystemVideoCacheService
/// in production. getCachedPath must return null here; returning a fake path
/// would cause VideoPlayerController.initialize() to throw file-not-found.
class InMemoryVideoCacheService implements VideoCacheService {
  @override
  Future<bool> isCached(String url) async => false;

  @override
  Future<String?> getCachedPath(String url) async => null;

  @override
  Future<void> cacheVideo(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    for (double p = 0.0; p <= 1.0; p += 0.25) {
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress?.call(p);
    }
  }

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> evict(String url) async {}
}

/// Production implementation using dio + path_provider.
///
/// Storage layout:
///   {appDocDir}/reels_downloads/{urlHash}.mp4  ← user-initiated downloads (persistent)
///   {tempDir}/reels_cache/{urlHash}.mp4         ← auto-preload cache (may be evicted)
///
/// getCachedPath checks the downloads directory first so that a downloaded
/// video is always served from disk — no network request, no range negotiation.
class FilesystemVideoCacheService implements VideoCacheService {
  final Dio _dio;

  FilesystemVideoCacheService(this._dio);

  Future<Directory> get _downloadsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/reels_downloads');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> get _cacheDir async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/reels_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  String _filename(String url) => '${url.hashCode}.mp4';

  @override
  Future<String?> getCachedPath(String url) async {
    // Check persistent downloads directory first.
    final downloadsDir = await _downloadsDir;
    final downloadFile = File('${downloadsDir.path}/${_filename(url)}');
    if (downloadFile.existsSync()) return downloadFile.path;

    // Fall back to temp cache.
    final cacheDir = await _cacheDir;
    final cacheFile = File('${cacheDir.path}/${_filename(url)}');
    if (cacheFile.existsSync()) return cacheFile.path;

    return null;
  }

  @override
  Future<bool> isCached(String url) async =>
      (await getCachedPath(url)) != null;

  @override
  Future<void> cacheVideo(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    // Skip if already available (downloaded or cached).
    if (await isCached(url)) return;

    final dir = await _cacheDir;
    final path = '${dir.path}/${_filename(url)}';

    try {
      await _dio.download(
        url,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
      );
    } catch (_) {
      // Best-effort: don't propagate cache errors to callers.
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }
  }

  @override
  Future<void> clearCache() async {
    final dir = await _cacheDir;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  @override
  Future<void> evict(String url) async {
    final dir = await _cacheDir;
    final file = File('${dir.path}/${_filename(url)}');
    if (file.existsSync()) file.deleteSync();
  }
}
