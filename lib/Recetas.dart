import 'package:flutter/material.dart';

class Recetas extends StatelessWidget {
  const Recetas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recetas"),
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
