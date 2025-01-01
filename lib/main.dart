import 'package:flutter/material.dart';
import 'package:proyectocompras/Gastos.dart';
import 'package:proyectocompras/Compra.dart';
import 'package:proyectocompras/Producto.dart';
import 'package:proyectocompras/Recetas.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF1F8E9), // Fondo del Scaffold global
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4CAF50), // Verde principal para el AppBar
          titleTextStyle: TextStyle(
            color: Colors.white, // Texto en blanco para contraste
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white), // Iconos en blanco
        ),
      ),
      home: const Main(),
    );
  }
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  int _selectedIndex = 0;

  // Lista de páginas para el body
  final List<Widget> pages = [
    Producto(),
    Compra(),
    Gastos(),
    Recetas(),
  ];

  // Método para cambiar la página seleccionada
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                debugPrint('Hacer layout de menu');
              },
            ),
            Expanded(
              child: Container(
                height: 40, // Altura consistente con el AppBar
                decoration: BoxDecoration(
                  color: Colors.white, // Fondo blanco para el TextField
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.store, color: Colors.white),
              onPressed: () {
                debugPrint('Abrir layout para crear supermercado');
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                debugPrint('Abrir layout/ventana de ajustes');
              },
            ),
          ],
        ),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFE8F5E9), // Fondo de la barra de navegación
        selectedItemColor: const Color(0xFF388E3C), // Verde oscuro para seleccionados
        unselectedItemColor: const Color(0xFFA5D6A7), // Verde desaturado para no seleccionados
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fastfood),
            label: "Productos",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: "Compra",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: "Gastos",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: "Recetas",
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}


