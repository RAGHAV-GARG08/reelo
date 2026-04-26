import 'package:equatable/equatable.dart';

class VideoEntity extends Equatable {
  final String id;
  final String url;
  final String username;
  final String caption;
  final int likes;

  const VideoEntity({
    required this.id,
    required this.url,
    required this.username,
    required this.caption,
    required this.likes,
  });

  @override
  List<Object?> get props => [id, url, username, caption, likes];
}
