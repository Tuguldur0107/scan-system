import 'package:equatable/equatable.dart';

class Project extends Equatable {
  const Project({
    required this.id,
    required this.tenantId,
    required this.name,
    this.description,
    this.isOpen = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String name;
  final String? description;
  final bool isOpen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        isOpen: json['is_open'] as bool? ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'name': name,
        if (description != null) 'description': description,
        'is_open': isOpen,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, tenantId, name, isOpen];
}

class CreateProjectRequest {
  const CreateProjectRequest({
    required this.name,
    this.description,
    this.isOpen = true,
  });

  final String name;
  final String? description;
  final bool isOpen;

  factory CreateProjectRequest.fromJson(Map<String, dynamic> json) =>
      CreateProjectRequest(
        name: json['name'] as String,
        description: json['description'] as String?,
        isOpen: json['is_open'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'is_open': isOpen,
      };
}
