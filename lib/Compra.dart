import 'package:proyectocompras/Gastos.dart';
import 'package:proyectocompras/Producto.dart';
import 'package:flutter/material.dart';
import 'package:proyectocompras/Recetas.dart';
/*---------------------------------------------------------------------------*/
void main() {
  runApp(const MainApp());
}
/*---------------------------------------------------------------------------*/
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
        home: Main()
    );
  }
}
/*---------------------------------------------------------------------------*/
class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _HomePageState();
}
/*---------------------------------------------------------------------------*/
class _HomePageState extends State<Main> {
  int _selectedIndex =0;

  final List<Widget> listaWidgets = [
    const Center(child: Text("Pagina principal")),
    Producto(),
    Gastos(),
    Recetas(),
  ];
  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: listaWidgets[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(items:[
        BottomNavigationBarItem(icon: Icon(Icons.fastfood,color: Colors.green),
            label: "Productos"),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined,color: Colors.green),
            label: "Compra"),
        BottomNavigationBarItem(icon: Icon(Icons.attach_money,color: Colors.green),
            label: "Gastos"),
        BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu,color: Colors.green),
            label: "Recetas"),
      ],
        currentIndex: _selectedIndex,
        onTap: onItemTapped,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
      ),

    );
  }
}
/*---------------------------------------------------------------------------*/