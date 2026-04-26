import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/video_entity.dart';

abstract class VideoRepository {
  /// Fetches a paginated list of reels videos.
  ///
  /// [lastDocumentId] - Firestore cursor for pagination (null = first page)
  /// [limit]          - Number of videos per page
  Future<Either<Failure, List<VideoEntity>>> getVideos({
    String? lastDocumentId,
    int limit = 10,
  });
}
