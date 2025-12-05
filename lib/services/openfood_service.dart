import 'package:openfoodfacts/openfoodfacts.dart';

/// Servicio para consultar productos en la base de datos de Open Food Facts
class OpenFoodService {

  /// Obtiene la información de un producto a partir de su código de barras
  ///
  /// Flujo principal:
  /// - Configura el cliente de la API con el UserAgent
  /// - Consulta la API de Open Food Facts con el código proporcionado
  /// - Retorna el producto si se encuentra, o null si no existe
  static Future<Product?> getProductByBarcode(String code) async {
    OpenFoodAPIConfiguration.userAgent = UserAgent(
      name: 'ProyectoCompras',
      version: '1.0.0',
      system: 'Flutter',
    );

    final config = ProductQueryConfiguration(
      code,
      language: OpenFoodFactsLanguage.SPANISH,
      fields: [
        ProductField.ALL,
        ProductField.IMAGE_FRONT_URL,
      ],
      version: ProductQueryVersion.v3,
    );

    final ProductResultV3 response = await OpenFoodAPIClient.getProductV3(config);

    if (response.status == ProductResultV3.statusSuccess && response.product != null) {
      return response.product;
    }

    return null;
  }
}