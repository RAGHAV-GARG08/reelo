import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/usecase/usecase.dart';
import '../entities/download_entity.dart';
import '../repositories/download_repository.dart';

class GetDownloadsUseCase extends UseCase<List<DownloadEntity>, NoParams> {
  final DownloadRepository repository;
  GetDownloadsUseCase(this.repository);

  @override
  Future<Either<Failure, List<DownloadEntity>>> call(NoParams params) async {
    try {
      final downloads = await repository.getDownloads();
      return Right(downloads);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
