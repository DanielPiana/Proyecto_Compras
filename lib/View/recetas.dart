import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Recetas extends StatelessWidget {
  const Recetas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.recipes),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          "Lista de la Recetas",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
