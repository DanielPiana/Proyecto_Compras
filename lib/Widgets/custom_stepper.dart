import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:food_manager/Providers/recipe_detail_provider.dart';
import 'package:food_manager/Widgets/awesome_snackbar.dart';
import '../Providers/recipe_steps_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/step_recipe_model.dart';

class CustomStepper extends StatefulWidget {
  final List<RecipeStep> recipeSteps;

  const CustomStepper({
    super.key,
    required this.recipeSteps,
  });

  @override
  State<CustomStepper> createState() => _CustomStepperState();
}

class _CustomStepperState extends State<CustomStepper> {
  int currentStep = 0;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _focusNode = FocusNode();

  bool _lastEditingState = false;

  @override
  void initState() {
    super.initState();

    // CARGAR EL PRIMER PASO EN LOS CONTROLLERS
    _titleController.text = widget.recipeSteps.first.title;
    _descriptionController.text = widget.recipeSteps.first.description;

    final recipeDetailProvider = context.read<RecipeDetailProvider>();

    recipeDetailProvider.addListener(() {
      // SI CAMBIAMOS EL ESTADO DE EDICIÓN, PONEMOS EL FOCUS EN EL CONTROLLER
      if (!_lastEditingState && recipeDetailProvider.isEditing) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            _focusNode.requestFocus();
          }
        });
      }
      _lastEditingState = recipeDetailProvider.isEditing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailRecipeProvider = context.read<RecipeDetailProvider>();

    // CARGAMOS PASOS DESDE EL PROVIDER
    final steps = context.watch<RecipeStepsProvider>().steps;

    // SI NO HAY PASOS, RESETEAMOS A PASO 0 VACÍO
    if (steps.isEmpty) {
      if (currentStep != 0) {
        setState(() {
          currentStep = 0;
          _titleController.text = '';
          _descriptionController.text = '';
        });
      }
      // SI EL PASO ACTUAL FUE BORRADO, IR AL ULTIMO DISPONIBLE
    } else if (currentStep >= steps.length) {
      setState(() {
        currentStep = steps.length - 1;
        _titleController.text = steps[currentStep].title;
        _descriptionController.text = steps[currentStep].description;
      });
    }

    return Column(
      children: [
        // CONTAINER PRINCIPAL
        Container(
          margin: const EdgeInsets.all(0),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade600, width: 0.8),
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF424242),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CONTAINER INDICADOR DE PASO EN EL QUE ESTAS
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${AppLocalizations.of(context)!.step}: ${steps.isEmpty ? 0 : currentStep + 1} de ${steps.length}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // CAMBIO DE MODO LECTURA A MODO EDICIÓN
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 400),
                  crossFadeState: context
                      .watch<RecipeDetailProvider>()
                      .isEditing
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  // MODO LECTURA
                  firstChild: (steps.isEmpty)
                      ? const SizedBox.shrink()
                      : Column(
                    children: [
                      Center(

                        child: Text(
                          steps[currentStep].title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        steps[currentStep].description,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  // MODO EDICION
                  secondChild: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        TextField(
                          controller: _titleController,
                          focusNode: _focusNode,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.title,
                          ),
                          onChanged: (value) {
                            if (steps.isEmpty) return;
                            final updated = steps[currentStep].copyWith(title: value);
                            context.read<RecipeStepsProvider>().updateLocalStep(updated.stepNumber, updated);
                            detailRecipeProvider.setStepChanged(true);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _descriptionController,
                          maxLines: null,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!
                                .description,
                          ),
                          onChanged: (value) {
                            if (steps.isEmpty) return;
                            final actualizado = steps[currentStep].copyWith(description: value);
                            context.read<RecipeStepsProvider>().updateLocalStep(actualizado.stepNumber, actualizado);
                            detailRecipeProvider.setStepChanged(true);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                // BOTONES NUEVO PASO/ELIMINAR PASO EN MODO EDICION
                if (detailRecipeProvider.isEditing)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () {
                          final recipeStepsProvider = context.read<RecipeStepsProvider>();
                          if (recipeStepsProvider.steps.length == 10) {
                            showAwesomeSnackBar(context,
                                title: AppLocalizations.of(context)!.warning,
                                message: AppLocalizations.of(context)!.max_steps_warning,
                                contentType: ContentType.warning);
                          } else {
                            // CREAR PASO VACIO
                            recipeStepsProvider.createStep("", "");
                            final newSteps = recipeStepsProvider.steps;
                            // IR AL PASO RECIEN CREADO
                            setState(() {
                              currentStep = newSteps.isEmpty ? 0 : newSteps.length - 1;
                              _titleController.text = newSteps.isNotEmpty ? newSteps.last.title : "";
                              _descriptionController.text = newSteps.isNotEmpty ? newSteps.last.description : "";
                            });
                            context.read<RecipeDetailProvider>().setEditing(
                                true);
                          }
                        },
                        child: Text(AppLocalizations.of(context)!.add_step),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () async {
                          final recipeStepsProvider = context.read<RecipeStepsProvider>();
                          if (recipeStepsProvider.steps.isEmpty) return;
                          final paso = recipeStepsProvider.steps[currentStep];

                          final confirmation = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                title: Text(
                                    AppLocalizations.of(context)!.delete_step),
                                content: Text(
                                    AppLocalizations.of(context)!.delete_step_confirmation),
                                actions: [
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: Text(
                                        AppLocalizations.of(context)!.cancel),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: Text(
                                        AppLocalizations.of(context)!.delete),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmation != true) return;

                          await recipeStepsProvider.deleteStep(paso.stepNumber);

                          if (!mounted) return;
                          final stepsLength = recipeStepsProvider.steps.length;

                          if (stepsLength > 0) {
                            setState(() {
                              if (currentStep >= stepsLength) currentStep = stepsLength - 1;
                              _titleController.text = recipeStepsProvider.steps[currentStep].title;
                              _descriptionController.text = recipeStepsProvider.steps[currentStep].description;
                            });
                          } else {
                            setState(() {
                              _titleController.clear();
                              _descriptionController.clear();
                            });
                          }
                        },
                        child: Text(AppLocalizations.of(context)!.delete_step),
                      )
                    ],
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            steps.length,
                (index) =>
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == currentStep ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: index == currentStep
                        ? Colors.blue
                        : index < currentStep
                        ? Colors.green.withOpacity(0.6)
                        : Colors.grey.withOpacity(0.4),
                  ),
                ),
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text(AppLocalizations.of(context)!.previous),
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: currentStep > 0
                    ? () {
                  setState(() {
                    currentStep--;
                    _titleController.text = steps[currentStep].title;
                    _descriptionController.text = steps[currentStep].description;
                  });
                }
                    : null,
              ),
              ElevatedButton.icon(
                icon: Icon(
                  (steps.isNotEmpty && currentStep == steps.length - 1)
                      ? Icons.check
                      : (steps.isNotEmpty && currentStep == steps.length - 2)
                      ? Icons.flag
                      : Icons.arrow_forward,
                  size: 16,
                ),
                label: Text(
                  (steps.isEmpty)
                      ? AppLocalizations.of(context)!.next
                      : (currentStep == steps.length - 1)
                      ? AppLocalizations.of(context)!.finish
                      : (currentStep == steps.length - 2)
                      ? AppLocalizations.of(context)!.finish
                      : AppLocalizations.of(context)!.next,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (steps.isNotEmpty &&
                      currentStep == steps.length - 1)
                      ? Colors.green
                      : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                ),
                onPressed: (steps.isNotEmpty && currentStep < steps.length - 1)
                    ? () {
                  setState(() {
                    currentStep++;
                    _titleController.text = steps[currentStep].title;
                    _descriptionController.text =
                        steps[currentStep].description;
                  });
                }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}