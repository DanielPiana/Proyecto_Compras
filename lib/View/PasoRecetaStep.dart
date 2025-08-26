import 'package:flutter/material.dart';

import '../models/PasoReceta.dart';

class PasoRecetaStep extends StatelessWidget {
  final PasoReceta paso;
  final PageController controller;

  const PasoRecetaStep({super.key, required this.paso, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          paso.titulo.isEmpty ? 'Paso sin título' : paso.titulo, // Evitar texto vacío
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          paso.descripcion.isEmpty ? 'Sin descripción' : paso.descripcion, // Evitar texto vacío
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}