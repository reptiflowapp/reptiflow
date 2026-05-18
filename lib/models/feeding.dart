import 'package:flutter/material.dart';

enum FeedingStatus {
  fed,
  partial,
  refused;

  String get label => switch (this) {
        FeedingStatus.fed => '급여완료',
        FeedingStatus.partial => '부분섭식',
        FeedingStatus.refused => '거부',
      };

  Color get color => switch (this) {
        FeedingStatus.fed => const Color(0xFF4CAF82),
        FeedingStatus.partial => const Color(0xFFFFA726),
        FeedingStatus.refused => const Color(0xFFEF5350),
      };

  String get value => switch (this) {
        FeedingStatus.fed => 'fed',
        FeedingStatus.partial => 'partial',
        FeedingStatus.refused => 'refused',
      };

  static FeedingStatus fromString(String s) => switch (s) {
        'partial' => FeedingStatus.partial,
        'refused' => FeedingStatus.refused,
        _ => FeedingStatus.fed,
      };
}

class FeedingRecipe {
  final String id;
  final String userId;
  final String name;
  final Map<String, int> components;
  final DateTime createdAt;

  const FeedingRecipe({
    required this.id,
    required this.userId,
    required this.name,
    required this.components,
    required this.createdAt,
  });

  factory FeedingRecipe.fromJson(Map<String, dynamic> j) {
    final raw = j['components'] as Map<String, dynamic>? ?? {};
    return FeedingRecipe(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      name: j['name'] as String,
      components: raw.map((k, v) => MapEntry(k, (v as num).toInt())),
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'components': components,
      };

  String get componentSummary {
    final entries = components.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => '${e.key} ${e.value}%').join(' · ');
  }
}

class FeedingLog {
  final String id;
  final String reptileId;
  final String? recipeId;
  final DateTime fedAt;
  final FeedingStatus status;
  final String? memo;
  final DateTime createdAt;

  const FeedingLog({
    required this.id,
    required this.reptileId,
    this.recipeId,
    required this.fedAt,
    required this.status,
    this.memo,
    required this.createdAt,
  });

  factory FeedingLog.fromJson(Map<String, dynamic> j) => FeedingLog(
        id: j['id'] as String,
        reptileId: j['reptile_id'] as String,
        recipeId: j['recipe_id'] as String?,
        fedAt: DateTime.parse(j['fed_at'] as String),
        status: FeedingStatus.fromString(j['status'] as String? ?? 'fed'),
        memo: j['memo'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'reptile_id': reptileId,
        if (recipeId != null) 'recipe_id': recipeId,
        'fed_at': fedAt.toIso8601String(),
        'status': status.value,
        if (memo != null && memo!.isNotEmpty) 'memo': memo,
      };
}
