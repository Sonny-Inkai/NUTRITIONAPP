import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';

enum MealSourceEntity {
  unknown,
  custom,
  off,
  fdc,
  logmeal;


  static MealSourceEntity fromMealSourceDBO(MealSourceDBO dbo) {
    switch (dbo) {
      case MealSourceDBO.unknown:
        return MealSourceEntity.unknown;
      case MealSourceDBO.custom:
        return MealSourceEntity.custom;
      case MealSourceDBO.off:
        return MealSourceEntity.off;
      case MealSourceDBO.fdc:
        return MealSourceEntity.fdc;
      case MealSourceDBO.logmeal:
        return MealSourceEntity.logmeal;
    }
  }
} 