/// Puntos de corte y anchos de contenido, con nombre y en un solo sitio.
///
/// Las pantallas llegaron a declarar **catorce** cortes distintos a mano —360,
/// 420, 480, 520, 600, 620, 680, 700, 720, 760, 780, 900, 980, 1000, 1024—
/// repartidos por 37 ficheros, de los que solo uno tenía nombre. Ninguno estaba
/// mal por separado; el problema es que juntos no dibujan un sistema, así que
/// dos pantallas hermanas cambian de forma en anchos distintos y la aplicación
/// se siente descosida.
///
/// **Esto no migra los 37 ficheros.** Cada pantalla que se toque cambia su
/// número por la constante que le corresponda; hacerlo de golpe sería un diff
/// enorme sobre pantallas que hoy funcionan, a cambio de nada visible.
abstract final class Breakpoints {
  /// Bajo esto se apila todo: móvil en vertical.
  static const double compacto = 600;

  /// Caben dos columnas o una barra lateral estrecha: tablet, móvil apaisado.
  static const double medio = 900;

  /// Escritorio. El menú lateral del shell ya se despliega a 960.
  static const double ancho = 1200;

  /// Monitor grande, donde el problema deja de ser que falte sitio y pasa a ser
  /// que sobre.
  static const double extraAncho = 1600;

  /// Ancho máximo de una columna de lectura: texto corrido, formularios y la
  /// conversación del chat.
  ///
  /// Más allá de esto no se gana nada —la vista tiene que barrer de un extremo
  /// a otro para seguir un renglón— y por eso las páginas de este tipo se topan
  /// y se centran en vez de estirarse con la ventana.
  static const double anchoLectura = 900;
}
