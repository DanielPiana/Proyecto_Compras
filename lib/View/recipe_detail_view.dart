import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:provider/provider.dart';
import 'package:food_manager/Providers/recipe_detail_provider.dart';
import 'package:food_manager/utils/capitalize.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/shopping_list_provider.dart';
import '../Providers/recipe_steps_provider.dart';
import '../Providers/products_provider.dart';
import '../Providers/products_recipe_provider.dart';
import '../Providers/recipe_provider.dart';
import '../Providers/user_provider.dart';
import '../Widgets/awesome_snackbar.dart';
import '../Widgets/custom_stepper.dart';
import '../l10n/app_localizations.dart';
import '../models/step_recipe_model.dart';
import '../models/recipe_model.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;

import '../utils/image_picker.dart';

class RecipeDetailView extends StatefulWidget {
  final RecipeModel recipe;

  const RecipeDetailView({super.key, required this.recipe});

  @override
  State<RecipeDetailView> createState() => _RecipeDetailViewState();
}

class _RecipeDetailViewState extends State<RecipeDetailView> {
  File? newPhotoFile;

  late RecipeModel recipe;

  String newName = "";
  String newStepTitle = "";
  String newStepDescription = "";
  String newPhotoUrl = "";
  int stepToUpdate = -1;
  bool changes = false;

  bool editingName = false;
  final nameController = TextEditingController();
  final _focusNode = FocusNode();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  List<RecipeStep> steps = [];
  bool isLoadingSteps = true;

  @override
  void initState() {
    super.initState();
    recipe = widget.recipe;
    nameController.text = recipe.name;
  }

  /// METODO PARA OBTENER UNA LISTA DE LOS PRODUCTOS
  Future<List<Map<String, dynamic>>> getProducts() async {
    final res = await Supabase.instance.client.from('productos').select();
    return List<Map<String, dynamic>>.from(res);
  }

  /// Guarda los productos seleccionados para una receta en la base de datos.
  ///
  /// Flujo principal:
  /// - Busca qué productos tiene actualmente guardados la receta en la tabla `receta_producto`.
  /// - Compara esos productos con los que el usuario ha seleccionado ahora.
  /// - Calcula:
  ///   - [insertar]: los productos nuevos que hay que añadir.
  ///   - [borrar]: los productos que ya no están seleccionados y hay que quitar.
  /// - Añade a la base de datos los productos nuevos.
  /// - Elimina los productos que ya no pertenecen a la receta.
  Future<void> saveRecipeProducts(int recipeId, Set<int> newSelected) async {
    final res = await Supabase.instance.client
        .from('receta_producto')
        .select('idproducto')
        .eq('idreceta', recipeId);

    final current = Set<int>.from(res.map((r) => r['idproducto'] as int));

    final add = newSelected.difference(current);
    final delete = current.difference(newSelected);

    for (final id in add) {
      await Supabase.instance.client.from('receta_producto').insert({
        'idreceta': recipeId,
        'idproducto': id,
      });
    }

    for (final id in delete) {
      await Supabase.instance.client
          .from('receta_producto')
          .delete()
          .eq('idreceta', recipeId)
          .eq('idproducto', id);
    }
  }

  /// Muestra un cuadro de diálogo para seleccionar productos y guardarlos en una receta.
  ///
  /// Flujo principal:
  /// - Obtiene la lista de productos disponibles desde el ProductoProvider.
  /// - Obtiene los productos ya asociados a la receta desde el ProductosRecetaProvider.
  /// - Crea un cuadro de diálogo con una lista de productos y casillas de verificación.
  /// - El usuario puede marcar o desmarcar productos para añadir o quitar.
  /// - Al pulsar Guardar:
  ///   - Se sincroniza la selección con la base de datos llamando a syncProductos.
  ///   - Si todo va bien, muestra un mensaje de éxito.
  ///   - Si ocurre un error, muestra un mensaje de error.
  /// - Al pulsar Cancelar, simplemente cierra el diálogo sin guardar cambios.
  void showProductsDialog(BuildContext context) async {
    final productProvider = context.read<ProductProvider>();
    final recipeProvider = context.read<ProductsRecipeProvider>();
    final availableProducts = productProvider.products;

    final Set<int> selected = recipeProvider.products.map((p) => p.id!).toSet();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.select_products),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableProducts.length,
                itemBuilder: (_, index) {
                  final product = availableProducts[index];
                  return CheckboxListTile(
                    value: selected.contains(product.id),
                    title: Text(product.name),
                    onChanged: (bool? checked) {
                      setStateDialog(() {
                        if (checked == true) {
                          selected.add(product.id!);
                        } else {
                          selected.remove(product.id!);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(AppLocalizations.of(context)!.cancel),
                        ),
                        ElevatedButton(
                          child: Text(AppLocalizations.of(context)!.save),
                          onPressed: () async {
                            try {
                              await recipeProvider.syncProducts(
                                  context, selected);

                              Navigator.pop(context);
                              showAwesomeSnackBar(
                                context,
                                title: AppLocalizations.of(context)!.success,
                                message: AppLocalizations.of(context)!
                                    .products_linked_ok,
                                contentType: asc.ContentType.success,
                              );
                            } catch (e) {
                              Navigator.pop(context);
                              showAwesomeSnackBar(
                                context,
                                title: AppLocalizations.of(context)!.error,
                                message: AppLocalizations.of(context)!
                                    .products_linked_error,
                                contentType: asc.ContentType.failure,
                              );
                            }
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: ElevatedButton.icon(
                  label: Text(
                      AppLocalizations.of(context)!.add_ingredients_to_list),
                  onPressed: () async {
                    final shoppingListProvider =
                        context.read<ShoppingListProvider>();
                    final productsProvider = context.read<ProductProvider>();

                    final markedProducts = productsProvider.products
                        .where((p) => selected.contains(p.id))
                        .toList();

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      int addedProducts = 0;

                      for (var product in markedProducts) {
                        final exists = shoppingListProvider.shoppingList
                            .any((c) => c.productId == product.id);

                        if (!exists) {
                          await shoppingListProvider.addToShoppingList(
                            product.id!,
                            product.price,
                            product.name,
                            product.supermarket,
                          );
                          addedProducts++;
                        }
                      }

                      Navigator.pop(context);

                      Navigator.pop(context);

                      showAwesomeSnackBar(
                        context,
                        title: AppLocalizations.of(context)!.success,
                        message: addedProducts > 0
                            ? AppLocalizations.of(context)!
                                .products_added_to_list
                            : AppLocalizations.of(context)!
                                .products_already_in_list,
                        contentType: asc.ContentType.success,
                      );
                    } catch (e) {
                      Navigator.pop(context);

                      Navigator.pop(context);

                      showAwesomeSnackBar(
                        context,
                        title: AppLocalizations.of(context)!.error,
                        message: AppLocalizations.of(context)!
                            .snackBarErrorAddingProduct,
                        contentType: asc.ContentType.failure,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Muestra una ventana con los detalles de un producto.
  void showProductDetail(BuildContext context, Map<String, dynamic> product) {
    final String? photo = product['foto'];
    final String? description = product['descripcion'];
    final bool hasDescription =
        description != null && description.trim().isNotEmpty;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // FOTO
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: (photo != null && photo.isNotEmpty)
                          ? Image.network(
                              photo,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // NOMBRE
                  Text(
                    product['nombre'] ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  // DESCRIPCIÓN SOLO SI EXISTE
                  if (hasDescription)
                    Text(
                      description!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),

                  if (hasDescription) const SizedBox(height: 12),

                  // SUPERMERCADO
                  Text(
                    '${AppLocalizations.of(context)!.supermarket}: ${product['supermercado'] ?? '-'}',
                    style: const TextStyle(
                        fontSize: 16, fontStyle: FontStyle.italic),
                  ),

                  const SizedBox(height: 24),

                  // CERRAR
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.close),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

// Imagen por defecto reutilizable
  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 60, color: Colors.white70),
      ),
    );
  }

  /// Abre la galería para seleccionar una nueva foto y la guarda temporalmente.
  ///
  /// Flujo principal:
  /// - Te da a elegir entre abrir la galería de fotos del dispositivo o usar la camara en movil o copiar desde el portapapeles en pc
  /// - Si el usuario no selecciona nada, no hace nada más.
  /// - Si selecciona una imagen, la guarda en nuevaFotoFile.
  /// - Marca en el DetalleRecetaProvider que la foto ha sido cambiada.
  Future<void> showEditPhotoDialog(BuildContext context, RecipeModel recipe) async {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Center(child: Text(AppLocalizations.of(context)!.change_photo)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BOTÓN GALERÍA
            InkWell(
              onTap: () async {
                Navigator.pop(dialogContext);

                final file = await ImagePickerHelper.imageFromGallery();
                if (file != null) {
                  await _uploadAndUpdatePhoto(context, recipe, file);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color:Theme.of(context).colorScheme.primary, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.photo_library, size: 40, color:Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.select_photo,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // BOTÓN CÁMARA/PORTAPAPELES
            InkWell(
              onTap: () async {
                Navigator.pop(dialogContext);

                final file = await ImagePickerHelper.imageFromClipboard();
                if (file != null) {
                  await _uploadAndUpdatePhoto(context, recipe, file);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.camera_alt, size: 40, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMobile
                                ? AppLocalizations.of(context)!.open_camera
                                : AppLocalizations.of(context)!.paste_image_from_clipboard,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAndUpdatePhoto(BuildContext context, RecipeModel recipe, File imageFile,) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userUuid = context.read<UserProvider>().uuid!;

      final bytes = await imageFile.readAsBytes();
      final fileName = '${recipe.name}_${Random().nextInt(9999).toString().padLeft(4, '0')}';
      final path = 'recetas/$userUuid/$fileName.jpg';

      await Supabase.instance.client.storage
          .from('fotos')
          .uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      final imageUrl = Supabase.instance.client.storage
          .from('fotos')
          .getPublicUrl(path);

      final updatedRecipe = RecipeModel(
        id: recipe.id,
        name: recipe.name,
        description: recipe.description,
        time: recipe.time,
        photo: imageUrl,
        userUuid: recipe.userUuid,
        shareCode: recipe.shareCode,
        importedCode: recipe.importedCode,
      );

      await context.read<RecipeProvider>().updateRecipe(updatedRecipe);

      // ACTUALIZAR LA VARIABLE LOCAL DEL STATE
      setState(() {
        this.recipe = updatedRecipe;
      });

      Navigator.pop(context);

      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.success,
        message: AppLocalizations.of(context)!.photo_updated_ok,
        contentType: asc.ContentType.success,
      );

    } catch (e) {
      Navigator.pop(context);

      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.error,
        message: AppLocalizations.of(context)!.photo_updated_error,
        contentType: asc.ContentType.failure,
      );
    }
  }

  /// Actualiza en la base de datos el título y la descripción de un paso de la receta.
  ///
  /// Flujo principal:
  /// - Busca el paso en la tabla pasos_receta usando el id de la receta y el número de paso.
  /// - Si lo encuentra, actualiza el título y la descripción con los nuevos valores.
  /// - Si no se encuentra el paso, devuelve false.
  /// - Si la actualización se hace correctamente, devuelve true.
  /// - Si ocurre un error durante el proceso, lo muestra por consola y devuelve false.
  Future<bool> updateStepInDB(recipeId, int stepNumber, String newTitle, String newDescription,) async {
    try {
      final response =
          await Supabase.instance.client.from('pasos_receta').update({
        'titulo': newTitle,
        'descripcion': newDescription,
      }).match({
        'receta_id': recipeId,
        'numero_paso': stepNumber,
      }).select();

      if (response.isEmpty) {
        if (kDebugMode) {
          print("No se encontró el paso para actualizar");
        }
        return false;
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Error al actualizar el paso: $e");
      }
      return false;
    }
  }

  /// METODO PARA MOSTRAR UN TEXTO AZUL PARA INTRODUCIR EL PRIMER PASO DE UNA RECETA SI NO TIENE PASOS.
  Widget clickableBlueText() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: GestureDetector(
          onTap: () async {
            final recipeStepsProvider = context.read<RecipeStepsProvider>();

            await recipeStepsProvider.createStep("", "");
            context.read<RecipeDetailProvider>().setEditing(true);
          },
          child: Text(
            AppLocalizations.of(context)!.first_time_step,
            style: const TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.blue,
            ),
          ),
        ),
      ),
    );
  }

  /// Controla lo que ocurre al intentar salir de la pantalla de detalle de una receta.
  ///
  /// Flujo principal:
  /// - Comprueba si hay cambios en el nombre, la foto o los pasos.
  /// - Si no hay cambios, desactiva el modo edición y permite salir.
  /// - Si hay cambios, muestra un cuadro de diálogo con tres opciones:
  ///   - Cancelar: cierra el cuadro y sigue en la pantalla.
  ///   - Salir sin guardar: muestra un aviso, borra los cambios y sale.
  ///   - Guardar y salir: guarda los cambios y luego cierra la pantalla.
  /// - Devuelve true si se puede salir, o false si debe mantenerse en la vista.
  Future<bool> _onWillPop() async {
    final recipeDetailProvider = context.read<RecipeDetailProvider>();

    final hasChanges = recipeDetailProvider.nameChanged ||
        recipeDetailProvider.photoChanged ||
        recipeDetailProvider.stepChanged;

    if (!hasChanges) {
      context.read<RecipeDetailProvider>().setEditing(false);
      return true;
    }

    final option = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.save_changes),
        content: Text(AppLocalizations.of(context)!.changes_confirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancelar'),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'salir'),
            child: Text(AppLocalizations.of(context)!.no_save_exit),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'guardar'),
            child: Text(AppLocalizations.of(context)!.save_exit),
          ),
        ],
      ),
    );

    if (option == 'cancelar') return false;

    if (option == 'salir') {
      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.warning,
        message: AppLocalizations.of(context)!.data_not_saved,
        contentType: asc.ContentType.warning,
      );
      recipeDetailProvider.resetChanges();
      return true;
    }

    if (option == 'guardar') {
      await saveChanges(closeScreen: true);
      return false;
    }

    return false;
  }

  /// Guarda los cambios realizados en la receta.
  ///
  /// Flujo principal:
  /// - Comprueba si se ha cambiado el nombre, la foto o los pasos de la receta.
  /// - Si cambió el nombre o la descripción, actualiza la receta en la base de datos y en pantalla.
  /// - Si cambió la foto, la sube a Supabase y actualiza la URL en la receta.
  /// - Si cambió algún paso, recorre todos los pasos y los actualiza uno por uno.
  /// - Marca que ya no hay cambios pendientes y muestra un mensaje de éxito.
  /// - Si ocurre un error, muestra un mensaje de error.
  /// - Si cerrarPantalla es true, cierra la vista al terminar.
  Future<void> saveChanges({bool closeScreen = false}) async {
    final recipeDetailProvider = context.read<RecipeDetailProvider>();
    final recipeProvider = context.read<RecipeProvider>();
    final recipeStepsProvider = context.read<RecipeStepsProvider>();

    try {
      if (recipeDetailProvider.nameChanged) {
        final localRecipe = recipe.copyWith(
          name: capitalize(nameController.text.trim()),
          description: capitalize(descriptionController.text.trim()),
          photo: recipe.photo,
        );

        await recipeProvider.updateRecipe(localRecipe);

        if (mounted) {
          setState(() {
            recipe = localRecipe;
            nameController.text = localRecipe.name;
          });
        }

        recipeDetailProvider.setNameChanged(false);
      }

      if (recipeDetailProvider.photoChanged && newPhotoFile != null) {
        final bytes = await newPhotoFile!.readAsBytes();
        final fileName =
            '${widget.recipe.name}_${Random().nextInt(9999).toString().padLeft(4, '0')}';
        final path = 'recetas/${widget.recipe.userUuid}/$fileName.jpg';

        await Supabase.instance.client.storage.from('fotos').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );

        final newPhotoUrl =
            Supabase.instance.client.storage.from('fotos').getPublicUrl(path);

        final finalRecipe = widget.recipe.copyWith(photo: newPhotoUrl);
        await recipeProvider.updateRecipe(finalRecipe);

        recipeDetailProvider.setPhotoChanged(false);
      }

      if (recipeDetailProvider.stepChanged) {
        for (final step in recipeStepsProvider.steps) {
          await recipeStepsProvider.updateStep(step);
        }
        recipeDetailProvider.setStepChanged(false);
      }

      recipeDetailProvider.setEditing(false);

      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.success,
        message: AppLocalizations.of(context)!.recipe_updated_ok,
        contentType: asc.ContentType.success,
      );
    } catch (e) {
      debugPrint("Error en guardarCambios: $e");
      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.error,
        message: AppLocalizations.of(context)!.recipe_updated_error,
        contentType: asc.ContentType.failure,
      );
    }

    if (closeScreen && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    // Padding dinámico para ajustar el SliverAppBar en Android
    final topPadding = MediaQuery.of(context).padding.top + 50;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // ---------- APP BAR ----------
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  pinned: false,
                  centerTitle: true,
                  expandedHeight: MediaQuery.of(context).size.height * 0.55,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(60),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: editingName
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: Text(
                          recipe.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        secondChild: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: nameController,
                            focusNode: _focusNode,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                            ),
                            onChanged: (value) {
                              setState(() {
                                newName = value.trim();
                              });
                              final originalName = widget.recipe.name.trim();
                              final newValue = capitalize(value.trim());

                              context
                                  .read<RecipeDetailProvider>()
                                  .setNameChanged(newValue != originalName);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                isLight
                                    ? const Color(0xFFF1F8E9)
                                    : const Color(0xFF1E1E1E),
                              ],
                              stops: const [0.25, 0.55],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            top: topPadding,
                            left: 8,
                            right: 8,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: newPhotoFile != null
                                  ? Image.file(newPhotoFile!,
                                      width: double.infinity, fit: BoxFit.cover)
                                  : (recipe.photo.isNotEmpty
                                      ? (recipe.photo.startsWith("http")
                                          ? Image.network(recipe.photo,
                                              width: double.infinity,
                                              fit: BoxFit.cover)
                                          : Image.file(File(recipe.photo),
                                              width: double.infinity,
                                              fit: BoxFit.cover))
                                      : Container(
                                          width: double.infinity,
                                          color: Colors.grey[300],
                                          child: const Center(
                                            child: Icon(Icons.image,
                                                size: 60,
                                                color: Colors.white70),
                                          ),
                                        )),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: SliverList(
                    // ---------- STEPPER PERSONALIZADO ----------
                    delegate: SliverChildListDelegate([
                      Builder(builder: (context) {
                        final recipeStepsProvider =
                            context.watch<RecipeStepsProvider>();
                        final recipeDetailProvider =
                            context.watch<RecipeDetailProvider>();

                        if (recipeStepsProvider.isLoading) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (recipeStepsProvider.steps.isEmpty) {
                          if (recipeDetailProvider.isEditing) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              context
                                  .read<RecipeDetailProvider>()
                                  .setEditing(false);
                            });
                          }
                          return clickableBlueText();
                        }
                        return CustomStepper(
                            recipeSteps: recipeStepsProvider.steps);
                      }),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text('${AppLocalizations.of(context)!.products}:',
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                          InkWell(
                            onTap: () {
                              showProductsDialog(context);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 20),
                                const Icon(Icons.link,
                                    size: 18, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  AppLocalizations.of(context)!.link_products,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 16,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ---------- LISTA DE PRODUCTOS ASOCIADOS A LA RECETA ----------
                      Consumer<ProductsRecipeProvider>(
                        builder: (context, prov, _) {
                          if (prov.products.isEmpty) {
                            return Text(AppLocalizations.of(context)!
                                .no_linked_products);
                          }
                          return Column(
                            children: prov.products.map((product) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey.shade600, width: 0.8),
                                  borderRadius: BorderRadius.circular(10),
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                child: SizedBox(
                                  height: 85,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Center(
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 8),
                                        leading: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: AspectRatio(
                                            aspectRatio: 1.4,
                                            child: Image.network(
                                              product.photo,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                      Icons.image_not_supported,
                                                      size: 50,
                                                      color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          maxLines: 2,
                                          product.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        trailing: const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 20,
                                            color: Colors.grey),
                                        onTap: () => showProductDetail(
                                            context, product.toMap()),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      )
                    ]),
                  ),
                ),
              ],
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: (!editingName &&
                !context.watch<RecipeDetailProvider>().isEditing)
            ? SpeedDial(
                heroTag: 'fab-menu',
                animatedIcon: AnimatedIcons.menu_close,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                buttonSize: const Size(58, 58),
                children: [
                  // ---------- ICONO EDITAR PASOS ----------
                  SpeedDialChild(
                    child: const Icon(Icons.description),
                    label: AppLocalizations.of(context)!.edit_step,
                    onTap: () async {
                      final recipeStepsProvider = context.read<RecipeStepsProvider>();

                      if (recipeStepsProvider.steps.isEmpty) {
                        await recipeStepsProvider.createStep("", "");
                      }

                      context.read<RecipeDetailProvider>().setEditing(true);
                    },
                  ),

                  // ---------- ICONO EDITAR IMAGEN ----------
                  SpeedDialChild(
                    child: const Icon(Icons.image),
                    label: AppLocalizations.of(context)!.change_photo,
                    onTap: () {
                      showEditPhotoDialog(context, recipe);
                    },
                  ),

                  // ---------- ICONO EDITAR NOMBRE ----------
                  SpeedDialChild(
                    child: const Icon(Icons.edit),
                    label: AppLocalizations.of(context)!.edit_name,
                    onTap: () {
                      setState(() {
                        editingName = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _focusNode.requestFocus();
                        Future.delayed(const Duration(milliseconds: 1), () {
                          nameController.selection = TextSelection.collapsed(
                            offset: nameController.text.length,
                          );
                        });
                      });
                    },
                  ),
                ],
              )

            // ---------- FABS CONFIRMAR CAMBIOS / CANCELAR CAMBIOS ----------
            : Row(
                children: [
                  const Spacer(),
                  FloatingActionButton(
                    heroTag: 'fab-save',
                    onPressed: () async {
                      await saveChanges();
                      context.read<RecipeDetailProvider>().setEditing(false);
                      setState(() {
                        editingName = false;
                      });
                    },
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.check, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton(
                    heroTag: 'fab-cancel',
                    onPressed: () {
                      context.read<RecipeDetailProvider>().setEditing(false);
                      editingName = false;
                      context
                          .read<RecipeDetailProvider>()
                          .setNameChanged(false);
                    },
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.cancel, color: Colors.white),
                  ),
                ],
              ),
      ),
    );
  }
}
