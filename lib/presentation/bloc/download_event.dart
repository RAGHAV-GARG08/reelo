import 'package:equatable/equatable.dart';
import '../../domain/entities/video_entity.dart';

abstract class DownloadEvent extends Equatable {
  const DownloadEvent();
  @override
  List<Object?> get props => [];
}

class LoadDownloads extends DownloadEvent {
  const LoadDownloads();
}

class StartDownload extends DownloadEvent {
  final VideoEntity video;
  const StartDownload(this.video);
  @override
  List<Object?> get props => [video];
}

class DeleteDownload extends DownloadEvent {
  final String videoId;
  const DeleteDownload(this.videoId);
  @override
  List<Object?> get props => [videoId];
}
