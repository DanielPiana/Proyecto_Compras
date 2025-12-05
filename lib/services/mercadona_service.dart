import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Descarga y guarda todos los productos de Mercadona desde su API
///
/// Flujo principal:
/// - Recorre las categorías del catálogo de Mercadona (1-300)
/// - Extrae productos directos y de subcategorías
/// - Guarda la información en un archivo JSON local
Future<void> updateMercadonaProducts() async {
  const base = 'https://tienda.mercadona.es/api/categories/';
  final products = <Map<String, dynamic>>[];

  /// Procesa una categoría específica y extrae sus productos
  Future<void> processCategory(int id) async {
    final url = '$base$id';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        print('Categoría $id no encontrada (${res.statusCode})');
        return;
      }

      final data = jsonDecode(res.body);

      // Si hay productos directamente
      if (data['products'] != null) {
        for (final p in data['products']) {
          products.add({
            'id': p['id'],
            'nombre': p['display_name'],
            'codigo_barras': p['ean'],
            'precio': p['price_instructions']?['unit_price'],
            'imagen': p['thumbnail']
          });
        }
      }

      // Si tiene subcategorías
      if (data['categories'] != null) {
        for (final sub in data['categories']) {
          if (sub['products'] != null) {
            for (final p in sub['products']) {
              products.add({
                'id': p['id'],
                'nombre': p['display_name'],
                'codigo_barras': p['ean'],
                'precio': p['price_instructions']?['unit_price'],
                'imagen': p['thumbnail']
              });
            }
          }
        }
      }

    } catch (e) {
      print('Error procesando categoría $id: $e');
    }
  }

  // Recorrer categorías (puedes ajustar el rango)
  for (var id = 1; id <= 300; id++) {
    await processCategory(id);
  }

  // Guardar JSON localmente
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/productos_mercadona.json');
  await file.writeAsString(jsonEncode(products), flush: true);

  print('Guardados ${products.length} productos de Mercadona');
}

/// Actualiza los códigos de barras (EAN) consultando la API de Mercadona
///
/// Flujo principal:
/// - Lee el archivo JSON local de productos
/// - Consulta la API de cada producto para obtener su EAN
/// - Actualiza el código de barras en el JSON
/// - Guarda el progreso cada 100 productos
Future<void> updateBarCodes() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/productos_mercadona.json');

    if (!await file.exists()) {
      print('No se encontró el archivo productos_mercadona.json');
      return;
    }

    // Leer el JSON existente
    final content = await file.readAsString();
    final List<dynamic> products = jsonDecode(content);

    print('Actualizando códigos de barras para ${products.length} productos...');

    int updated = 0;
    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      final id = product['id'];

      try {
        final url = Uri.parse('https://tienda.mercadona.es/api/products/$id');
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final ean = data['ean'];

          if (ean != null && ean.toString().isNotEmpty) {
            product['codigo_barras'] = ean;
            updated++;
          }
        } else {
          print('Error ${response.statusCode} al obtener producto $id');
        }

        // Evita saturar la API
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        print('Error con el producto $id: $e');
      }

      // Guarda cada cierto número de productos para no perder progreso
      if (i % 100 == 0 && i > 0) {
        await file.writeAsString(jsonEncode(products), flush: true);
        print('Progreso guardado ($i productos procesados)');
      }
    }

    // Guardar el resultado final
    await file.writeAsString(jsonEncode(products), flush: true);

    print('Códigos de barras actualizados ($updated productos con EAN)');
  } catch (e) {
    print('Error general al actualizar códigos de barras: $e');
  }
}