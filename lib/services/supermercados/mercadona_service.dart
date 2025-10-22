import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

Future<void> actualizarProductosMercadona() async {
  const base = 'https://tienda.mercadona.es/api/categories/';
  final productos = <Map<String, dynamic>>[];

  Future<void> procesarCategoria(int id) async {
    final url = '$base$id';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        print('⚠️ Categoría $id no encontrada (${res.statusCode})');
        return;
      }

      final data = jsonDecode(res.body);

      // ✅ Si hay productos directamente
      if (data['products'] != null) {
        for (final p in data['products']) {
          productos.add({
            'id': p['id'],
            'nombre': p['display_name'],
            'codigo_barras': p['ean'],
            'precio': p['price_instructions']?['unit_price'],
            'imagen': p['thumbnail']
          });
        }
      }

      // ✅ Si tiene subcategorías
      if (data['categories'] != null) {
        for (final sub in data['categories']) {
          if (sub['products'] != null) {
            for (final p in sub['products']) {
              productos.add({
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
      print('❌ Error procesando categoría $id: $e');
    }
  }

  // 🔄 Recorrer categorías (puedes ajustar el rango)
  for (var id = 1; id <= 300; id++) {
    await procesarCategoria(id);
  }

  // 💾 Guardar JSON localmente
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/productos_mercadona.json');
  await file.writeAsString(jsonEncode(productos), flush: true);

  print('✅ Guardados ${productos.length} productos de Mercadona');
}

Future<void> actualizarCodigosDeBarras() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/productos_mercadona.json');

    if (!await file.exists()) {
      print('❌ No se encontró el archivo productos_mercadona.json');
      return;
    }

    // Leer el JSON existente
    final contenido = await file.readAsString();
    final List<dynamic> productos = jsonDecode(contenido);

    print('🔍 Actualizando códigos de barras para ${productos.length} productos...');

    int actualizados = 0;
    for (int i = 0; i < productos.length; i++) {
      final producto = productos[i];
      final id = producto['id'];

      try {
        final url = Uri.parse('https://tienda.mercadona.es/api/products/$id');
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final ean = data['ean'];

          if (ean != null && ean.toString().isNotEmpty) {
            producto['codigo_barras'] = ean;
            actualizados++;
          }
        } else {
          print('⚠️ Error ${response.statusCode} al obtener producto $id');
        }

        // Evita saturar la API
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        print('⚠️ Error con el producto $id: $e');
      }

      // Guarda cada cierto número de productos para no perder progreso
      if (i % 100 == 0 && i > 0) {
        await file.writeAsString(jsonEncode(productos), flush: true);
        print('💾 Progreso guardado ($i productos procesados)');
      }
    }

    // Guardar el resultado final
    await file.writeAsString(jsonEncode(productos), flush: true);

    print('✅ Códigos de barras actualizados ($actualizados productos con EAN)');
  } catch (e) {
    print('❌ Error general al actualizar códigos de barras: $e');
  }
}
