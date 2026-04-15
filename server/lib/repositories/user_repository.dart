import 'package:bcrypt/bcrypt.dart';
import 'package:postgres/postgres.dart';

import 'base_repository.dart';

class UserRepository extends BaseRepository {
  Future<List<Map<String, dynamic>>> findByTenant(String tenantId) async {
    final result = await db.execute(
      Sql.named(
        'SELECT id, tenant_id, username, role, is_active, created_at, updated_at FROM users WHERE tenant_id = @tenant_id ORDER BY created_at DESC',
      ),
      parameters: {'tenant_id': tenantId},
    );
    return result.map(_rowToMap).toList();
  }

  Future<Map<String, dynamic>?> findById(String id) async {
    final result = await db.execute(
      Sql.named(
        'SELECT id, tenant_id, username, role, is_active, created_at, updated_at FROM users WHERE id = @id',
      ),
      parameters: {'id': id},
    );
    return result.isEmpty ? null : _rowToMap(result.first);
  }

  Future<Map<String, dynamic>?> findByUsernameAndTenant(
    String username,
    String tenantId,
  ) async {
    final result = await db.execute(
      Sql.named(
        'SELECT * FROM users WHERE username = @username AND tenant_id = @tenant_id',
      ),
      parameters: {'username': username, 'tenant_id': tenantId},
    );
    return result.isEmpty ? null : _rowToMapFull(result.first);
  }

  Future<Map<String, dynamic>> create({
    required String tenantId,
    required String username,
    required String password,
    required String role,
  }) async {
    final hash = BCrypt.hashpw(password, BCrypt.gensalt());
    final result = await db.execute(
      Sql.named(
        '''INSERT INTO users (tenant_id, username, password_hash, role)
           VALUES (@tenant_id, @username, @password_hash, @role)
           RETURNING id, tenant_id, username, role, is_active, created_at, updated_at''',
      ),
      parameters: {
        'tenant_id': tenantId,
        'username': username,
        'password_hash': hash,
        'role': role,
      },
    );
    return _rowToMap(result.first);
  }

  Future<Map<String, dynamic>?> update(
    String id, {
    String? username,
    String? password,
    String? role,
    bool? isActive,
  }) async {
    final sets = <String>[];
    final params = <String, dynamic>{'id': id};

    if (username != null) {
      sets.add('username = @username');
      params['username'] = username;
    }
    if (password != null) {
      sets.add('password_hash = @password_hash');
      params['password_hash'] = BCrypt.hashpw(password, BCrypt.gensalt());
    }
    if (role != null) {
      sets.add('role = @role');
      params['role'] = role;
    }
    if (isActive != null) {
      sets.add('is_active = @is_active');
      params['is_active'] = isActive;
    }

    if (sets.isEmpty) return findById(id);

    sets.add('updated_at = NOW()');

    final result = await db.execute(
      Sql.named(
        'UPDATE users SET ${sets.join(', ')} WHERE id = @id RETURNING id, tenant_id, username, role, is_active, created_at, updated_at',
      ),
      parameters: params,
    );
    return result.isEmpty ? null : _rowToMap(result.first);
  }

  Future<bool> delete(String id) async {
    final result = await db.execute(
      Sql.named('DELETE FROM users WHERE id = @id'),
      parameters: {'id': id},
    );
    return result.affectedRows > 0;
  }

  Future<bool> verifyPassword(String plaintext, String hash) async {
    return BCrypt.checkpw(plaintext, hash);
  }

  Future<void> updatePassword(String userId, String newPassword) async {
    final hash = BCrypt.hashpw(newPassword, BCrypt.gensalt());
    await db.execute(
      Sql.named('UPDATE users SET password_hash = @hash, updated_at = NOW() WHERE id = @id'),
      parameters: {'id': userId, 'hash': hash},
    );
  }

  Map<String, dynamic> _rowToMap(ResultRow row) {
    final schema = row.toColumnMap();
    return {
      'id': schema['id'].toString(),
      'tenant_id': schema['tenant_id'].toString(),
      'username': schema['username'],
      'role': schema['role'],
      'is_active': schema['is_active'],
      'created_at': schema['created_at']?.toString(),
      'updated_at': schema['updated_at']?.toString(),
    };
  }

  Map<String, dynamic> _rowToMapFull(ResultRow row) {
    final m = _rowToMap(row);
    final schema = row.toColumnMap();
    m['password_hash'] = schema['password_hash'];
    return m;
  }
}
