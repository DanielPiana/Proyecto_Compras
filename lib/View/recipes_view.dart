import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/Providers/products_recipe_provider.dart';
import 'package:proyectocompras/utils/capitalize.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/recipe_steps_provider.dart';
import '../Providers/recipe_provider.dart';
import '../Providers/user_provider.dart';
import 'package:flutter/foundation.dart';
import '../Widgets/recipe_placeholder.dart';
import '../Widgets/awesome_snackbar.dart';
import '../l10n/app_localizations.dart';
import '../models/recipe_model.dart';
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

  Future<void> showCreateRecipeDialog(BuildContext context, int currentRecipeIndex) async {
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
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: Text(AppLocalizations.of(context)!.select_photo),
                      onPressed: () async {
                        File? image;

                        if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
                          final picker = ImagePicker();
                          final pickedFile = await picker.pickImage(
                              source: ImageSource.gallery);
                          if (pickedFile != null) {
                            image = File(pickedFile.path);
                          }
                        } else {
                          final result = await FilePicker.platform
                              .pickFiles(type: FileType.image);
                          if (result != null &&
                              result.files.single.path != null) {
                            image = File(result.files.single.path!);
                          }
                        }

                        if (image != null) {
                          setState(() {
                            selectedImage = image;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (selectedImage != null)
                    Center(
                      child: Image.file(
                        selectedImage!,
                        height: 100,
                        fit: BoxFit.cover,
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
                    timeValid = selectedTime != null &&
                        selectedTime!.trim().isNotEmpty;
                  });

                  if (!nameValid || !descriptionValid || !timeValid) {
                    return;
                  }

                  final name = capitalize(nameController.text.trim());
                  final description =
                      capitalize(descriptionController.text.trim());
                  final userUuid = context.read<UserProvider>().uuid;

                  if (name.isEmpty || userUuid == null) return;

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
                    );

                    await context
                        .read<RecipeProvider>()
                        .createRecipe(newRecipe);

                    Navigator.pop(dialogContext);
                    showAwesomeSnackBar(
                      context,
                      title: AppLocalizations.of(context)!.success,
                      message: AppLocalizations.of(context)!.recipe_created_ok,
                      contentType: asc.ContentType.success,
                    );
                  } catch (e) {
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
            centerTitle: true),

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
                            final recipe = recipeProvider.recipesToShow[index];
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
                                            create: (_) =>
                                                ProductsRecipeProvider(
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
                                                      // TODO: método compartir
                                                    } else if (value ==
                                                        'eliminar') {
                                                      // Eliminar
                                                      final recipeProvider =
                                                          context.read<
                                                              RecipeProvider>();
                                                      final allRecipes =
                                                          List.of(recipeProvider
                                                              .recipes);
                                                      final isLastRecipe =
                                                          allRecipes.length ==
                                                              1;

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
                                                  color: Theme.of(context).colorScheme.surface,
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                            style:
                                                const TextStyle(fontSize: 18),
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
                  }
                  ),
        floatingActionButton:
        FloatingActionButton(
          onPressed: () {
            showCreateRecipeDialog(context, currentRecipeIndex);
          },
          child: const Icon(Icons.add),
        ),
    );
  }
}