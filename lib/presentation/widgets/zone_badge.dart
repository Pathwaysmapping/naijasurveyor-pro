import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ZoneBadge extends StatelessWidget {
  final int zone;
  final String datum;

  const ZoneBadge({
    Key? key,
    required this.zone,
    required this.datum,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.elevatedNavy,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.strokeNavy, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.crimsonPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'UTM Zone ${zone}N',
            style: const TextStyle(
              color: AppTheme.pureWhite,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            datum == 'MINNA_UTM' ? 'Minna 1965' : 'WGS84',
            style: const TextStyle(
              color: AppTheme.slateText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
