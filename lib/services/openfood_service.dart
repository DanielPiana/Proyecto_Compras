import 'package:openfoodfacts/openfoodfacts.dart';

class OpenFoodService {
  static Future<Product?> obtenerProductoPorCodigo(String codigo) async {
    OpenFoodAPIConfiguration.userAgent = UserAgent(
      name: 'ProyectoCompras',
      version: '1.0.0',
      system: 'Flutter',
    );

    final config = ProductQueryConfiguration(
      codigo,
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