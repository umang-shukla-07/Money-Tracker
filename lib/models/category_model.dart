import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isSystem;
  final String? description;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isSystem = false,
    this.description,
  });

  static const List<CategoryModel> defaultCategories = [
    CategoryModel(
      id: 'cat_food',
      name: 'Food & Dining',
      icon: Icons.restaurant,
      color: Color(0xFFF97316),
      isSystem: true,
    ),
    CategoryModel(
      id: 'cat_shopping',
      name: 'Shopping',
      icon: Icons.shopping_bag,
      color: Color(0xFFA855F7),
      isSystem: true,
    ),
    CategoryModel(
      id: 'cat_investments',
      name: 'Investments & SIP',
      icon: Icons.trending_up,
      color: Color(0xFF10B981),
      isSystem: true,
    ),
    CategoryModel(
      id: 'cat_transport',
      name: 'Transport & Fuel',
      icon: Icons.directions_car,
      color: Color(0xFF84CC16),
      isSystem: true,
    ),
    CategoryModel(
      id: 'cat_bills',
      name: 'Bills & Utilities',
      icon: Icons.bolt,
      color: Color(0xFFEAB308),
      isSystem: true,
    ),
    CategoryModel(
      id: 'cat_entertainment',
      name: 'Entertainment',
      icon: Icons.movie,
      color: Color(0xFFEC4899),
      isSystem: true,
    ),
    CategoryModel(
      id: 'cat_income',
      name: 'Salary & Income',
      icon: Icons.account_balance_wallet,
      color: Color(0xFF34D399),
      isSystem: true,
    ),
    CategoryModel(
      id: 'cat_other',
      name: 'Other',
      icon: Icons.category,
      color: Color(0xFF94A3B8),
      isSystem: true,
    ),
  ];
}

