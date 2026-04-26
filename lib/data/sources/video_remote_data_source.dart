import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_model.dart';

/// Contract for fetching raw video data from a remote source.
abstract class VideoRemoteDataSource {
  Future<List<VideoModel>> getVideos({
    String? lastDocumentId,
    int limit = 10,
  });
}

/// Firestore implementation.
///
/// Collection schema — each document in `reels/` must have:
///   url       : String   — publicly accessible MP4 URL
///   username  : String   — e.g. "@johndoe"
///   caption   : String   — reel caption / hashtags
///   likes     : Number   — like count
///   createdAt : Timestamp — server timestamp used for ordering (set via
///                           FieldValue.serverTimestamp() when writing)
///
/// Pagination uses a DocumentSnapshot cursor (startAfterDocument) so each
/// page query is O(1) — no extra reads to resolve the cursor document.
class FirestoreVideoDataSource implements VideoRemoteDataSource {
  final FirebaseFirestore _firestore;

  /// Internal cursor: the last document fetched in the previous page.
  /// Kept in memory; resets to null on app restart (always starts from top).
  DocumentSnapshot? _lastDocument;

  FirestoreVideoDataSource(this._firestore);

  /// Resets the pagination cursor. Call this when performing a fresh fetch.
  void resetCursor() => _lastDocument = null;

  @override
  Future<List<VideoModel>> getVideos({
    String? lastDocumentId,
    int limit = 10,
  }) async {
    // A null lastDocumentId signals a fresh fetch — reset internal cursor.
    if (lastDocumentId == null) {
      _lastDocument = null;
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('reels')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
    }

    return snapshot.docs
        .map((doc) => VideoModel.fromJson(doc.id, doc.data()))
        .toList();
  }
}

// ---- STUB (kept for local dev / testing without Firebase) ----

/// Stub implementation returning hardcoded mock data.
/// Swap back in injection_container.dart for offline development.
class StubVideoRemoteDataSource implements VideoRemoteDataSource {
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
    if (lastDocumentId == null) return _mockVideos.take(limit).toList();
    final start = _mockVideos.indexWhere((v) => v.id == lastDocumentId);
    if (start == -1 || start >= _mockVideos.length - 1) return [];
    return _mockVideos.skip(start + 1).take(limit).toList();
  }
}
