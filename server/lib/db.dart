import 'dart:io';

import 'package:postgres/postgres.dart';

class Database {
  Database._();

  static Database? _instance;
  static Database get instance => _instance ??= Database._();

  late Connection _connection;
  Connection get connection => _connection;

  Future<void> initialize() async {
    final url = Platform.environment['DATABASE_URL'] ??
        'postgres://scan_user:scan_pass@localhost:5432/scan_system';

    final uri = Uri.parse(url);
    final endpoint = Endpoint(
      host: uri.host,
      port: uri.port,
      database: uri.pathSegments.first,
      username: uri.userInfo.split(':').first,
      password: uri.userInfo.split(':').last,
    );

    _connection = await Connection.open(
      endpoint,
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    print('Database connected');
  }

  Future<void> runMigrations() async {
    // Create migrations tracking table
    await _connection.execute('''
      CREATE TABLE IF NOT EXISTS _migrations (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        applied_at TIMESTAMPTZ DEFAULT NOW()
      )
    ''');

    final migrations = <String, String>{
      '001_initial': _migration001,
      '002_rls_policies': _migration002,
      '003_seed_super_admin': _migration003,
      '004_project_is_open': _migration004,
      '005_epc_counters': _migration005,
      '006_scans_kind': _migration006,
    };

    for (final entry in migrations.entries) {
      final applied = await _connection.execute(
        Sql.named('SELECT 1 FROM _migrations WHERE name = @name'),
        parameters: {'name': entry.key},
      );

      if (applied.isEmpty) {
        // Split multi-statement migrations and execute each separately
        final statements = entry.value
            .split(';')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s != '--')
            .toList();
        for (final stmt in statements) {
          if (stmt.startsWith('--')) continue;
          await _connection.execute('$stmt;');
        }
        await _connection.execute(
          Sql.named('INSERT INTO _migrations (name) VALUES (@name)'),
          parameters: {'name': entry.key},
        );
        print('Applied migration: ${entry.key}');
      }
    }
  }

  Future<void> close() async {
    await _connection.close();
  }
}

const _migration001 = '''
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE tenants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  settings JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('super_admin', 'tenant_admin', 'operator')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(tenant_id, username)
);

CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  is_open BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE scans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  barcode_value TEXT NOT NULL,
  barcode_format TEXT,
  scanned_at TIMESTAMPTZ NOT NULL,
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  details JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_projects_tenant ON projects(tenant_id);
CREATE INDEX idx_scans_tenant ON scans(tenant_id);
CREATE INDEX idx_scans_project ON scans(project_id);
CREATE INDEX idx_scans_user ON scans(user_id);
CREATE INDEX idx_scans_scanned_at ON scans(scanned_at);
CREATE INDEX idx_audit_tenant ON audit_log(tenant_id);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
''';

const _migration002 = '''
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
''';

const _migration003 = '''
-- Seed is handled by application startup, not migration
-- This is a placeholder for the super admin tenant and user
SELECT 1;
''';

const _migration004 = '''
ALTER TABLE projects
ADD COLUMN IF NOT EXISTS is_open BOOLEAN NOT NULL DEFAULT true;
''';

/// EPC serial counter per (tenant, gtin14). Used by the web Barcode → EPC
/// importer to assign cumulative serial numbers across uploads, so each
/// physical item gets a unique SGTIN-96 EPC and total counts can be tracked.
const _migration005 = '''
CREATE TABLE IF NOT EXISTS epc_counters (
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  gtin14 TEXT NOT NULL,
  last_serial BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (tenant_id, gtin14)
);

CREATE INDEX IF NOT EXISTS idx_epc_counters_tenant ON epc_counters(tenant_id);
''';

/// Classifies each scan by source so the task UI can split scans into three
/// tabs (manual barcode scan vs. web Excel→EPC import vs. C5 EPC reader)
/// instead of mixing them in one table.
///
/// Allowed values:
/// - 'barcode_scan' — mobile camera scan or manual entry of a printed barcode.
/// - 'epc_import'   — web upload of a packing list / Excel that gets
///                    converted to SGTIN-96 EPCs.
/// - 'epc_read'     — UHF RFID tags read by the C5 hand reader (the EPC is
///                    the truth, the barcode column is its decoded GTIN).
///
/// Existing rows are backfilled from `barcode_format` and `metadata`:
/// - `metadata->>'import_kind' = 'web_barcode_to_sgtin96_epc'` → `epc_import`.
/// - `barcode_format` ∈ {'EPC', 'EPC->BARCODE', 'SGTIN-96'} → `epc_read`
///   when not flagged as an import (the import sets SGTIN-96 with the
///   `import_kind` flag so the previous rule wins for those rows).
/// - everything else → `barcode_scan`.
const _migration006 = '''
ALTER TABLE scans
ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'barcode_scan';

UPDATE scans
SET kind = CASE
  WHEN metadata->>'import_kind' = 'web_barcode_to_sgtin96_epc' THEN 'epc_import'
  WHEN barcode_format IN ('EPC', 'EPC->BARCODE') THEN 'epc_read'
  WHEN barcode_format = 'SGTIN-96' AND (metadata ? 'import_kind') = false THEN 'epc_read'
  ELSE 'barcode_scan'
END
WHERE kind = 'barcode_scan';

ALTER TABLE scans
DROP CONSTRAINT IF EXISTS scans_kind_check;

ALTER TABLE scans
ADD CONSTRAINT scans_kind_check
CHECK (kind IN ('barcode_scan', 'epc_import', 'epc_read'));

CREATE INDEX IF NOT EXISTS idx_scans_kind ON scans(tenant_id, project_id, kind);
''';
