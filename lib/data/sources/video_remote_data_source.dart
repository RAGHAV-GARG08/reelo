import '../models/video_model.dart';

/// Contract for fetching raw video data from a remote source (e.g., Firestore).
abstract class VideoRemoteDataSource {
  Future<List<VideoModel>> getVideos({
    String? lastDocumentId,
    int limit = 10,
  });
}

/// Stub implementation returning hardcoded mock data.
/// Replace with FirestoreVideoDataSource once Firebase SDK is integrated.
class StubVideoRemoteDataSource implements VideoRemoteDataSource {
  /// Publicly accessible test MP4s maintained by Flutter and W3C.
  static const List<String> _testUrls = [
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    'https://media.w3.org/2010/05/sintel/trailer.mp4',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    'https://www.w3schools.com/html/mov_bbb.mp4',
  ];

  static final List<VideoModel> _mockVideos = List.generate(
    20,
    (i) => VideoModel(
      id: 'video_$i',
      url: _testUrls[i % _testUrls.length],
      username: '@user_${i + 1}',
      caption: 'Reel caption #${i + 1} 🎬 #reels #flutter',
      likes: (i + 1) * 432,
    ),
  );

  @override
  Future<List<VideoModel>> getVideos({
    String? lastDocumentId,
    int limit = 10,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (lastDocumentId == null) {
      return _mockVideos.take(limit).toList();
    }

    final startIndex = _mockVideos.indexWhere((v) => v.id == lastDocumentId);
    if (startIndex == -1 || startIndex >= _mockVideos.length - 1) {
      return [];
    }

    return _mockVideos.skip(startIndex + 1).take(limit).toList();
  }
}

// ---- PRODUCTION IMPLEMENTATION (commented out - no Firebase import) ----
//
// class FirestoreVideoDataSource implements VideoRemoteDataSource {
//   final FirebaseFirestore _firestore;
//   DocumentSnapshot? _lastDocument;
//
//   FirestoreVideoDataSource(this._firestore);
//
//   @override
//   Future<List<VideoModel>> getVideos({
//     String? lastDocumentId,
//     int limit = 10,
//   }) async {
//     Query query = _firestore
//         .collection('reels')
//         .orderBy('createdAt', descending: true)
//         .limit(limit);
//
//     if (_lastDocument != null) {
//       query = query.startAfterDocument(_lastDocument!);
//     }
//
//     final snapshot = await query.get();
//     if (snapshot.docs.isNotEmpty) {
//       _lastDocument = snapshot.docs.last;
//     }
//     return snapshot.docs
//         .map((doc) => VideoModel.fromJson(doc.id, doc.data() as Map<String, dynamic>))
//         .toList();
//   }
// }
