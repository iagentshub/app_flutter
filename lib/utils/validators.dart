import '../core/config/identity_validation_contract.dart';
import 'i18n.dart';

class Validators {
  static String? requiredField(
    String? value, {
    String message = 'Campo obligatorio',
  }) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return tr('auth.email_required');
    if (!isValidEmail(value)) return tr('auth.email_invalid');
    return null;
  }

  static bool isValidEmail(String value) =>
      IdentityValidationContract.get(IdentityPatternId.email).hasMatch(value.trim());

  static String? username(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return tr('auth.username_required');
    if (!isValidUsername(normalized)) {
      return 'Usa entre 5 y 32 caracteres: a-z, 0-9, punto, guion o guion bajo';
    }
    return null;
  }

  static bool isValidUsername(String value) {
    final normalized = value.trim().toLowerCase();
    return IdentityValidationContract.get(IdentityPatternId.username)
            .hasMatch(normalized) &&
        normalized != 'guest' &&
        !normalized.startsWith('guest_');
  }

  static String? backendUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return tr('auth.backend_url_required');
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !(uri.hasScheme && uri.host.isNotEmpty)) {
      return 'URL invalida';
    }
    return null;
  }
}
