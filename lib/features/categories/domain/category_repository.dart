import 'category.dart';

/// Source of the category catalog.
///
/// Categories are a small, rarely-changing list. Both data modes load them
/// from the bundled `assets/mock/categories.json`, which avoids a Firestore
/// read on every launch. Firestore security rules mirror the same id list so
/// the server rejects unknown categories (see `firebase/firestore.rules`).
abstract interface class CategoryRepository {
  Future<CategoryCatalog> loadCategories();
}
