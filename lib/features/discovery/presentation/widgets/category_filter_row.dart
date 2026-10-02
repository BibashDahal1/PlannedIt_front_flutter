import 'package:flutter/material.dart';

class CategoryFilterRow extends StatelessWidget {
  const CategoryFilterRow({super.key});

  static const categories = [
    'All',
    'Futsal',
    'Basketball',
    'Hiking',
    'Board Games',
    'Study',
    'Volunteering',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ChoiceChip(
          label: Text(categories[index]),
          selected: index == 0,
          onSelected: (_) {},
        ),
      ),
    );
  }
}
