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
