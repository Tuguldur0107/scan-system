import 'package:postgres/postgres.dart';

import 'base_repository.dart';

class ProjectRepository extends BaseRepository {
  Future<List<Map<String, dynamic>>> findByTenant(String tenantId) async {
    final result = await db.execute(
      Sql.named(
          'SELECT * FROM projects WHERE tenant_id = @tenant_id ORDER BY created_at DESC'),
      parameters: {'tenant_id': tenantId},
    );
    return result.map(_rowToMap).toList();
  }

  Future<Map<String, dynamic>?> findById(String id, String tenantId) async {
    final result = await db.execute(
      Sql.named(
          'SELECT * FROM projects WHERE id = @id AND tenant_id = @tenant_id'),
      parameters: {'id': id, 'tenant_id': tenantId},
    );
    return result.isEmpty ? null : _rowToMap(result.first);
  }

  Future<Map<String, dynamic>> create({
    required String tenantId,
    required String name,
    String? description,
    bool isOpen = true,
  }) async {
    final result = await db.execute(
      Sql.named(
        '''INSERT INTO projects (tenant_id, name, description, is_open)
           VALUES (@tenant_id, @name, @description, @is_open)
           RETURNING *''',
      ),
      parameters: {
        'tenant_id': tenantId,
        'name': name,
        'description': description,
        'is_open': isOpen,
      },
    );
    return _rowToMap(result.first);
  }

  Future<Map<String, dynamic>?> update(
    String id,
    String tenantId, {
    String? name,
    String? description,
    bool? isOpen,
  }) async {
    final sets = <String>[];
    final params = <String, dynamic>{'id': id, 'tenant_id': tenantId};

    if (name != null) {
      sets.add('name = @name');
      params['name'] = name;
    }
    if (description != null) {
      sets.add('description = @description');
      params['description'] = description;
    }
    if (isOpen != null) {
      sets.add('is_open = @is_open');
      params['is_open'] = isOpen;
    }

    if (sets.isEmpty) return findById(id, tenantId);

    sets.add('updated_at = NOW()');

    final result = await db.execute(
      Sql.named(
        'UPDATE projects SET ${sets.join(', ')} WHERE id = @id AND tenant_id = @tenant_id RETURNING *',
      ),
      parameters: params,
    );
    return result.isEmpty ? null : _rowToMap(result.first);
  }

  Future<bool> delete(String id, String tenantId) async {
    final result = await db.execute(
      Sql.named(
          'DELETE FROM projects WHERE id = @id AND tenant_id = @tenant_id'),
      parameters: {'id': id, 'tenant_id': tenantId},
    );
    return result.affectedRows > 0;
  }

  Map<String, dynamic> _rowToMap(ResultRow row) {
    final schema = row.toColumnMap();
    return {
      'id': schema['id'].toString(),
      'tenant_id': schema['tenant_id'].toString(),
      'name': schema['name'],
      'description': schema['description'],
      'is_open': schema['is_open'] as bool? ?? true,
      'created_at': schema['created_at']?.toString(),
      'updated_at': schema['updated_at']?.toString(),
    };
  }
}
