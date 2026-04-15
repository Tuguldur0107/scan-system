import 'package:postgres/postgres.dart';

import 'base_repository.dart';

class TenantRepository extends BaseRepository {
  Future<List<Map<String, dynamic>>> findAll() async {
    final result = await db.execute('''
      SELECT
        t.*,
        COUNT(DISTINCT u.id) AS user_count,
        COUNT(DISTINCT s.id) AS scan_count
      FROM tenants t
      LEFT JOIN users u ON u.tenant_id = t.id
      LEFT JOIN scans s ON s.tenant_id = t.id
      GROUP BY t.id
      ORDER BY t.created_at DESC
    ''');
    return result.map(_rowToMap).toList();
  }

  Future<Map<String, dynamic>?> findById(String id) async {
    final result = await db.execute(
      Sql.named('''
        SELECT
          t.*,
          COUNT(DISTINCT u.id) AS user_count,
          COUNT(DISTINCT s.id) AS scan_count
        FROM tenants t
        LEFT JOIN users u ON u.tenant_id = t.id
        LEFT JOIN scans s ON s.tenant_id = t.id
        WHERE t.id = @id
        GROUP BY t.id
      '''),
      parameters: {'id': id},
    );
    return result.isEmpty ? null : _rowToMap(result.first);
  }

  Future<Map<String, dynamic>?> findBySlug(String slug) async {
    final result = await db.execute(
      Sql.named('''
        SELECT
          t.*,
          COUNT(DISTINCT u.id) AS user_count,
          COUNT(DISTINCT s.id) AS scan_count
        FROM tenants t
        LEFT JOIN users u ON u.tenant_id = t.id
        LEFT JOIN scans s ON s.tenant_id = t.id
        WHERE t.slug = @slug
        GROUP BY t.id
      '''),
      parameters: {'slug': slug},
    );
    return result.isEmpty ? null : _rowToMap(result.first);
  }

  Future<Map<String, dynamic>> create({
    required String name,
    required String slug,
    Map<String, dynamic> settings = const {},
  }) async {
    final result = await db.execute(
      Sql.named(
        '''INSERT INTO tenants (name, slug, settings)
           VALUES (@name, @slug, @settings::jsonb)
           RETURNING *''',
      ),
      parameters: {
        'name': name,
        'slug': slug,
        'settings': settings.toString(),
      },
    );
    final id = result.first.toColumnMap()['id'].toString();
    return (await findById(id))!;
  }

  Future<Map<String, dynamic>?> update(
    String id, {
    String? name,
    String? slug,
    bool? isActive,
    Map<String, dynamic>? settings,
  }) async {
    final sets = <String>[];
    final params = <String, dynamic>{'id': id};

    if (name != null) {
      sets.add('name = @name');
      params['name'] = name;
    }
    if (slug != null) {
      sets.add('slug = @slug');
      params['slug'] = slug;
    }
    if (isActive != null) {
      sets.add('is_active = @is_active');
      params['is_active'] = isActive;
    }
    if (settings != null) {
      sets.add("settings = @settings::jsonb");
      params['settings'] = settings.toString();
    }

    if (sets.isEmpty) return findById(id);

    sets.add('updated_at = NOW()');

    final result = await db.execute(
      Sql.named(
          'UPDATE tenants SET ${sets.join(', ')} WHERE id = @id RETURNING *'),
      parameters: params,
    );
    if (result.isEmpty) return null;
    return findById(id);
  }

  Future<bool> delete(String id) async {
    final result = await db.execute(
      Sql.named('DELETE FROM tenants WHERE id = @id'),
      parameters: {'id': id},
    );
    return result.affectedRows > 0;
  }

  Map<String, dynamic> _rowToMap(ResultRow row) {
    final schema = row.toColumnMap();
    return {
      'id': schema['id'].toString(),
      'name': schema['name'],
      'slug': schema['slug'],
      'is_active': schema['is_active'],
      'user_count': schema['user_count'] as int? ?? 0,
      'scan_count': schema['scan_count'] as int? ?? 0,
      'settings': schema['settings'] ?? {},
      'created_at': schema['created_at']?.toString(),
      'updated_at': schema['updated_at']?.toString(),
    };
  }
}
