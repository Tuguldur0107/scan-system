import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.tenantId,
    required this.username,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String username;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        username: json['username'] as String,
        role: json['role'] as String,
        isActive: json['is_active'] as bool? ?? true,
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
        'username': username,
        'role': role,
        'is_active': isActive,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, tenantId, username, role, isActive];
}

class CreateUserRequest {
  const CreateUserRequest({
    required this.username,
    required this.password,
    required this.role,
  });

  final String username;
  final String password;
  final String role;

  factory CreateUserRequest.fromJson(Map<String, dynamic> json) =>
      CreateUserRequest(
        username: json['username'] as String,
        password: json['password'] as String,
        role: json['role'] as String,
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'role': role,
      };
}

class UpdateUserRequest {
  const UpdateUserRequest({
    this.username,
    this.password,
    this.role,
    this.isActive,
  });

  final String? username;
  final String? password;
  final String? role;
  final bool? isActive;

  factory UpdateUserRequest.fromJson(Map<String, dynamic> json) =>
      UpdateUserRequest(
        username: json['username'] as String?,
        password: json['password'] as String?,
        role: json['role'] as String?,
        isActive: json['is_active'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        if (username != null) 'username': username,
        if (password != null) 'password': password,
        if (role != null) 'role': role,
        if (isActive != null) 'is_active': isActive,
      };
}
