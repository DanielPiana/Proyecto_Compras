import 'package:flutter/material.dart';

class Producto extends StatelessWidget {
  const Producto({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Productos"),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          "Productos",
          style: TextStyle(
            color: Color(0xFF212121), // Gris oscuro para el texto
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}