// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get totalMarked => 'Total marcado:';

  @override
  String get totalPrice => 'Precio total';

  @override
  String get changeLanguage => 'Cambiar idioma';

  @override
  String get darkTheme => 'Tema oscuro';

  @override
  String get menuSettings => 'Menú de ajustes';

  @override
  String get search => 'Buscar...';

  @override
  String get language => 'Idioma';

  @override
  String get products => 'Productos';

  @override
  String get shoppingList => 'Compra';

  @override
  String get receipt => 'Gastos';

  @override
  String get recipes => 'Recetas';

  @override
  String get generateReceipt => 'Generar Factura';

  @override
  String get delete => 'Eliminar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get editProduct => 'Editar producto';

  @override
  String get createProduct => 'Crear producto';

  @override
  String get titleConfirmDialog => 'Confirmar eliminación';

  @override
  String get deleteConfirmationSP =>
      '¿Estás seguro de que deseas eliminar este producto? \nEste producto solo se borrará de la lista de la compra';

  @override
  String get deleteConfirmationP =>
      '¿Estás seguro de que deseas eliminar este producto?';

  @override
  String get deleteConfirmationR =>
      '¿Estás seguro de que deseas eliminar esta factura? \nLos productos asociados no se borrarán';

  @override
  String get name => 'Nombre';

  @override
  String get description => 'Descripción';

  @override
  String get price => 'Precio';

  @override
  String get supermarket => 'Supermercado';

  @override
  String get selectSupermarket => 'Seleccionar Supermercado';

  @override
  String get selectSupermarketName => 'Nombre del nuevo supermercado';

  @override
  String get selectSupermarketNameDDB => 'Nuevo supermercado';

  @override
  String get snackBarRepeatedProduct =>
      'Este producto ya está en la lista de compra';

  @override
  String get snackBarAddedProduct => 'Producto añadido a la lista de compra';

  @override
  String get snackBarErrorAddingProduct =>
      'Error al añadir producto a la lista de compra:';

  @override
  String get snackBarAddedReceipt => 'Factura generada';

  @override
  String get snackBarReceiptQuantityError =>
      'No hay productos marcados para generar una factura';

  @override
  String get quantity => 'Cantidad: ';
}
