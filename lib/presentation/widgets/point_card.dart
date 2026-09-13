import 'package:flutter/material.dart';
import '../../data/models/survey_point_model.dart';
import '../theme/app_theme.dart';

class PointCard extends StatelessWidget {
  final SurveyPointModel point;
  final VoidCallback? onDelete;

  const PointCard({
    Key? key,
    required this.point,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.strokeNavy, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.crimsonPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.crimsonPrimary.withOpacity(0.4)),
                    ),
                    child: Text(
                      point.ptName,
                      style: const TextStyle(
                        color: AppTheme.crimsonAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    point.ptType.name.replaceAll('_', ' '),
                    style: const TextStyle(
                      color: AppTheme.slateMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.slateMuted),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCoordCol('EASTING (X)', '${point.easting.toStringAsFixed(3)} m'),
              ),
              Container(width: 1, height: 28, color: AppTheme.strokeNavy),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _buildCoordCol('NORTHING (Y)', '${point.northing.toStringAsFixed(3)} m'),
                ),
              ),
              Container(width: 1, height: 28, color: AppTheme.strokeNavy),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _buildCoordCol('ELEVATION (Z)', '${point.height.toStringAsFixed(3)} m'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoordCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.slateMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.pureWhite,
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
