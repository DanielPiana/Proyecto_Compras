// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get totalMarked => 'Total marked:';

  @override
  String get totalPrice => 'Total price';

  @override
  String get changeLanguage => 'Change language';

  @override
  String get darkTheme => 'Dark theme';

  @override
  String get menuSettings => 'Settings menu';

  @override
  String get search => 'Search...';

  @override
  String get language => 'Language';

  @override
  String get products => 'Products';

  @override
  String get shoppingList => 'Shopping List';

  @override
  String get receipt => 'Receipts';

  @override
  String get recipes => 'Recipes';

  @override
  String get generateReceipt => 'Generate Receipt';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get editProduct => 'Edit product';

  @override
  String get createProduct => 'Create product';

  @override
  String get titleConfirmDialog => 'Confirm delete';

  @override
  String get deleteConfirmationSP =>
      'Are you sure you want to delete this product? \nThis product will only be removed from the shopping list.';

  @override
  String get deleteConfirmationP =>
      'Are you sure you want to delete this product?';

  @override
  String get deleteConfirmationR =>
      'Are you sure you want to delete this recepit? \nThe associated products will not be deleted.';

  @override
  String get name => 'Name';

  @override
  String get description => 'Description';

  @override
  String get price => 'Price';

  @override
  String get supermarket => 'Supermarket';

  @override
  String get selectSupermarket => 'Select Supermarket';

  @override
  String get selectSupermarketName => 'New Supermarket name';

  @override
  String get selectSupermarketNameDDB => 'New supermarket';

  @override
  String get snackBarRepeatedProduct =>
      'This product is already on the shopping list';

  @override
  String get snackBarAddedProduct => 'Product added to the shopping list';

  @override
  String get snackBarErrorAddingProduct =>
      'Error adding producto to the shopping list';

  @override
  String get snackBarAddedReceipt => 'Recepit created';

  @override
  String get snackBarReceiptQuantityError =>
      'There are no marked products to generate a receipt.';

  @override
  String get quantity => 'Quantity: ';
}
