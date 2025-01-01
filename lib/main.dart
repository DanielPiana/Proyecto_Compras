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

  // ELIMINAR TABLAS EXISTENTES Y VOLVER A CREARLAS.
  await database.execute('DROP TABLE IF EXISTS recetas');
  await database.execute('DROP TABLE IF EXISTS productos');
  await database.execute('DROP TABLE IF EXISTS receta_producto');
  await database.execute('DROP TABLE IF EXISTS facturas');
  await database.execute('DROP TABLE IF EXISTS producto_factura');

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
INSERT INTO productos (id, codBarras, nombre, descripcion, precio, supermercado)
VALUES 
    (4, 111111111111, 'Tomates', 'Tomates frescos', 3.49, 'Dia'),
    (5, 222222222222, 'Arroz', 'Arroz blanco 1kg', 2.5, 'Mercadona'),
    (6, 333333333333, 'Azúcar', 'Azúcar refinada', 1.99, 'Gadis'),
    (7, 444444444444, 'Sal', 'Sal marina 1kg', 1.25, 'Dia'),
    (8, 555555555556, 'Cereales', 'Cereales integrales', 3.99, 'Mercadona'),
    (9, 666666666666, 'Aceite de oliva', 'Aceite de oliva virgen extra 1L', 5.99, 'Gadis'),
    (10, 777777777777, 'Huevos', 'Huevos frescos (docena)', 2.99, 'Dia'),
    (11, 888888888888, 'Queso', 'Queso manchego 200g', 4.5, 'Mercadona'),
    (12, 999999999999, 'Lechuga', 'Lechuga iceberg', 1.49, 'Gadis'),
    (13, 123456789013, 'Yogur', 'Yogur natural (pack de 4)', 3.0, 'Dia'),
    (14, 987654321099, 'Zumo', 'Zumo de naranja 1L', 2.75, 'Mercadona'),
    (15, 555557555556, 'Pasta', 'Pasta espagueti 500g', 2.25, 'Gadis'),
    (16, 444444444445, 'Harina', 'Harina de trigo 1kg', 1.75, 'Dia'),
    (17, 111111111112, 'Mantequilla', 'Mantequilla sin sal 250g', 3.25, 'Mercadona'),
    (18, 333333333334, 'Café', 'Café molido 250g', 4.99, 'Gadis'),
    (19, 888888888889, 'Pescado', 'Filetes de merluza 500g', 8.99, 'Dia'),
    (20, 999999999998, 'Pollo', 'Pechuga de pollo 1kg', 6.5, 'Mercadona');
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
            color: Colors.white, // Texto en blanco para contraste
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white), // Iconos en blanco
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
      Compra(),
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
/*---------------------------------------------------------------------------------------*/