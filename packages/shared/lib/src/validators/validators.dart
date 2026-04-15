class Validators {
  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'Username is required';
    if (value.length < 3) return 'Username must be at least 3 characters';
    if (value.length > 50) return 'Username must be at most 50 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    if (value.length > 128) return 'Password must be at most 128 characters';
    return null;
  }

  static String? tenantSlug(String? value) {
    if (value == null || value.trim().isEmpty) return 'Tenant slug is required';
    if (value.length < 2) return 'Slug must be at least 2 characters';
    if (value.length > 50) return 'Slug must be at most 50 characters';
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(value)) {
      return 'Slug can only contain lowercase letters, numbers, and hyphens';
    }
    return null;
  }

  static String? tenantName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Tenant name is required';
    if (value.length > 100) return 'Name must be at most 100 characters';
    return null;
  }

  static String? projectName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Project name is required';
    if (value.length > 100) return 'Name must be at most 100 characters';
    return null;
  }

  static String? barcodeValue(String? value) {
    if (value == null || value.trim().isEmpty) return 'Barcode value is required';
    if (value.length > 500) return 'Barcode value too long';
    return null;
  }
}
