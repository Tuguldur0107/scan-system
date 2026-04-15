class AppConstants {
  static const appName = 'Scan System';
  static const duplicateCooldownMs = 1200;
  static const apiTimeout = Duration(seconds: 30);
  static const maxBatchSize = 500;
  static const accessTokenDuration = Duration(minutes: 15);
  static const refreshTokenDuration = Duration(days: 30);
  static const jwtIssuer = 'scan_system';
}

class Roles {
  static const superAdmin = 'super_admin';
  static const tenantAdmin = 'tenant_admin';
  static const operator = 'operator';

  static const all = [superAdmin, tenantAdmin, operator];

  static bool isValid(String role) => all.contains(role);

  /// Returns true if [role] has at least as much privilege as [required].
  static bool hasPermission(String role, String required) {
    final roleIndex = all.indexOf(role);
    final requiredIndex = all.indexOf(required);
    if (roleIndex < 0 || requiredIndex < 0) return false;
    return roleIndex <= requiredIndex;
  }
}
