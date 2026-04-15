import 'package:postgres/postgres.dart';

import 'base_repository.dart';

class ScanRepository extends BaseRepository {
  Future<Map<String, dynamic>> create({
    required String tenantId,
    required String projectId,
    required String userId,
    required String barcodeValue,
    String? barcodeFormat,
    required DateTime scannedAt,
    String? notes,
    Map<String, dynamic> metadata = const {},
  }) async {
    final result = await db.execute(
      Sql.named(
        '''INSERT INTO scans (tenant_id, project_id, user_id, barcode_value, barcode_format, scanned_at, notes, metadata)
           VALUES (@tenant_id, @project_id, @user_id, @barcode_value, @barcode_format, @scanned_at, @notes, @metadata::jsonb)
           RETURNING *''',
      ),
      parameters: {
        'tenant_id': tenantId,
        'project_id': projectId,
        'user_id': userId,
        'barcode_value': barcodeValue,
        'barcode_format': barcodeFormat,
        'scanned_at': scannedAt,
        'notes': notes,
        'metadata': metadata.toString(),
      },
    );
    return _rowToMap(result.first);
  }

  Future<List<Map<String, dynamic>>> createBatch({
    required String tenantId,
    required String userId,
    required List<Map<String, dynamic>> scans,
  }) async {
    final results = <Map<String, dynamic>>[];
    for (final scan in scans) {
      final r = await create(
        tenantId: tenantId,
        projectId: scan['project_id'] as String,
        userId: userId,
        barcodeValue: scan['barcode_value'] as String,
        barcodeFormat: scan['barcode_format'] as String?,
        scannedAt: DateTime.parse(scan['scanned_at'] as String),
        notes: scan['notes'] as String?,
        metadata: scan['metadata'] as Map<String, dynamic>? ?? {},
      );
      results.add(r);
    }
    return results;
  }

  Future<({List<Map<String, dynamic>> data, int total})> findByTenant(
    String tenantId, {
    int page = 1,
    int perPage = 50,
    String? projectId,
    String? userId,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    final where = <String>['s.tenant_id = @tenant_id'];
    final params = <String, dynamic>{'tenant_id': tenantId};

    if (projectId != null) {
      where.add('s.project_id = @project_id');
      params['project_id'] = projectId;
    }
    if (userId != null) {
      where.add('s.user_id = @user_id');
      params['user_id'] = userId;
    }
    if (search != null && search.isNotEmpty) {
      where.add('s.barcode_value ILIKE @search');
      params['search'] = '%$search%';
    }
    if (from != null) {
      where.add('s.scanned_at >= @from');
      params['from'] = from;
    }
    if (to != null) {
      where.add('s.scanned_at <= @to');
      params['to'] = to;
    }

    final whereClause = where.join(' AND ');

    // Count
    final countResult = await db.execute(
      Sql.named('SELECT COUNT(*) as count FROM scans s WHERE $whereClause'),
      parameters: params,
    );
    final total = countResult.first.toColumnMap()['count'] as int;

    // Data
    final offset = (page - 1) * perPage;
    params['limit'] = perPage;
    params['offset'] = offset;

    final dataResult = await db.execute(
      Sql.named(
        '''SELECT s.*, u.username, p.name as project_name
           FROM scans s
           LEFT JOIN users u ON s.user_id = u.id
           LEFT JOIN projects p ON s.project_id = p.id
           WHERE $whereClause
           ORDER BY s.scanned_at DESC LIMIT @limit OFFSET @offset''',
      ),
      parameters: params,
    );

    return (data: dataResult.map(_rowToMapWithJoins).toList(), total: total);
  }

  Future<bool> delete(String id, String tenantId) async {
    final result = await db.execute(
      Sql.named('DELETE FROM scans WHERE id = @id AND tenant_id = @tenant_id'),
      parameters: {'id': id, 'tenant_id': tenantId},
    );
    return result.affectedRows > 0;
  }

  Future<List<Map<String, dynamic>>> exportCsv(
    String tenantId, {
    String? projectId,
    DateTime? from,
    DateTime? to,
  }) async {
    final where = <String>['s.tenant_id = @tenant_id'];
    final params = <String, dynamic>{'tenant_id': tenantId};

    if (projectId != null) {
      where.add('s.project_id = @project_id');
      params['project_id'] = projectId;
    }
    if (from != null) {
      where.add('s.scanned_at >= @from');
      params['from'] = from;
    }
    if (to != null) {
      where.add('s.scanned_at <= @to');
      params['to'] = to;
    }

    final whereClause = where.join(' AND ');

    final result = await db.execute(
      Sql.named(
        '''SELECT s.barcode_value, s.barcode_format, s.scanned_at, s.notes,
                  u.username, p.name as project_name
           FROM scans s
           JOIN users u ON s.user_id = u.id
           JOIN projects p ON s.project_id = p.id
           WHERE $whereClause
           ORDER BY s.scanned_at DESC''',
      ),
      parameters: params,
    );

    return result.map((row) {
      final m = row.toColumnMap();
      return {
        'barcode_value': m['barcode_value'],
        'barcode_format': m['barcode_format'],
        'scanned_at': m['scanned_at']?.toString(),
        'notes': m['notes'],
        'username': m['username'],
        'project_name': m['project_name'],
      };
    }).toList();
  }

  // Dashboard queries
  Future<Map<String, dynamic>> getSummary(String tenantId) async {
    final result = await db.execute(
      Sql.named('''
        SELECT
          COUNT(*) as total_scans,
          COUNT(DISTINCT user_id) as active_users,
          COUNT(DISTINCT project_id) as active_projects,
          MIN(scanned_at) as first_scan,
          MAX(scanned_at) as last_scan
        FROM scans WHERE tenant_id = @tenant_id
      '''),
      parameters: {'tenant_id': tenantId},
    );

    final row = result.first.toColumnMap();
    return {
      'total_scans': row['total_scans'],
      'active_users': row['active_users'],
      'active_projects': row['active_projects'],
      'first_scan': row['first_scan']?.toString(),
      'last_scan': row['last_scan']?.toString(),
    };
  }

  Future<List<Map<String, dynamic>>> getByUser(String tenantId) async {
    final result = await db.execute(
      Sql.named('''
        SELECT u.username, COUNT(*) as scan_count
        FROM scans s JOIN users u ON s.user_id = u.id
        WHERE s.tenant_id = @tenant_id
        GROUP BY u.username
        ORDER BY scan_count DESC
      '''),
      parameters: {'tenant_id': tenantId},
    );

    return result.map((row) {
      final m = row.toColumnMap();
      return {'username': m['username'], 'scan_count': m['scan_count']};
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getByProject(String tenantId) async {
    final result = await db.execute(
      Sql.named('''
        SELECT p.name as project_name, COUNT(*) as scan_count
        FROM scans s JOIN projects p ON s.project_id = p.id
        WHERE s.tenant_id = @tenant_id
        GROUP BY p.name
        ORDER BY scan_count DESC
      '''),
      parameters: {'tenant_id': tenantId},
    );

    return result.map((row) {
      final m = row.toColumnMap();
      return {'project_name': m['project_name'], 'scan_count': m['scan_count']};
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getTimeline(
    String tenantId, {
    int days = 30,
  }) async {
    final result = await db.execute(
      Sql.named('''
        SELECT DATE(scanned_at) as date, COUNT(*) as scan_count
        FROM scans
        WHERE tenant_id = @tenant_id
          AND scanned_at >= NOW() - INTERVAL '1 day' * @days
        GROUP BY DATE(scanned_at)
        ORDER BY date
      '''),
      parameters: {'tenant_id': tenantId, 'days': days},
    );

    return result.map((row) {
      final m = row.toColumnMap();
      return {'date': m['date']?.toString(), 'scan_count': m['scan_count']};
    }).toList();
  }

  Map<String, dynamic> _rowToMap(ResultRow row) {
    final schema = row.toColumnMap();
    return {
      'id': schema['id'].toString(),
      'tenant_id': schema['tenant_id'].toString(),
      'project_id': schema['project_id'].toString(),
      'user_id': schema['user_id'].toString(),
      'barcode_value': schema['barcode_value'],
      'barcode_format': schema['barcode_format'],
      'scanned_at': schema['scanned_at']?.toString(),
      'synced_at': schema['synced_at']?.toString(),
      'notes': schema['notes'],
      'metadata': schema['metadata'] ?? {},
      'created_at': schema['created_at']?.toString(),
    };
  }

  Map<String, dynamic> _rowToMapWithJoins(ResultRow row) {
    final m = _rowToMap(row);
    final schema = row.toColumnMap();
    m['username'] = schema['username'];
    m['project_name'] = schema['project_name'];
    return m;
  }
}
