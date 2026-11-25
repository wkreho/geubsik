import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'controllers/meal_controller.dart';
import 'repositories/meal_repository.dart';
import 'screens/debug_meals_screen.dart';
import 'services/meal_cache.dart';

void main() => runApp(const MealApp());

class MealApp extends StatefulWidget {
  const MealApp({super.key});

  @override
  State<MealApp> createState() => _MealAppState();
}

class _MealAppState extends State<MealApp> {
  final _client = http.Client();
  late final MealController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MealController(MealRepository(_client), MealCache());
    unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '급식',
    home: DebugMealsScreen(controller: _controller),
  );
}
