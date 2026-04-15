import 'package:postgres/postgres.dart';

import '../db.dart';

abstract class BaseRepository {
  Connection get db => Database.instance.connection;

  /// Helper to build WHERE clause with tenant_id filter.
  String tenantFilter(String tenantId, {String alias = ''}) {
    final prefix = alias.isNotEmpty ? '$alias.' : '';
    return "${prefix}tenant_id = '$tenantId'";
  }
}
