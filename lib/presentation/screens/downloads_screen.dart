import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/download_entity.dart';
import '../bloc/download_bloc.dart';
import '../bloc/download_event.dart';
import '../bloc/download_state.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocBuilder<DownloadBloc, DownloadState>(
        builder: (context, state) {
          final completed = state.downloads.values
              .where((d) => d.status == DownloadStatus.completed)
              .toList();
          final inProgress = state.downloads.values
              .where((d) => d.status == DownloadStatus.downloading)
              .toList();

          if (completed.isEmpty && inProgress.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_outlined,
                      color: Colors.white38, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No downloads yet',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap the save icon on any reel to download it.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final items = [...inProgress, ...completed];

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Colors.white12, height: 1),
            itemBuilder: (context, index) {
              final download = items[index];
              return _DownloadTile(download: download);
            },
          );
        },
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadEntity download;

  const _DownloadTile({required this.download});

  @override
  Widget build(BuildContext context) {
    final isDownloading = download.status == DownloadStatus.downloading;

    return Dismissible(
      key: ValueKey(download.videoId),
      direction: isDownloading
          ? DismissDirection.none // Can't swipe away in-progress downloads
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade900,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => context
          .read<DownloadBloc>()
          .add(DeleteDownload(download.videoId)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isDownloading ? Icons.downloading : Icons.movie_outlined,
            color: Colors.white54,
          ),
        ),
        title: Text(
          download.username,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              download.caption,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isDownloading) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: download.progress,
                backgroundColor: Colors.white12,
                color: Colors.white70,
                minHeight: 2,
              ),
              const SizedBox(height: 2),
              Text(
                '${(download.progress * 100).toInt()}%',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ] else if (download.downloadedAt != null) ...[
              const SizedBox(height: 2),
              Text(
                _formatDate(download.downloadedAt!),
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
        trailing: isDownloading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              )
            : IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white38),
                onPressed: () => context
                    .read<DownloadBloc>()
                    .add(DeleteDownload(download.videoId)),
              ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
