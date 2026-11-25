import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/meal_snapshot.dart';
import '../repositories/meal_repository.dart';
import '../services/meal_cache.dart';
import '../utils/korea_date.dart';

enum MealStatus { loading, refreshing, ready, stale, failed }

enum MealSource { cache, remote }

class MealController extends ChangeNotifier {
  MealController(this._repository, this._cache, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    selected = today;
  }

  final MealRepository _repository;
  final MealCache _cache;
  final DateTime Function() _now;
  Future<void>? _pending;
  bool _checkedCache = false;
  bool _disposed = false;

  late KoreaDate selected;
  KoreaDate get today => KoreaDate.today(_now());
  MealSnapshot? snapshot;
  MealSource? source;
  MealStatus status = MealStatus.loading;
  String? message;

  void select(KoreaDate date) {
    selected = date;
    _publish();
  }

  Future<void> refresh({bool manual = false}) {
    return _pending ??= Future.microtask(() => _load(manual)).whenComplete(() {
      _pending = null;
    });
  }

  Future<void> _load(bool manual) async {
    if (_disposed) return;
    message = null;
    status = snapshot == null ? MealStatus.loading : MealStatus.refreshing;
    _publish();
    if (!_checkedCache) {
      _checkedCache = true;
      try {
        final stored = await _cache.read();
        if (stored != null) {
          snapshot = MealSnapshot.parse(stored);
          source = MealSource.cache;
          status = MealStatus.refreshing;
          _publish();
        }
      } catch (_) {
        // Storage may be unavailable or contain a damaged snapshot.
      }
    }
    if (_disposed) return;
    try {
      final result = await _repository.fetch(manual: manual);
      if (_disposed) return;
      snapshot = result.snapshot;
      source = MealSource.remote;
      status = MealStatus.ready;
      _publish();
      try {
        await _cache.write(result.source);
      } catch (_) {
        message = '기기에 저장하지 못했습니다. 현재 급식표는 볼 수 있습니다.';
      }
    } catch (error) {
      status = snapshot == null ? MealStatus.failed : MealStatus.stale;
      message = switch (error) {
        TimeoutException() => '요청 시간이 초과되었습니다.',
        FormatException() => '급식 데이터 형식을 확인할 수 없습니다.',
        http.ClientException(:final message) when message.startsWith('HTTP ') =>
          '급식 서버가 오류를 반환했습니다 ($message).',
        _ => '급식 서버에 연결할 수 없습니다.',
      };
    }
    _publish();
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
