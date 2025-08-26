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

  /// No description provided for @snackBarAddedReceipt.
  ///
  /// In es, this message translates to:
  /// **'Factura generada'**
  String get snackBarAddedReceipt;

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
