import 'package:hive_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_source_entity.dart';

part 'meal_dbo.g.dart';

@HiveType(typeId: 1)
class MealDBO extends HiveObject {
  @HiveField(0)
  final String? code;
  @HiveField(1)
  final String? name;

  @HiveField(2)
  final String? brands;

  @HiveField(3)
  final String? thumbnailImageUrl;
  @HiveField(4)
  final String? mainImageUrl;

  @HiveField(5)
  final String? url;

  @HiveField(6)
  final String? mealQuantity;
  @HiveField(7)
  final String? mealUnit;
  @HiveField(8)
  final double? servingQuantity;
  @HiveField(9)
  final String? servingUnit;

  @HiveField(10)
  final MealSourceDBO source;

  @HiveField(11)
  final MealNutrimentsDBO nutriments;

  MealDBO(
      {required this.code,
      required this.name,
      required this.brands,
      required this.thumbnailImageUrl,
      required this.mainImageUrl,
      required this.url,
      required this.mealQuantity,
      required this.mealUnit,
      required this.servingQuantity,
      required this.servingUnit,
      required this.nutriments,
      required this.source});

  factory MealDBO.fromMealEntity(
          MealEntity mealEntity) =>
      MealDBO(
          code: mealEntity.code,
          name: mealEntity.name,
          brands: mealEntity.brands,
          thumbnailImageUrl: mealEntity.thumbnailImageUrl,
          mainImageUrl: mealEntity.mainImageUrl,
          url: mealEntity.url,
          mealQuantity: mealEntity.mealQuantity,
          mealUnit: mealEntity.mealUnit,
          servingQuantity: mealEntity.servingQuantity,
          servingUnit: mealEntity.servingUnit,
          nutriments:
              MealNutrimentsDBO.fromProductNutrimentsEntity(
                  mealEntity.nutriments),
          source:
              MealSourceDBO.fromMealSourceEntity(mealEntity.source));

  factory MealDBO.fromLogmealResponse(Map<String, dynamic> response) {
    final foodName = (response['foodName'] is List && response['foodName'].isNotEmpty)
        ? response['foodName'][0] as String
        : 'Unknown';
    final imageId = response['imageId'];
    final calories = (response['nutritional_info'] != null)
        ? response['nutritional_info']['calories'] as double?
        : null;
    
    return MealDBO(
      code: null,
      name: foodName,
      brands: null,
      thumbnailImageUrl: imageId != null
          ? 'https://logmealapi.com/images/$imageId'
          : null,
      mainImageUrl: null,
      url: null,
      mealQuantity: null,
      mealUnit: null,
      servingQuantity: 0,
      servingUnit: null,
      nutriments: MealNutrimentsDBO(
        energyKcal100: calories,
        carbohydrates100: null,
        fat100: null,
        proteins100: null,
        sugars100: null,
        saturatedFat100: null,
        fiber100: null,
      ),
      source: MealSourceDBO.logmeal,
    );
  }
}

@HiveType(typeId: 14)
enum MealSourceDBO {
  @HiveField(0)
  unknown,
  @HiveField(1)
  custom,
  @HiveField(2)
  off,
  @HiveField(3)
  fdc,
  @HiveField(4)
  logmeal;

  factory MealSourceDBO.fromMealSourceEntity(MealSourceEntity entity) {
    MealSourceDBO mealSourceDBO;
    switch (entity) {
      case MealSourceEntity.unknown:
        mealSourceDBO = MealSourceDBO.unknown;
        break;
      case MealSourceEntity.custom:
        mealSourceDBO = MealSourceDBO.custom;
        break;
      case MealSourceEntity.off:
        mealSourceDBO = MealSourceDBO.off;
        break;
      case MealSourceEntity.fdc:
        mealSourceDBO = MealSourceDBO.fdc;
        break;
      case MealSourceEntity.logmeal:
        mealSourceDBO = MealSourceDBO.logmeal;
        break;
    }
    return mealSourceDBO;
  }
}
