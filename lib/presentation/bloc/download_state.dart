import 'package:equatable/equatable.dart';
import '../../domain/entities/download_entity.dart';

class DownloadState extends Equatable {
  /// Map of videoId → DownloadEntity for all known downloads.
  final Map<String, DownloadEntity> downloads;

  const DownloadState({this.downloads = const {}});

  DownloadState copyWith({Map<String, DownloadEntity>? downloads}) =>
      DownloadState(downloads: downloads ?? this.downloads);

  bool isDownloaded(String videoId) =>
      downloads[videoId]?.status == DownloadStatus.completed;

  bool isDownloading(String videoId) =>
      downloads[videoId]?.status == DownloadStatus.downloading;

  double progress(String videoId) => downloads[videoId]?.progress ?? 0.0;

  @override
  List<Object> get props => [downloads];
}
