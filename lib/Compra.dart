import 'package:flutter/material.dart';

class Compra extends StatelessWidget {
  const Compra({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Compras"),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          "Lista de la compra",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
