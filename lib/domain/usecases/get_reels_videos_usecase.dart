import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../core/error/failures.dart';
import '../../core/usecase/usecase.dart';
import '../entities/video_entity.dart';
import '../repositories/video_repository.dart';

class GetReelsVideosUseCase extends UseCase<List<VideoEntity>, GetReelsParams> {
  final VideoRepository repository;

  GetReelsVideosUseCase(this.repository);

  @override
  Future<Either<Failure, List<VideoEntity>>> call(GetReelsParams params) {
    return repository.getVideos(
      lastDocumentId: params.lastDocumentId,
      limit: params.limit,
    );
  }
}

class GetReelsParams extends Equatable {
  final String? lastDocumentId;
  final int limit;

  const GetReelsParams({
    this.lastDocumentId,
    this.limit = 10,
  });

  @override
  List<Object?> get props => [lastDocumentId, limit];
}
