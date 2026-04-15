import 'dart:convert';
import 'package:crypto/crypto.dart' show sha256;
import 'package:postgres/postgres.dart';

import 'base_repository.dart';

class RefreshTokenRepository extends BaseRepository {
  String _hash(String token) => sha256.convert(utf8.encode(token)).toString();

  Future<void> store({
    required String userId,
    required String token,
    required DateTime expiresAt,
  }) async {
    await db.execute(
      Sql.named(
        '''INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
           VALUES (@user_id, @token_hash, @expires_at)''',
      ),
      parameters: {
        'user_id': userId,
        'token_hash': _hash(token),
        'expires_at': expiresAt,
      },
    );
  }

  Future<bool> validate(String token) async {
    final result = await db.execute(
      Sql.named(
        'SELECT 1 FROM refresh_tokens WHERE token_hash = @hash AND expires_at > NOW()',
      ),
      parameters: {'hash': _hash(token)},
    );
    return result.isNotEmpty;
  }

  Future<void> revoke(String token) async {
    await db.execute(
      Sql.named('DELETE FROM refresh_tokens WHERE token_hash = @hash'),
      parameters: {'hash': _hash(token)},
    );
  }

  Future<void> revokeAllForUser(String userId) async {
    await db.execute(
      Sql.named('DELETE FROM refresh_tokens WHERE user_id = @user_id'),
      parameters: {'user_id': userId},
    );
  }

  Future<void> cleanExpired() async {
    await db.execute('DELETE FROM refresh_tokens WHERE expires_at <= NOW()');
  }
}
