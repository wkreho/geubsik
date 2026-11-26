import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'controllers/meal_controller.dart';
import 'controllers/settings_controller.dart';
import 'repositories/meal_repository.dart';
import 'screens/meal_shell.dart';
import 'services/meal_cache.dart';
import 'theme/app_theme.dart';
import 'utils/korea_date.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController(SettingsStorage());
  await settings.restore();
  runApp(MealApp(settings: settings));
}

class MealApp extends StatefulWidget {
  const MealApp({super.key, required this.settings});
  final SettingsController settings;

  @override
  State<MealApp> createState() => _MealAppState();
}

class _MealAppState extends State<MealApp> with WidgetsBindingObserver {
  final _client = http.Client();
  late final MealController _controller;
  late KoreaDate _today;
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    _controller = MealController(MealRepository(_client), MealCache());
    _today = _controller.today;
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
    unawaited(_controller.refresh());
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now().toUtc();
    final next = KoreaDate.today(
      now,
    ).next.calendar.subtract(const Duration(hours: 9));
    _midnight = Timer(next.difference(now), _syncDay);
  }

  void _syncDay() {
    final next = _controller.today;
    if (next != _today) {
      final followingToday = _controller.selected == _today;
      setState(() => _today = next);
      _controller.select(followingToday ? next : _controller.selected);
    }
    _scheduleMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncDay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _controller.dispose();
    widget.settings.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '급식',
      theme: mealTheme(widget.settings.value.background, Brightness.light),
      darkTheme: mealTheme(widget.settings.value.background, Brightness.dark),
      themeMode: widget.settings.value.theme,
      home: MealShell(meals: _controller, settings: widget.settings),
    ),
  );
}
