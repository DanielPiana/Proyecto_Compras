import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyectocompras/Providers/languageProvider.dart';


void main() {
  test("El valor deberia ser español", () {
    final languageProvider = LanguageProvider(); // CREAMOS EL OBJETO/VARIABLE QUE VAMOS A PROBAR
    expect(languageProvider.locale, const Locale("es")); // Y PONEMOS EL VALOR QUE ESPERAMOS COMO RESULTADO CORRECTO
  });

  test('Cambiar idioma a inglés', () {
    final languageProvider = LanguageProvider();
    languageProvider.setLocale(const Locale('en'));
    expect(languageProvider.locale, const Locale('en'));
  });
}