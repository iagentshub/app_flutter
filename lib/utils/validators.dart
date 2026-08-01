class Validators {
  static String? requiredField(
    String? value, {
    String message = 'Campo obligatorio',
  }) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'El email es obligatorio';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) return 'Email no valido';
    return null;
  }

  static String? username(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return 'El usuario es obligatorio';
    if (!RegExp(r'^[a-z0-9._-]{5,32}$').hasMatch(normalized) ||
        normalized == 'guest' ||
        normalized.startsWith('guest_')) {
      return 'Usa entre 5 y 32 caracteres: a-z, 0-9, punto, guion o guion bajo';
    }
    return null;
  }

  static String? backendUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La URL del backend es obligatoria';
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !(uri.hasScheme && uri.host.isNotEmpty)) {
      return 'URL invalida';
    }
    return null;
  }
}
