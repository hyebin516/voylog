import 'package:flutter/material.dart';

import '../models/video_search_result_model.dart';

class VideoSearchResultCard extends StatelessWidget {
  final VideoSearchResultModel result;
  final VoidCallback onTap;

  const VideoSearchResultCard({
    super.key,
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: SizedBox(
          width: 80,
          height: 56,
          child: result.thumbnailUrl != null
              ? Image.network(
                  result.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.smart_display_outlined),
                )
              : const Icon(Icons.smart_display_outlined),
        ),
        title: Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: result.channelName != null ? Text(result.channelName!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
        onTap: onTap,
      ),
    );
  }
}
