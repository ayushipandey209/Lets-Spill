import 'package:equatable/equatable.dart';

/// A confession category (Relationships, School, Workplace, ...).
class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    this.description = '',
    this.order = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final String description;
  final int order;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'order': order,
  };

  @override
  List<Object?> get props => [id, name, description, order];
}

/// Lookup helper so widgets can turn a `categoryId` into a label.
class CategoryCatalog extends Equatable {
  CategoryCatalog(List<Category> categories)
    : categories = List.unmodifiable(
        [...categories]..sort((a, b) => a.order.compareTo(b.order)),
      ),
      _byId = {for (final c in categories) c.id: c};

  final List<Category> categories;
  final Map<String, Category> _byId;

  Category? byId(String id) => _byId[id];

  /// Display name, falling back to a title-cased id for unknown categories.
  String nameOf(String id) {
    final c = _byId[id];
    if (c != null) return c.name;
    if (id.isEmpty) return 'Other';
    return id[0].toUpperCase() + id.substring(1);
  }

  bool contains(String id) => _byId.containsKey(id);

  Set<String> get ids => _byId.keys.toSet();

  @override
  List<Object?> get props => [categories];
}
