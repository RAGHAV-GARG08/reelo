import 'package:equatable/equatable.dart';

enum DownloadStatus { pending, downloading, completed, failed }

class DownloadEntity extends Equatable {
  final String id;
  final String videoId;
  final String videoUrl;
  final String username;
  final String caption;
  final String? localPath;
  final DownloadStatus status;
  final double progress;
  final DateTime? downloadedAt;

  const DownloadEntity({
    required this.id,
    required this.videoId,
    required this.videoUrl,
    required this.username,
    required this.caption,
    this.localPath,
    required this.status,
    required this.progress,
    this.downloadedAt,
  });

  DownloadEntity copyWith({
    DownloadStatus? status,
    double? progress,
    String? localPath,
    DateTime? downloadedAt,
  }) {
    return DownloadEntity(
      id: id,
      videoId: videoId,
      videoUrl: videoUrl,
      username: username,
      caption: caption,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoId': videoId,
        'videoUrl': videoUrl,
        'username': username,
        'caption': caption,
        'localPath': localPath,
        'status': status.name,
        'progress': progress,
        'downloadedAt': downloadedAt?.millisecondsSinceEpoch,
      };

  factory DownloadEntity.fromJson(Map<String, dynamic> json) => DownloadEntity(
        id: json['id'] as String,
        videoId: json['videoId'] as String,
        videoUrl: json['videoUrl'] as String,
        username: json['username'] as String,
        caption: json['caption'] as String,
        localPath: json['localPath'] as String?,
        status: DownloadStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => DownloadStatus.failed,
        ),
        progress: (json['progress'] as num).toDouble(),
        downloadedAt: json['downloadedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['downloadedAt'] as int)
            : null,
      );

  @override
  List<Object?> get props =>
      [id, videoId, videoUrl, localPath, status, progress, downloadedAt];
}
