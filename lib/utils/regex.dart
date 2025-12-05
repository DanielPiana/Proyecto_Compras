/// Expresión regular para validar formatos de correo electrónico
///
/// Valida que el email tenga el formato: usuario@dominio.extensión
final emailRegex = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  caseSensitive: false,
);