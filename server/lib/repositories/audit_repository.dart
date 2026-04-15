import 'package:postgres/postgres.dart';

import 'base_repository.dart';

class AuditRepository extends BaseRepository {
  Future<void> log({
    required String tenantId,
    required String userId,
    required String action,
    required String entityType,
    String? entityId,
    Map<String, dynamic> details = const {},
  }) async {
    await db.execute(
      Sql.named(
        '''INSERT INTO audit_log (tenant_id, user_id, action, entity_type, entity_id, details)
           VALUES (@tenant_id, @user_id, @action, @entity_type, @entity_id, @details::jsonb)''',
      ),
      parameters: {
        'tenant_id': tenantId,
        'user_id': userId,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'details': details.toString(),
      },
    );
  }
}
