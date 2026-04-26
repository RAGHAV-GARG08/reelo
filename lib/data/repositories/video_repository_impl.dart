import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/repositories/video_repository.dart';
import '../sources/video_remote_data_source.dart';

class VideoRepositoryImpl implements VideoRepository {
  final VideoRemoteDataSource remoteDataSource;

  VideoRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<VideoEntity>>> getVideos({
    String? lastDocumentId,
    int limit = 10,
  }) async {
    try {
      final models = await remoteDataSource.getVideos(
        lastDocumentId: lastDocumentId,
        limit: limit,
      );
      return Right(models);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
