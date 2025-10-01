import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @totalMarked.
  ///
  /// In es, this message translates to:
  /// **'Total marcado:'**
  String get totalMarked;

  /// No description provided for @totalPrice.
  ///
  /// In es, this message translates to:
  /// **'Precio total'**
  String get totalPrice;

  /// No description provided for @changeLanguage.
  ///
  /// In es, this message translates to:
  /// **'Cambiar idioma'**
  String get changeLanguage;

  /// No description provided for @darkTheme.
  ///
  /// In es, this message translates to:
  /// **'Tema oscuro'**
  String get darkTheme;

  /// No description provided for @menuSettings.
  ///
  /// In es, this message translates to:
  /// **'Menú de ajustes'**
  String get menuSettings;

  /// No description provided for @search.
  ///
  /// In es, this message translates to:
  /// **'Buscar...'**
  String get search;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @products.
  ///
  /// In es, this message translates to:
  /// **'Productos'**
  String get products;

  /// No description provided for @shoppingList.
  ///
  /// In es, this message translates to:
  /// **'Compra'**
  String get shoppingList;

  /// No description provided for @receipt.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get receipt;

  /// No description provided for @recipes.
  ///
  /// In es, this message translates to:
  /// **'Recetas'**
  String get recipes;

  /// No description provided for @generateReceipt.
  ///
  /// In es, this message translates to:
  /// **'Generar Factura'**
  String get generateReceipt;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @editProduct.
  ///
  /// In es, this message translates to:
  /// **'Editar producto'**
  String get editProduct;

  /// No description provided for @createProduct.
  ///
  /// In es, this message translates to:
  /// **'Crear producto'**
  String get createProduct;

  /// No description provided for @titleConfirmDialog.
  ///
  /// In es, this message translates to:
  /// **'Confirmar eliminación'**
  String get titleConfirmDialog;

  /// No description provided for @deleteConfirmationSP.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que deseas eliminar este producto? \nEste producto solo se borrará de la lista de la compra'**
  String get deleteConfirmationSP;

  /// No description provided for @deleteConfirmationP.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que deseas eliminar este producto?'**
  String get deleteConfirmationP;

  /// No description provided for @deleteConfirmationR.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que deseas eliminar esta factura? \nLos productos asociados no se borrarán'**
  String get deleteConfirmationR;

  /// No description provided for @name.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get name;

  /// No description provided for @description.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get description;

  /// No description provided for @price.
  ///
  /// In es, this message translates to:
  /// **'Precio'**
  String get price;

  /// No description provided for @supermarket.
  ///
  /// In es, this message translates to:
  /// **'Supermercado'**
  String get supermarket;

  /// No description provided for @selectSupermarket.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar Supermercado'**
  String get selectSupermarket;

  /// No description provided for @selectSupermarketName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del nuevo supermercado'**
  String get selectSupermarketName;

  /// No description provided for @selectSupermarketNameDDB.
  ///
  /// In es, this message translates to:
  /// **'Nuevo supermercado'**
  String get selectSupermarketNameDDB;

  /// No description provided for @snackBarRepeatedProduct.
  ///
  /// In es, this message translates to:
  /// **'Este producto ya está en la lista de compra'**
  String get snackBarRepeatedProduct;

  /// No description provided for @snackBarAddedProduct.
  ///
  /// In es, this message translates to:
  /// **'Producto añadido a la lista de compra'**
  String get snackBarAddedProduct;

  /// No description provided for @snackBarErrorAddingProduct.
  ///
  /// In es, this message translates to:
  /// **'Error al añadir producto a la lista de compra:'**
  String get snackBarErrorAddingProduct;

  /// No description provided for @snackBarReceiptQuantityError.
  ///
  /// In es, this message translates to:
  /// **'No hay productos marcados para generar una factura'**
  String get snackBarReceiptQuantityError;

  /// No description provided for @quantity.
  ///
  /// In es, this message translates to:
  /// **'Cantidad: '**
  String get quantity;

  /// No description provided for @select_photo.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar foto'**
  String get select_photo;

  /// No description provided for @register_or_login.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Sesión o Registrarse'**
  String get register_or_login;

  /// No description provided for @login_register.
  ///
  /// In es, this message translates to:
  /// **'Entrar / Registrar'**
  String get login_register;

  /// No description provided for @new_recipe.
  ///
  /// In es, this message translates to:
  /// **'Nueva receta'**
  String get new_recipe;

  /// No description provided for @lessThan15.
  ///
  /// In es, this message translates to:
  /// **'Menos de 15 minutos'**
  String get lessThan15;

  /// No description provided for @lessThan30.
  ///
  /// In es, this message translates to:
  /// **'Menos de 30 minutos'**
  String get lessThan30;

  /// No description provided for @lessThan45.
  ///
  /// In es, this message translates to:
  /// **'Menos de 45 minutos'**
  String get lessThan45;

  /// No description provided for @lessThan1h.
  ///
  /// In es, this message translates to:
  /// **'Menos de 1 hora'**
  String get lessThan1h;

  /// No description provided for @lessThan1h30.
  ///
  /// In es, this message translates to:
  /// **'Menos de 1hora y 30 minutos'**
  String get lessThan1h30;

  /// No description provided for @lessThan2h.
  ///
  /// In es, this message translates to:
  /// **'Menos de 2 horas'**
  String get lessThan2h;

  /// No description provided for @moreThan2h.
  ///
  /// In es, this message translates to:
  /// **'Más de 2 horas'**
  String get moreThan2h;

  /// No description provided for @estimated_time.
  ///
  /// In es, this message translates to:
  /// **'Tiempo estimado'**
  String get estimated_time;

  /// No description provided for @share.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get share;

  /// No description provided for @time.
  ///
  /// In es, this message translates to:
  /// **'Tiempo'**
  String get time;

  /// No description provided for @select_products.
  ///
  /// In es, this message translates to:
  /// **'Selecciona productos'**
  String get select_products;

  /// No description provided for @no_description.
  ///
  /// In es, this message translates to:
  /// **'Sin descripción'**
  String get no_description;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// No description provided for @edit_name.
  ///
  /// In es, this message translates to:
  /// **'Editar nombre'**
  String get edit_name;

  /// No description provided for @new_name.
  ///
  /// In es, this message translates to:
  /// **'Nuevo nombre'**
  String get new_name;

  /// No description provided for @save_changes.
  ///
  /// In es, this message translates to:
  /// **'¿Guardar cambios?'**
  String get save_changes;

  /// No description provided for @changes_confirmation.
  ///
  /// In es, this message translates to:
  /// **'Tienes cambios sin guardar. ¿Qué deseas hacer?'**
  String get changes_confirmation;

  /// No description provided for @no_save_exit.
  ///
  /// In es, this message translates to:
  /// **'Salir sin guardar'**
  String get no_save_exit;

  /// No description provided for @save_exit.
  ///
  /// In es, this message translates to:
  /// **'Guardar y salir'**
  String get save_exit;

  /// No description provided for @first_time_step.
  ///
  /// In es, this message translates to:
  /// **'Para añadir tu primer paso haz click aquí'**
  String get first_time_step;

  /// No description provided for @link_products.
  ///
  /// In es, this message translates to:
  /// **'Vincular productos'**
  String get link_products;

  /// No description provided for @no_linked_products.
  ///
  /// In es, this message translates to:
  /// **'No hay productos asociados'**
  String get no_linked_products;

  /// No description provided for @change_photo.
  ///
  /// In es, this message translates to:
  /// **'Cambiar foto'**
  String get change_photo;

  /// No description provided for @edit_step.
  ///
  /// In es, this message translates to:
  /// **'Editar paso'**
  String get edit_step;

  /// No description provided for @fill_fields.
  ///
  /// In es, this message translates to:
  /// **'Por favor, completa todos los campos'**
  String get fill_fields;

  /// No description provided for @step_title.
  ///
  /// In es, this message translates to:
  /// **'Título del paso'**
  String get step_title;

  /// No description provided for @step_description.
  ///
  /// In es, this message translates to:
  /// **'Descripción del paso'**
  String get step_description;

  /// No description provided for @save_step.
  ///
  /// In es, this message translates to:
  /// **'Guardar paso'**
  String get save_step;

  /// No description provided for @step.
  ///
  /// In es, this message translates to:
  /// **'Paso'**
  String get step;

  /// No description provided for @title.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get title;

  /// No description provided for @add_step.
  ///
  /// In es, this message translates to:
  /// **'Añadir paso'**
  String get add_step;

  /// No description provided for @delete_step.
  ///
  /// In es, this message translates to:
  /// **'Eliminar paso'**
  String get delete_step;

  /// No description provided for @previous.
  ///
  /// In es, this message translates to:
  /// **'Anterior'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get next;

  /// No description provided for @finish.
  ///
  /// In es, this message translates to:
  /// **'Finalizar'**
  String get finish;

  /// No description provided for @product_deleted_ok.
  ///
  /// In es, this message translates to:
  /// **'Producto eliminado correctamente'**
  String get product_deleted_ok;

  /// No description provided for @product_deleted_error.
  ///
  /// In es, this message translates to:
  /// **'Error al eliminar producto'**
  String get product_deleted_error;

  /// No description provided for @success.
  ///
  /// In es, this message translates to:
  /// **'Éxito'**
  String get success;

  /// No description provided for @product_updated_ok.
  ///
  /// In es, this message translates to:
  /// **'Producto actualizado correctamente'**
  String get product_updated_ok;

  /// No description provided for @product_updated_error.
  ///
  /// In es, this message translates to:
  /// **'Error actualizando producto'**
  String get product_updated_error;

  /// No description provided for @product_created_ok.
  ///
  /// In es, this message translates to:
  /// **'Producto creado correctamente'**
  String get product_created_ok;

  /// No description provided for @product_created_error.
  ///
  /// In es, this message translates to:
  /// **'Error creando producto'**
  String get product_created_error;

  /// No description provided for @warning.
  ///
  /// In es, this message translates to:
  /// **'Aviso'**
  String get warning;

  /// No description provided for @name_error_message.
  ///
  /// In es, this message translates to:
  /// **'El nombre es obligatorio'**
  String get name_error_message;

  /// No description provided for @description_error_message.
  ///
  /// In es, this message translates to:
  /// **'La descripción es obligatoria'**
  String get description_error_message;

  /// No description provided for @price_error_message.
  ///
  /// In es, this message translates to:
  /// **'El precio debe ser un número válido'**
  String get price_error_message;

  /// No description provided for @supermarket_error_message.
  ///
  /// In es, this message translates to:
  /// **'Debes seleccionar un supermercado'**
  String get supermarket_error_message;

  /// No description provided for @receipt_deleted_ok.
  ///
  /// In es, this message translates to:
  /// **'Factura eliminada correctamente'**
  String get receipt_deleted_ok;

  /// No description provided for @receipt_deleted_error.
  ///
  /// In es, this message translates to:
  /// **'Error al eliminar factura'**
  String get receipt_deleted_error;

  /// No description provided for @receipt_created_ok.
  ///
  /// In es, this message translates to:
  /// **'Factura creada correctamente'**
  String get receipt_created_ok;

  /// No description provided for @receipt_created_error.
  ///
  /// In es, this message translates to:
  /// **'Error creando factura'**
  String get receipt_created_error;

  /// No description provided for @wrong_username_or_password.
  ///
  /// In es, this message translates to:
  /// **'Usuario o contraseña incorrectos'**
  String get wrong_username_or_password;

  /// No description provided for @mail.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get mail;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @recipe_deleted_ok.
  ///
  /// In es, this message translates to:
  /// **'Receta borrada correctamente'**
  String get recipe_deleted_ok;

  /// No description provided for @recipe_deleted_error.
  ///
  /// In es, this message translates to:
  /// **'Error borrando receta'**
  String get recipe_deleted_error;

  /// No description provided for @recipe_created_ok.
  ///
  /// In es, this message translates to:
  /// **'Receta creada correctamente'**
  String get recipe_created_ok;

  /// No description provided for @recipe_created_error.
  ///
  /// In es, this message translates to:
  /// **'Error creando receta'**
  String get recipe_created_error;

  /// No description provided for @time_error_message.
  ///
  /// In es, this message translates to:
  /// **'Tiempo es obligatorio'**
  String get time_error_message;

  /// No description provided for @products_linked_ok.
  ///
  /// In es, this message translates to:
  /// **'Productos vinculados correctamente'**
  String get products_linked_ok;

  /// No description provided for @products_linked_error.
  ///
  /// In es, this message translates to:
  /// **'Error al vincular productos'**
  String get products_linked_error;

  /// No description provided for @data_not_saved.
  ///
  /// In es, this message translates to:
  /// **'Los datos no se han guardado'**
  String get data_not_saved;

  /// No description provided for @data_saved_ok.
  ///
  /// In es, this message translates to:
  /// **'Los datos se han guardado correctamente'**
  String get data_saved_ok;

  /// No description provided for @recipe_updated_ok.
  ///
  /// In es, this message translates to:
  /// **'Receta actualizada correctamente'**
  String get recipe_updated_ok;

  /// No description provided for @recipe_updated_error.
  ///
  /// In es, this message translates to:
  /// **'Error actualizando receta'**
  String get recipe_updated_error;

  /// No description provided for @delete_step_confirmation.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de borrar este paso?'**
  String get delete_step_confirmation;

  /// No description provided for @login_try_ok.
  ///
  /// In es, this message translates to:
  /// **'Inicio de sesión correcto'**
  String get login_try_ok;

  /// No description provided for @login_try_error.
  ///
  /// In es, this message translates to:
  /// **'Contraseña incorrecta, prueba otra vez'**
  String get login_try_error;

  /// No description provided for @error.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @register_try_ok.
  ///
  /// In es, this message translates to:
  /// **'Cuenta creada correctamente'**
  String get register_try_ok;

  /// No description provided for @register_try_error.
  ///
  /// In es, this message translates to:
  /// **'Error al crear cuenta'**
  String get register_try_error;

  /// No description provided for @unknown_error.
  ///
  /// In es, this message translates to:
  /// **'Error desconocido'**
  String get unknown_error;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
