import 'dart:convert';

import '../../../core/data/asset_loader.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/category.dart';
import '../domain/category_repository.dart';

class AssetCategoryRepository implements CategoryRepository {
  AssetCategoryRepository({required AssetLoader loader}) : _loader = loader;

  static const assetPath = 'assets/mock/categories.json';

  final AssetLoader _loader;
  CategoryCatalog? _cache;

  @override
  Future<CategoryCatalog> loadCategories() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final raw = await _loader(assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = (json['categories'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Category.fromJson)
          .toList();
      return _cache = CategoryCatalog(list);
    } catch (e) {
      throw UnknownException('Could not load categories.', e);
    }
  }
}
