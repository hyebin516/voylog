import 'package:flutter/material.dart';

import '../core/constants/public_data_sources.dart';
import '../core/theme/app_theme.dart';

/// One-line public-data source credit shown under place lists that can
/// include dataset places (see [PublicDataSources]).
class DataSourceAttribution extends StatelessWidget {
  const DataSourceAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        PublicDataSources.caption,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
    );
  }
}
