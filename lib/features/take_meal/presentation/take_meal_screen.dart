import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opennutritracker/core/utils/env.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_source_entity.dart';
import 'package:uuid/uuid.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/image_cache_manager.dart';
import 'package:opennutritracker/features/take_meal/presentation/widgets/nutrition_info_card.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';

class TakeMealScreen extends StatefulWidget {
  const TakeMealScreen({super.key});

  @override
  State<TakeMealScreen> createState() => _TakeMealScreenState();
}

class _TakeMealScreenState extends State<TakeMealScreen> with WidgetsBindingObserver {
  File? _image;
  bool _isLoading = false;
  Map<String, dynamic>? _nutritionData;
  IntakeTypeEntity _selectedMealType = IntakeTypeEntity.breakfast;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1024,
        maxHeight: 1024,


      );

      if (pickedFile == null) {
        return;
      }

      final file = File(pickedFile.path);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image file not found!')),
        );
        return;
      }

      setState(() {
        _image = file;
        _isLoading = true;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      await _analyzeImage(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing camera: $e')),
        );
      }
    }
  }

  Future<void> _analyzeImage(File image) async {
    try {
      // Step 1: Call segmentation endpoint to get imageId
      var segmentationUri = Uri.parse('https://api.logmeal.com/v2/image/segmentation/complete');
      var request = http.MultipartRequest('POST', segmentationUri);
      request.headers['Authorization'] = 'Bearer ${Env.logmealApiToken}';
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      
      var streamedResponse = await request.send();
      var segmentationResponse = await http.Response.fromStream(streamedResponse);
      
      if (segmentationResponse.statusCode != 200) {
        String errorMsg = (segmentationResponse.statusCode == 401)
            ? 'Segmentation API unauthorized (401): Invalid LogMeal API token.'
            : 'Segmentation API failed: ${segmentationResponse.statusCode}';
        throw Exception(errorMsg);
      }
      
      var segmentationData = jsonDecode(segmentationResponse.body);
      var imageId = segmentationData['imageId'];

      // Step 2: Call nutritional info endpoint with the obtained imageId
      var nutritionUri = Uri.parse('https://api.logmeal.com/v2/recipe/nutritionalInfo');
      var nutritionResponse = await http.post(
        nutritionUri,
        headers: {
          'Authorization': 'Bearer ${Env.logmealApiToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'imageId': imageId}),
      );

      if (nutritionResponse.statusCode == 200) {
        setState(() {
          _nutritionData = jsonDecode(nutritionResponse.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Nutritional Info API failed: ${nutritionResponse.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error analyzing image: $e')),
      );
    }
  }

  Future<void> _saveMeal() async {
    if (_nutritionData == null || _image == null) return;
    
    // Extract food name and calories from API response
    final foodName = (_nutritionData!['foodName'] is List &&
            _nutritionData!['foodName'].isNotEmpty)
        ? _nutritionData!['foodName'][0] as String
        : 'Unknown Meal';
    final calories = (_nutritionData!['nutritional_info'] != null &&
            _nutritionData!['nutritional_info']['calories'] != null)
        ? _nutritionData!['nutritional_info']['calories'].toString()
        : 'N/A';
    
    // Show confirmation dialog with meal details
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Meal"),
          content:
              Text("Meal: $foodName\nCalories: $calories\nDo you want to save this meal?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Retake"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
    
    if (confirm != true) {
      // User chose to retake; optionally delete the temporary image file to free memory,
      // and reset the image and nutritional data along with the loading flag.
      if (_image != null) {
        try {
          _image!.deleteSync();
        } catch (_) {
          // ignore any file deletion errors
        }
      }
      setState(() {
        _nutritionData = null;
        _image = null;
        _isLoading = false;
      });
      return;
    }
    
    try {
      setState(() => _isLoading = true);
      
      // Save image to app directory
      final savedImagePath = await ImageCacheManager.saveImage(_image!);
      
      // Create a MealDBO directly using LogMeal API response factory
      final meal = MealDBO.fromLogmealResponse(_nutritionData!);
      
      // Create intake entry
      final intake = IntakeDBO(
        id: const Uuid().v4(),
        unit: 'serving',
        amount: 1.0,
        type: _selectedMealType.toIntakeTypeDBO(),
        meal: meal,
        dateTime: DateTime.now(),
      );
      
      // Save to database
      await locator<IntakeDataSource>().addIntake(intake);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal saved successfully')),
        );
        // After saving, navigate to the home screen so the diary is shown.
        Navigator.pushNamedAndRemoveUntil(
          context,
          NavigationOptions.mainRoute,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving meal: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).addLabel),
        actions: [
          if (_nutritionData != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _isLoading ? null : _saveMeal,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_image != null) 
              Container(
                height: 250,
                child: Image.file(
                  _image!,
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
            if (_isLoading) 
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_nutritionData != null) ...[
              _buildMealTypeSelector(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _nutritionData!['foodName']?.join(', ') ?? 'Unknown Meal',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              NutritionInfoCard(nutritionData: _nutritionData!),
            ],
            if (_image == null)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Take a photo of your meal',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _takePicture,
                icon: const Icon(Icons.camera_alt),
                label: Text(_image == null ? 'Take Photo' : 'Retake Photo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SegmentedButton<IntakeTypeEntity>(
        segments: IntakeTypeEntity.values.map((type) => ButtonSegment(
          value: type,
          label: Text(type.name),
          icon: Icon(type.getIconData()),
        )).toList(),
        selected: {_selectedMealType},
        onSelectionChanged: (Set<IntakeTypeEntity> selected) {
          setState(() {
            _selectedMealType = selected.first;
          });
        },
      ),
    );
  }
}

class NutritionRow extends StatelessWidget {
  final String label;
  final String value;

  const NutritionRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text('${value}g', style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
} 