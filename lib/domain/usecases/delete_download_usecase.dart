import '../repositories/download_repository.dart';

class DeleteDownloadUseCase {
  final DownloadRepository repository;
  DeleteDownloadUseCase(this.repository);

  Future<void> call(String videoId) => repository.deleteDownload(videoId);
}
