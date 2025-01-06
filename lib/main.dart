import 'package:flutter/material.dart';
import 'package:proyectocompras/Gastos.dart';
import 'package:proyectocompras/Compra.dart';
import 'package:proyectocompras/Producto.dart';
import 'package:proyectocompras/Recetas.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
/*---------------------------------------------------------------------------------------*/
void main() async {
  // INICIALIZAR SQLITE PARA APLICACIONES DE ESCRITORIO.
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  // CONFIGURAR RUTA DE LA BASE DE DATOS.
  final dbPath = join(await databaseFactory.getDatabasesPath(), 'gestioncompras.db');
  final database = await databaseFactory.openDatabase(dbPath);

/* // ELIMINAR TABLAS EXISTENTES Y VOLVER A CREARLAS.
  await database.execute('DROP TABLE IF EXISTS recetas');
  await database.execute('DROP TABLE IF EXISTS productos');
  await database.execute('DROP TABLE IF EXISTS receta_producto');
  await database.execute('DROP TABLE IF EXISTS facturas');
  await database.execute('DROP TABLE IF EXISTS producto_factura');
  await database.execute('DROP TABLE IF EXISTS compra');
*/
  // CREAR TABLA DE TAREAS SI NO EXISTE.
  try {
    await database.execute('''
 CREATE TABLE IF NOT EXISTS recetas (
  id INTEGER PRIMARY KEY,
  nombre TEXT
);
CREATE TABLE IF NOT EXISTS productos (
  id INTEGER PRIMARY KEY,
  codBarras INTEGER UNIQUE,
  nombre TEXT,
  descripcion TEXT,
  precio REAL,
  supermercado TEXT
);
CREATE TABLE IF NOT EXISTS receta_producto (
  idReceta INTEGER,
  idProducto INTEGER,
  cantidad TEXT,
  FOREIGN KEY (idReceta) REFERENCES recetas(id),
  FOREIGN KEY (idProducto) REFERENCES productos(id)
);
CREATE TABLE IF NOT EXISTS facturas (
  id INTEGER PRIMARY KEY,
  precio REAL,
  fecha TEXT,
  supermercado TEXT
);
CREATE TABLE IF NOT EXISTS producto_factura (
  idProducto INTEGER,
  idFactura INTEGER,
  cantidad INTEGER,
  FOREIGN KEY (idProducto) REFERENCES productos(id),
  FOREIGN KEY (idFactura) REFERENCES facturas(id)
);
CREATE TABLE IF NOT EXISTS compra (
  idProducto INTEGER,
  nombre TEXT,
  precio REAL,
  marcado INTEGER DEFAULT 0,
  FOREIGN KEY (idProducto) REFERENCES productos(id)
);
''');
  } catch (e) {
    debugPrint("Error al crear tablas: $e");
  }

  // INICIAR APLICACIÓN CON BASE DE DATOS.
  runApp(MainApp(database: database));
}
/*---------------------------------------------------------------------------------------*/
class MainApp extends StatelessWidget {
  final Database database;

  const MainApp({super.key,required this.database});

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
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: Main(database: database),
    );
  }
}
/*---------------------------------------------------------------------------------------*/
class Main extends StatefulWidget {
  final Database database;

  const Main({super.key,required this.database});

  @override
  State<Main> createState() => _MainState();
}
/*---------------------------------------------------------------------------------------*/
class _MainState extends State<Main> {
  late List<Widget> pages;

  int _selectedIndex = 0;

  @override //INICIALIZADOR
  void initState() {
    super.initState();

    // Inicializamos las paginas aqui, para que no de error el widget.database
     pages = [
      Producto(database: widget.database),
      Compra(database: widget.database),
      Gastos(),
      Recetas(),
    ];
  }
  /*
  // Función para cargar los productos desde la base de datos
  Future<void> _cargarProductos() async {
    try {
      final productos = await widget.database.query('productos');
      setState(() {
        _productos = productos;
      });
    } catch (e) {
      debugPrint('Error al cargar productos: $e');
    }
  }
*/

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
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
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
/*---------------------------------------------------------------------------------------*/