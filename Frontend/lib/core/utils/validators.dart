/// Client-side validation mirroring the backend's zod schemas, so users see
/// problems inline instead of as a generic server error.
class Validators {
  Validators._();

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? minLength(String value, int min, String field) {
    if (value.trim().length < min) return '$field must be at least $min characters';
    return null;
  }

  static String? positiveInt(String value, String field, {int? max}) {
    final n = int.tryParse(value.trim());
    if (n == null || n <= 0) return 'Enter a whole number greater than 0';
    if (max != null && n > max) return '$field can be at most $max';
    return null;
  }
}
