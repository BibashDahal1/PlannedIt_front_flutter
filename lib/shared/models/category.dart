import 'package:flutter/material.dart';

class Category {
  final int id;
  final String name;
  final String iconKey;

  const Category({required this.id, required this.name, required this.iconKey});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as int,
    name: json['name'] as String,
    iconKey: json['icon'] as String,
  );

  /// Maps the backend's icon key strings to Material icons. Add cases here
  /// as new categories are added server-side; falls back gracefully.
  IconData get icon {
    switch (iconKey) {
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'sports_basketball':
        return Icons.sports_basketball;
      case 'hiking':
        return Icons.hiking;
      case 'casino':
        return Icons.casino;
      case 'school':
        return Icons.school;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      case 'more_horiz':
        return Icons.more_horiz;
      default:
        return Icons.category_outlined;
    }
  }
}
