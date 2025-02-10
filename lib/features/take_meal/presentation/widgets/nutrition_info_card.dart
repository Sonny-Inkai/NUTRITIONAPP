import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';

class NutritionInfoCard extends StatelessWidget {
  final Map<String, dynamic> nutritionData;

  const NutritionInfoCard({Key? key, required this.nutritionData})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Safely extract nutritional info. If missing, default to an empty map.
    final nutritionalInfo = nutritionData['nutritional_info'] ?? {};
    // Extract calories if provided; otherwise, use 'N/A'
    final calories = nutritionalInfo['calories'] is num
        ? (nutritionalInfo['calories'] as num).toDouble().toStringAsFixed(0)
        : 'N/A';

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          // Display only the calories value
          child: Text(
            'Calories: $calories ${S.of(context).kcalLabel}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
      ),
    );
  }
} 