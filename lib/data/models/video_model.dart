import '../../domain/entities/video_entity.dart';

/// Data Transfer Object. Extends VideoEntity so it can be used
/// directly wherever a VideoEntity is expected (Liskov Substitution).
class VideoModel extends VideoEntity {
  const VideoModel({
    required super.id,
    required super.url,
    required super.username,
    required super.caption,
    required super.likes,
  });

  /// Deserialize from a Firestore document map.
  factory VideoModel.fromJson(String docId, Map<String, dynamic> json) {
    return VideoModel(
      id: docId,
      url: json['url'] as String? ?? '',
      username: json['username'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'username': username,
      'caption': caption,
      'likes': likes,
    };
  }
}
