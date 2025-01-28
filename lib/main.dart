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
   await database.execute('DROP TABLE IF EXISTS compra');

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
  precioUnidad REAL,
  total REAL,
  FOREIGN KEY (idProducto) REFERENCES productos(id),
  FOREIGN KEY (idFactura) REFERENCES facturas(id)
);
CREATE TABLE IF NOT EXISTS compra (
  idProducto INTEGER,
  nombre TEXT,
  precio REAL,
  marcado INTEGER DEFAULT 0,
  cantidad INTEGER DEFAULT 1,
  total REAL,
  FOREIGN KEY (idProducto) REFERENCES productos(id)
);
INSERT INTO productos (id, codBarras, nombre, descripcion, precio, supermercado)
VALUES
(1, 123456, 'Manzanas', 'Manzanas rojas frescas', 1.50, 'Supermercado A'),
(2, 234567, 'Leche', 'Leche entera de vaca', 0.90, 'Supermercado B'),
(3, 345678, 'Pan', 'Pan de molde integral', 1.20, 'Supermercado A'),
(4, 456789, 'Huevos', 'Huevos frescos de granja', 2.30, 'Supermercado C');

INSERT INTO facturas (id, precio, fecha, supermercado)
VALUES
(1, 3.90, '01/01/2025', 'Supermercado A'),
(2, 7.50, '05/01/2025', 'Supermercado C');

-- Insertar productos en facturas
INSERT INTO producto_factura (idProducto, idFactura, cantidad, precioUnidad, total)
VALUES
(1, 1, 2, 1.50, 3.00), -- 2 Manzanas en factura 1, 1.50 cada una, total 3.00
(2, 1, 1, 0.90, 0.90), -- 1 Leche en factura 1, 0.90 cada una, total 0.90
(3, 2, 3, 1.20, 3.60), -- 3 Panes en factura 2, 1.20 cada uno, total 3.60
(4, 2, 1, 2.30, 2.30); -- 1 Huevos en factura 2, 2.30 cada uno, total 2.30

-- Insertar productos en la lista de compra
INSERT INTO compra (idProducto, nombre, precio, marcado, cantidad, total)
VALUES
(1, 'Manzanas', 1.50, 1, 2, 3.00), -- 2 Manzanas marcadas, total 3.00
(2, 'Leche', 0.90, 0, 1, 0.90),    -- 1 Leche no marcada, total 0.90
(3, 'Pan', 1.20, 1, 3, 3.60),     -- 3 Panes marcados, total 3.60
(4, 'Huevos', 2.30, 0, 1, 2.30);  -- 1 Huevos no marcado, total 2.30
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
        scaffoldBackgroundColor: const Color(0xFFF1F8E9), // FONDO DEL SCAFFOLD GLOBAL (BODY)
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4CAF50), // VERDE PRINCIPAL DEL AppBar
          titleTextStyle: TextStyle(
            color: Colors.white, //COLOR DEL TITULO DEL AppBar
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white), //COLOR ICONO CREAR FACTURA, DENTRO DEL AppBar
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
  late List<Widget> pages; // LISTA CON LAS DIFERENTES PAGINAS

  int _selectedIndex = 0; // VARIABLE PARA EL INDICE DEL BottomNavigationBar

  @override //INICIALIZADOR
  void initState() {
    super.initState();

    // INICIALIZAMOS LAS PAGINAS AQUI, PARA QUE NO DE ERROR EL WIDGET.DATABASE
     pages = [ //DEBEMOS PASAR A TODAS COMO PARAMETRO LA BASE DE DATOS
      Producto(database: widget.database),
      Compra(database: widget.database),
      Gastos(database: widget.database),
      Recetas(),
    ];
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            IconButton( //ICONO MENU HAMBURGUESA
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                debugPrint('Hacer layout de menu');
              },
            ),
            Expanded( //PERSONALIZACION DE LA BARRA DE BUSQUEDA
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            IconButton( // ICONO DE SETTINGS
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                debugPrint('Abrir layout/ventana de ajustes');
              },
            ),
          ],
        ),
      ),
      body: pages[_selectedIndex], //CARGAMOS LA PAGINA DEPENDIENDO DEL INDICE EN EL QUE HAGAMOS CLICK
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFE8F5E9), // FONDO DEL BottomNavigationBar
        selectedItemColor: const Color(0xFF388E3C), // COLOR PARA EL ITEM SELECCIONADO
        unselectedItemColor: const Color(0xFFA5D6A7), // COLOR PARA LOS NO SELECCIONADOS
        items: const [
          BottomNavigationBarItem( // PRODUCTOS
            icon: Icon(Icons.fastfood),
            label: "Productos",
          ),
          BottomNavigationBarItem( // COMPRA
            icon: Icon(Icons.shopping_cart_outlined),
            label: "Compra",
          ),
          BottomNavigationBarItem( // GASTOS
            icon: Icon(Icons.attach_money),
            label: "Gastos",
          ),
          BottomNavigationBarItem(// RECETAS
            icon: Icon(Icons.restaurant_menu),
            label: "Recetas",
          ),
        ],
        currentIndex: _selectedIndex, // INDICE EN EL QUE HACEMOS CLICK
        onTap: _onItemTapped, //LLAMAMOS AL METODO Y QUE SE ACTUALICE LA PAGINA A VISUALIZAR
      ),
    );
  }
  /*---------------------------------------------------------------------------------------*/
  // METODO PARA CAMBIAR LA PAGINA SELECCIONADA CON EL INDEX DEL BottomNavigationBar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
/*---------------------------------------------------------------------------------------*/