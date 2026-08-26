enum IdentityPatternId { email, username }

/// Patrones de identidad compartidos por los formularios de la aplicación.
///
/// Los patrones permanecen privados detrás de validadores semánticos; este
/// acceso tipado existe para evitar copias cuando otra capa necesite el mismo
/// contrato básico.
abstract final class IdentityValidationContract {
  static final Map<IdentityPatternId, RegExp> _patterns = {
    IdentityPatternId.email: RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$'),
    IdentityPatternId.username: RegExp(r'^[a-z0-9._-]{5,32}$'),
  };

  static RegExp get(IdentityPatternId id) => _patterns[id]!;
}
