import 'package:flutter/material.dart';

class Gastos extends StatelessWidget {
  const Gastos({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gastos"),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          "Lista de la Gastos",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
