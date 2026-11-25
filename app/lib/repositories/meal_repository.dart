import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/meal_snapshot.dart';

class MealRepository {
  MealRepository(this.client, {this.timeout = const Duration(seconds: 12)});

  final http.Client client;
  final Duration timeout;
  static final endpoint = Uri.parse(
    'https://raw.githubusercontent.com/wkreho/geubsik/main/data/meals.json',
  );

  Future<({MealSnapshot snapshot, String source})> fetch({
    bool manual = false,
  }) async {
    final url = manual
        ? endpoint.replace(
            queryParameters: {
              'refresh': DateTime.now().microsecondsSinceEpoch.toString(),
            },
          )
        : endpoint;
    final response = await client.get(url).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', url);
    }
    final source = utf8.decode(response.bodyBytes);
    return (snapshot: MealSnapshot.parse(source), source: source);
  }
}
