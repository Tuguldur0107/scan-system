import 'package:equatable/equatable.dart';

class Tenant extends Equatable {
  const Tenant({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
    this.settings = const {},
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String slug;
  final bool isActive;
  final Map<String, dynamic> settings;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        isActive: json['is_active'] as bool? ?? true,
        settings: json['settings'] as Map<String, dynamic>? ?? {},
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'is_active': isActive,
        'settings': settings,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, name, slug, isActive];
}

class CreateTenantRequest {
  const CreateTenantRequest({
    required this.name,
    required this.slug,
    this.settings = const {},
  });

  final String name;
  final String slug;
  final Map<String, dynamic> settings;

  factory CreateTenantRequest.fromJson(Map<String, dynamic> json) =>
      CreateTenantRequest(
        name: json['name'] as String,
        slug: json['slug'] as String,
        settings: json['settings'] as Map<String, dynamic>? ?? {},
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'slug': slug,
        'settings': settings,
      };
}
