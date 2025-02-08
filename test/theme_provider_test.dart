import 'package:flutter_test/flutter_test.dart';
import 'package:proyectocompras/Providers/themeProvider.dart';


void main() {
  test("El valor inicial debería ser modo claro", () {
    final themeProvider = ThemeProvider();
    expect(themeProvider.isDarkMode, false);
  });

  test("Cambiar a modo oscuro", () {
    final themeProvider = ThemeProvider();
    themeProvider.toggleTheme();
    expect(themeProvider.isDarkMode, true);
  });

  test("Cambiar de nuevo a modo claro", () {
    final themeProvider = ThemeProvider();
    themeProvider.toggleTheme(); // Cambia a oscuro
    themeProvider.toggleTheme(); // Cambia a claro
    expect(themeProvider.isDarkMode, false);
  });
}
