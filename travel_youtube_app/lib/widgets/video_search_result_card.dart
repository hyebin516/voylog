import 'package:flutter/material.dart';

import '../models/video_search_result_model.dart';
import 'app_card.dart';

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
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
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
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (result.channelName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    result.channelName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
