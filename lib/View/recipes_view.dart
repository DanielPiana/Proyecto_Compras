import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/Providers/products_recipe_provider.dart';
import 'package:proyectocompras/main.dart';
import 'package:proyectocompras/utils/capitalize.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/products_provider.dart';
import '../Providers/recipe_steps_provider.dart';
import '../Providers/recipe_provider.dart';
import '../Providers/user_provider.dart';
import 'package:flutter/foundation.dart';
import '../Widgets/recipe_placeholder.dart';
import '../Widgets/awesome_snackbar.dart';
import '../l10n/app_localizations.dart';
import '../models/recipe_model.dart';
import '../utils/image_picker.dart';
import 'recipe_detail_view.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;

class RecipesView extends StatefulWidget {
  const RecipesView({super.key});

  @override
  State<RecipesView> createState() => RecipesViewState();
}

class RecipesViewState extends State<RecipesView> {
  int currentRecipeIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  /// Genera un código aleatorio para compartir esa receta
  String _generateShareCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Muestra el diálogo para importar una receta compartida
  void _showImportDialog(BuildContext context) {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(AppLocalizations.of(context)!.import_recipe),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.type_code_recipe,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.code,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim().toUpperCase();
              Navigator.pop(dialogContext);
              if (code.isNotEmpty) {
                await _importRecipe(context, code);
              }
            },
            child: Text(AppLocalizations.of(context)!.import),
          ),
        ],
      ),
    );
  }

  /// Importa una receta usando su código de compartir
  Future<void> _importRecipe(BuildContext context, String code) async {
    if (code.isEmpty) return;

    final userUuid = context.read<UserProvider>().uuid!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // VERIFICAR QUE NO SE HAYA IMPORTADO EL MISMO CODIGO
      final alreadyImported = await Supabase.instance.client
          .from('recetas')
          .select()
          .eq('usuariouuid', userUuid)
          .eq('codigo_importado', code)
          .maybeSingle();

      if (alreadyImported != null) {
        Navigator.pop(context);
        showAwesomeSnackBar(
          context,
          title: AppLocalizations.of(context)!.warning,
          message:
              '${AppLocalizations.of(context)!.recipe_already_imported} "${alreadyImported['nombre']}"',
          contentType: asc.ContentType.warning,
        );
        return;
      }

      // BUSCAMOS LA RECETA POR CODIGO
      final recipeResponse = await Supabase.instance.client
          .from('recetas')
          .select()
          .eq('codigo_compartir', code)
          .single();

      final originalRecipe = RecipeModel.fromMap(recipeResponse);
      final originalRecipeId = originalRecipe.id!;

      // COMPROBAMOS QUE NO INTENTE IMPORTAR SU PROPIA RECETA
      if (originalRecipe.userUuid == userUuid) {
        Navigator.pop(context);
        showAwesomeSnackBar(
          context,
          title: AppLocalizations.of(context)!.warning,
          message: AppLocalizations.of(context)!.own_recipe_warning,
          contentType: asc.ContentType.warning,
        );
        return;
      }

      // BUSCAMOS LOS PRODUCTOS VINCULADOS A LA RECETA
      final productsResponse = await Supabase.instance.client
          .from('receta_producto')
          .select('*, productos(*)')
          .eq('idreceta', originalRecipeId);

      // BUSCAMOS LOS PASOS VINCULADOS A LA RECETA
      final stepsResponse = await Supabase.instance.client
          .from('pasos_receta')
          .select()
          .eq('receta_id', originalRecipeId)
          .order('numero_paso', ascending: true);

      Navigator.pop(context);

      // MOSTRAMOS DIALOGO DE PREVISUALIZACION DE RECETA
      await _showRecipePreviewDialog(
        context,
        originalRecipe,
        productsResponse,
        stepsResponse,
        userUuid,
        code,
      );
    } catch (e) {
      Navigator.pop(context);
      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.error,
        message: AppLocalizations.of(context)!.invalid_code,
        contentType: asc.ContentType.failure,
      );
    }
  }

  /// Muestra un diálogo con previsualización de la receta a importar
  Future<void> _showRecipePreviewDialog(BuildContext context, RecipeModel recipe, List<Map<String, dynamic>> products, List<Map<String, dynamic>> steps, String userUuid, String importCode,) async {
    // Contar productos existentes vs nuevos
    int existingCount = 0;

    for (var productData in products) {
      final originalProduct = productData['productos'];
      final String? barcode = originalProduct['codbarras'];

      if (barcode != null && barcode.isNotEmpty) {
        final existing = await Supabase.instance.client
            .from('productos')
            .select()
            .eq('usuariouuid', userUuid)
            .eq('codbarras', barcode)
            .maybeSingle();

        if (existing != null) existingCount++;
      }
    }

    final newCount = products.length - existingCount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.import_recipe,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              recipe.name,
              style: TextStyle(
                  fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // DESCRIPCION DE LA RECETA
                Text(
                  recipe.description,
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  recipe.time,
                  style: const TextStyle(
                      fontSize: 14, fontStyle: FontStyle.italic),
                ),

                const Divider(height: 24),

                // RESUMEN DE LO QUE SE IMPORTARÁ
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.what_will_be_imported,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• ${products.length} ${AppLocalizations.of(context)!.ingredients}',
                        style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSecondary),
                      ),
                      if (existingCount > 0)
                        Text(
                          '  └─ $existingCount ${AppLocalizations.of(context)!.already_have}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.green[700]),
                        ),
                      if (newCount > 0)
                        Text(
                          '  └─ $newCount ${AppLocalizations.of(context)!.new_products}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.blue[700]),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '• ${steps.length} ${AppLocalizations.of(context)!.steps}',
                        style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSecondary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // INFO SOBRE ORGANIZACIÓN
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_special,
                          size: 18, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!
                              .products_organized_in(recipe.name),
                          style:
                              TextStyle(fontSize: 12, color: Colors.amber[900]),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 24),

                // LISTA DE INGREDIENTES (solo mostrar)
                Text(
                  '${AppLocalizations.of(context)!.ingredients} (${products.length})',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...products.take(5).map((productData) {
                  final product = productData['productos'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            product['nombre'],
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '${product['precio']}€',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }),
                if (products.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '... ${AppLocalizations.of(context)!.and_more(products.length - 5)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),

                const Divider(height: 24),

                // PASOS
                Text(
                  '${AppLocalizations.of(context)!.steps} (${steps.length})',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...steps.take(3).toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (step['titulo']?.toString().isNotEmpty ??
                                  false)
                                Text(
                                  step['titulo'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              Text(
                                step['descripcion'] ?? '',
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (steps.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '... ${AppLocalizations.of(context)!.and_more_steps(steps.length - 3)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(context)!.import),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // IMPORTAMOS TODO
      await _confirmImport(
          context, recipe, products, steps, userUuid, importCode);
    }
  }

  /// Confirma e importa la receta con los productos
  Future<void> _confirmImport(BuildContext context, RecipeModel originalRecipe, List<Map<String, dynamic>> allProducts, List<Map<String, dynamic>> steps, String userUuid, String importCode,) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // CREAMOS LA NUEVA RECETA
      final newRecipe = RecipeModel(
        name: originalRecipe.name,
        description: originalRecipe.description,
        time: originalRecipe.time,
        photo: originalRecipe.photo,
        userUuid: userUuid,
        shareCode: _generateShareCode(),
        importedCode: importCode,
      );

      final createdRecipeData = await Supabase.instance.client
          .from('recetas')
          .insert(newRecipe.toMap())
          .select()
          .single();

      final newRecipeId = createdRecipeData['id'] as int;

      // USAMOS EL NOMBRE DE LA RECETA COMO SUPERMERCADO
      final recipeSupermarket = originalRecipe.name;

      // SIEMPRE CREAMOS PRODUCTOS NUEVOS
      final List<Map<String, dynamic>> productsToLink = [];

      for (var productData in allProducts) {
        final originalProduct = productData['productos'];

        // NO HACE FALTA VERIFICACIÓN DE SI EXISTE
        final newProductData = await Supabase.instance.client
            .from('productos')
            .insert({
              'codbarras': originalProduct['codbarras'],
              'nombre': originalProduct['nombre'],
              'descripcion': originalProduct['descripcion'],
              'precio': originalProduct['precio'],
              'supermercado': recipeSupermarket,
              'usuariouuid': userUuid,
              'foto': originalProduct['foto'] ?? '',
            })
            .select()
            .single();

        final productIdToLink = newProductData['id'] as int;

        productsToLink.add({
          'idreceta': newRecipeId,
          'idproducto': productIdToLink,
        });
      }

      // VINCULAMOS TODOS LOS PRODUCTOS
      await Supabase.instance.client
          .from('receta_producto')
          .insert(productsToLink);

      // COPIAMOS LOS PASOS
      if (steps.isNotEmpty) {
        final stepsToCopy = steps.map((step) {
          return {
            'receta_id': newRecipeId,
            'numero_paso': step['numero_paso'],
            'titulo': step['titulo'],
            'descripcion': step['descripcion'],
          };
        }).toList();

        await Supabase.instance.client.from('pasos_receta').insert(stepsToCopy);
      }

      // RECARGAMOS PROVIDERS
      await context.read<RecipeProvider>().loadRecipes();
      await context.read<ProductProvider>().loadProducts();

      Navigator.pop(context);

      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.success,
        message:
            '${AppLocalizations.of(context)!.recipe_imported_successfully}\n'
            '✓ ${productsToLink.length} ${AppLocalizations.of(context)!.ingredients}\n'
            '✓ ${steps.length} ${AppLocalizations.of(context)!.steps}',
        contentType: asc.ContentType.success,
      );
    } catch (e) {
      Navigator.pop(context);
      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.error,
        message: '${AppLocalizations.of(context)!.import_error}: $e',
        contentType: asc.ContentType.failure,
      );
    }
  }

  Future<void> showCreateRecipeDialog(BuildContext context, int currentRecipeIndex) async {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    File? selectedImage;
    String? selectedTime;

    bool nameValid = false;
    bool descriptionValid = false;
    bool timeValid = false;

    bool nameTouched = false;
    bool descriptionTouched = false;
    bool timeTouched = false;

    List<String> times(BuildContext context) => [
          AppLocalizations.of(context)!.lessThan15,
          AppLocalizations.of(context)!.lessThan30,
          AppLocalizations.of(context)!.lessThan45,
          AppLocalizations.of(context)!.lessThan1h,
          AppLocalizations.of(context)!.lessThan1h30,
          AppLocalizations.of(context)!.lessThan2h,
          AppLocalizations.of(context)!.moreThan2h,
        ];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.new_recipe),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.name,
                      suffixIcon: nameTouched
                          ? (nameValid
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : const Icon(Icons.cancel, color: Colors.red))
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        nameTouched = true;
                        nameValid = value.trim().isNotEmpty;
                      });
                    },
                  ),
                  if (nameTouched && !nameValid)
                    Text(
                      AppLocalizations.of(context)!.name_error_message,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.description,
                      suffixIcon: descriptionTouched
                          ? (descriptionValid
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : const Icon(Icons.cancel, color: Colors.red))
                          : null,
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      setState(() {
                        descriptionTouched = true;
                        descriptionValid = value.trim().isNotEmpty;
                      });
                    },
                  ),
                  if (descriptionTouched && !descriptionValid)
                    Text(
                      AppLocalizations.of(context)!.description_error_message,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedTime,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.estimated_time,
                      suffixIcon: timeTouched
                          ? (timeValid
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : const Icon(Icons.cancel, color: Colors.red))
                          : null,
                    ),
                    items: times(context).map((time) {
                      return DropdownMenuItem(
                        value: time,
                        child: SizedBox(
                          width: double.infinity,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade400, width: 0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(time,
                                style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      );
                    }).toList(),
                    selectedItemBuilder: (context) {
                      return times(context).map((s) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(s, style: const TextStyle(fontSize: 16)),
                        );
                      }).toList();
                    },
                    onChanged: (value) {
                      setState(() {
                        timeTouched = true;
                        selectedTime = value;
                        timeValid = value != null && value.trim().isNotEmpty;
                      });
                    },
                  ),
                  if (timeTouched && !timeValid)
                    Text(
                      AppLocalizations.of(context)!.time_error_message,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 16),
                  // Cambiar esta sección en el diálogo:

                  const SizedBox(height: 16),

                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // BOTÓN GALERÍA
                            Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[700]!, width: 0.8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.photo_library, color: Colors.green, size: 28),
                                  tooltip: AppLocalizations.of(context)!.select_photo,
                                  onPressed: () async {
                                    final file = await ImagePickerHelper.imageFromGallery();
                                    if (file != null) {
                                      setState(() {
                                        selectedImage = file;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // BOTÓN CÁMARA/CLIPBOARD
                            Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[700]!, width: 0.8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt, color: Colors.green, size: 28),
                                  tooltip: isMobile
                                      ? AppLocalizations.of(context)!.open_camera
                                      : AppLocalizations.of(context)!.paste_image_from_clipboard,
                                  onPressed: () async {
                                    final file = await ImagePickerHelper.imageFromClipboard();
                                    if (file != null) {
                                      setState(() {
                                        selectedImage = file;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // ========== PREVIEW DE IMAGEN ==========
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: selectedImage != null
                                ? Image.file(
                              selectedImage!,
                              fit: BoxFit.contain,
                            )
                                : Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 60,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                child: Text(AppLocalizations.of(context)!.cancel),
                onPressed: () => Navigator.pop(dialogContext),
              ),
              ElevatedButton(
                child: Text(AppLocalizations.of(context)!.save),
                onPressed: () async {
                  setState(() {
                    nameTouched = true;
                    descriptionTouched = true;
                    timeTouched = true;

                    nameValid = nameController.text.trim().isNotEmpty;
                    descriptionValid =
                        descriptionController.text.trim().isNotEmpty;
                    timeValid =
                        selectedTime != null && selectedTime!.trim().isNotEmpty;
                  });

                  if (!nameValid || !descriptionValid || !timeValid) {
                    return;
                  }

                  final name = capitalize(nameController.text.trim());
                  final description =
                      capitalize(descriptionController.text.trim());
                  final userUuid = context.read<UserProvider>().uuid;

                  if (name.isEmpty || userUuid == null) return;

                  showDialog(
                    context: dialogContext,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    String? imageUrl;

                    if (selectedImage != null) {
                      final bytes = await selectedImage!.readAsBytes();
                      final fileName =
                          '${name}_${Random().nextInt(9999).toString().padLeft(4, '0')}';
                      final path = 'recetas/$userUuid/$fileName.jpg';

                      await Supabase.instance.client.storage
                          .from('fotos')
                          .uploadBinary(path, bytes,
                              fileOptions:
                                  const FileOptions(contentType: 'image/jpeg'));

                      imageUrl = Supabase.instance.client.storage
                          .from('fotos')
                          .getPublicUrl(path);
                    }

                    final newRecipe = RecipeModel(
                      name: name,
                      description: description,
                      userUuid: userUuid,
                      photo: imageUrl ?? '',
                      time: selectedTime ?? '',
                      shareCode: _generateShareCode(),
                    );

                    await context.read<RecipeProvider>().createRecipe(newRecipe);

                    Navigator.pop(dialogContext);

                    Navigator.pop(dialogContext);

                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message: AppLocalizations.of(context)!.recipe_created_ok,
                      contentType: asc.ContentType.success,
                    );
                  } catch (e) {
                    Navigator.pop(dialogContext);

                    Navigator.pop(dialogContext);

                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.error,
                      message:
                          AppLocalizations.of(context)!.recipe_created_error,
                      contentType: asc.ContentType.failure,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();

    return Scaffold(
      // ---------- APP BAR ----------
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.recipes,
          style: const TextStyle(
              fontSize: 30,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: AppLocalizations.of(context)!.import_recipe,
            onPressed: () => _showImportDialog(context),
          ),
        ],
      ),
      // ---------- BODY ----------
      body: recipeProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : recipeProvider.recipesToShow.isEmpty
              ? const RecipePlaceholder()
              : LayoutBuilder(builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  int crossAxisCount = 1;

                  if (width >= 1200) {
                    crossAxisCount = 5;
                  } else if (width >= 900) {
                    crossAxisCount = 4;
                  } else if (width >= 600) {
                    crossAxisCount = 2;
                  }

                  // ---------- SECCIÓN DE LAS RECETAS ----------
                  return Builder(
                    builder: (context) {
                      final isLight =
                          Theme.of(context).brightness == Brightness.light;

                      return GridView.builder(
                        itemCount: recipeProvider.recipesToShow.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisExtent: 280,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) {
                          var recipe = recipeProvider.recipesToShow[index];
                          return Card(
                            color: Theme.of(context).colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: Colors.grey.shade600,
                                width: 0.8,
                              ),
                            ),
                            elevation: 4,

                            // ---------- LISTENER DE LA RECETA ----------
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MultiProvider(
                                      providers: [
                                        ChangeNotifierProvider(
                                          create: (_) => RecipeStepsProvider(
                                            Supabase.instance.client,
                                            recipe.id!,
                                          )..loadSteps(),
                                        ),
                                        ChangeNotifierProvider(
                                          create: (_) => ProductsRecipeProvider(
                                            Supabase.instance.client,
                                            recipe.id!,
                                          )..loadProducts(),
                                        ),
                                      ],
                                      child: RecipeDetailView(recipe: recipe),
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  recipeProvider.loadRecipes();
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade600,
                                        width: 0.8,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Stack(
                                        children: [
                                          recipe.photo.isNotEmpty
                                              ? Image.network(
                                                  recipe.photo,
                                                  width: double.infinity,
                                                  height: 150,
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  width: double.infinity,
                                                  height: 150,
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                    size: 60,
                                                    color: Colors.grey,
                                                  ),
                                                ),

                                          // ---------- ICONO PARA BORRAR Y COMPARTIR ----------
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: PopupMenuButton<String>(
                                                onSelected: (value) async {
                                                  if (value == 'compartir') {
                                                    try {
                                                      final code =
                                                          recipe.shareCode ??
                                                              '';

                                                      if (code.isEmpty) {
                                                        showAwesomeSnackBar(
                                                          context,
                                                          title: AppLocalizations
                                                                  .of(context)!
                                                              .error,
                                                          message:
                                                              'Error: receta sin código',
                                                          contentType: asc
                                                              .ContentType
                                                              .failure,
                                                        );
                                                        return;
                                                      }

                                                      await Share.share(
                                                          '${AppLocalizations.of(context)!.share_recipe_message}"${recipe.name}"\n\n'
                                                          '${AppLocalizations.of(context)!.use_code} $code');
                                                    } catch (e) {
                                                      showAwesomeSnackBar(
                                                        context,
                                                        title:
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .error,
                                                        message: AppLocalizations
                                                                .of(context)!
                                                            .error_sharing_code,
                                                        contentType: asc
                                                            .ContentType
                                                            .failure,
                                                      );
                                                    }
                                                  } else if (value ==
                                                      'eliminar') {
                                                    // Eliminar
                                                    final recipeProvider =
                                                        context.read<
                                                            RecipeProvider>();
                                                    final allRecipes = List.of(
                                                        recipeProvider.recipes);
                                                    final isLastRecipe =
                                                        allRecipes.length == 1;

                                                    try {
                                                      if (isLastRecipe) {
                                                        showAwesomeSnackBar(
                                                          context,
                                                          title: AppLocalizations
                                                                  .of(context)!
                                                              .success,
                                                          message: AppLocalizations
                                                                  .of(context)!
                                                              .recipe_deleted_ok,
                                                          contentType: asc
                                                              .ContentType
                                                              .success,
                                                        );
                                                      }
                                                      await recipeProvider
                                                          .deleteRecipe(
                                                              recipe.id!);

                                                      if (!isLastRecipe &&
                                                          context.mounted) {
                                                        showAwesomeSnackBar(
                                                          context,
                                                          title: AppLocalizations
                                                                  .of(context)!
                                                              .success,
                                                          message: AppLocalizations
                                                                  .of(context)!
                                                              .recipe_deleted_ok,
                                                          contentType: asc
                                                              .ContentType
                                                              .success,
                                                        );
                                                      }
                                                    } catch (error) {
                                                      if (context.mounted) {
                                                        showAwesomeSnackBar(
                                                          context,
                                                          title: AppLocalizations
                                                                  .of(context)!
                                                              .error,
                                                          message: AppLocalizations
                                                                  .of(context)!
                                                              .recipe_deleted_error,
                                                          contentType: asc
                                                              .ContentType
                                                              .failure,
                                                        );
                                                      }
                                                    }
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  PopupMenuItem(
                                                    value: 'compartir',
                                                    child: Text(
                                                        AppLocalizations.of(
                                                                context)!
                                                            .share),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'eliminar',
                                                    child: Text(
                                                        AppLocalizations.of(
                                                                context)!
                                                            .delete),
                                                  ),
                                                ],
                                                icon: const Icon(
                                                    Icons.more_vert,
                                                    color: Colors.white,
                                                    size: 20),
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // ---------- SECCIÓN INFERIOR DE PRECIO TOTAL ----------
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          maxLines: 2,
                                          recipe.name,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${AppLocalizations.of(context)!.time}: ${recipe.time}',
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showCreateRecipeDialog(context, currentRecipeIndex);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
