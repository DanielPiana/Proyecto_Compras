import 'package:flutter/material.dart';
import 'package:proyectocompras/gastos.dart';
import 'package:proyectocompras/compra.dart';
import 'package:proyectocompras/producto.dart';
import 'package:proyectocompras/recetas.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'ThemeProvider.dart';
import 'languageProvider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/*---------------------------------------------------------------------------------------*/
void main() async {
  // INICIALIZAR SQLITE PARA APLICACIONES DE ESCRITORIO.
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  // CONFIGURAR RUTA DE LA BASE DE DATOS.
  final dbPath =
      join(await databaseFactory.getDatabasesPath(), 'gestioncompras.db');
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
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider())
    ],
    child: MainApp(database: database),
  ));
}

/*---------------------------------------------------------------------------------------*/
class MainApp extends StatelessWidget {
  final Database database;

  const MainApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF1F8E9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4CAF50),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF303030),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2C6B31),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      themeMode: context.watch<ThemeProvider>().isDarkMode ? ThemeMode.dark : ThemeMode.light,
      supportedLocales: const [Locale("es"), Locale("en")],
      locale: context.watch<LanguageProvider>().locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Main(database: database),
    );
  }
}
/*---------------------------------------------------------------------------------------*/
class Main extends StatefulWidget {
  final Database database;

  const Main({super.key, required this.database});

  @override
  State<Main> createState() => MainState();
}

/*---------------------------------------------------------------------------------------*/
class MainState extends State<Main> {
  late List<Widget> pages; // LISTA CON LAS DIFERENTES PAGINAS

  int selectedIndex = 0; // VARIABLE PARA EL INDICE DEL BottomNavigationBar

  @override //INICIALIZADOR
  void initState() {
    super.initState();
    // INICIALIZAMOS LAS PAGINAS AQUI, PARA QUE NO DE ERROR EL WIDGET.DATABASE
    pages = [
      //DEBEMOS PASAR A TODAS COMO PARAMETRO LA BASE DE DATOS
      Producto(database: widget.database),
      Compra(database: widget.database),
      Gastos(database: widget.database),
      Recetas(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // CREAMOS LA VARIABLE AQUI, PORQUE COMO VA A TENER UN .watch NECESITA ESTAR DENTRO DE UN build.
    final bottomNavColors = context.watch<ThemeProvider>().isDarkMode
        ? {
            "background": const Color(0xFF424242),
            "selectedItem": const Color(0xFF81C784),
            "unselectedItem": const Color(0xFF757575),
          }
        : {
            "background": const Color(0xFFE8F5E9),
            "selectedItem": const Color(0xFF388E3C),
            "unselectedItem": const Color(0xFFA5D6A7),
          };

    String languageSelected = "en";

    List<DropdownMenuItem> language = [
      DropdownMenuItem(
        value: "en",
        child: Text("English"),
      ),
      DropdownMenuItem(
        value: "es",
        child: Text("Español"),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: (AppLocalizations.of(context)!.search),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(AppLocalizations.of(context)!.menuSettings),
            ),
            ListTile(
                title: Text(AppLocalizations.of(context)!.language),
                trailing: DropdownButton(
                    items: language, // Lista de opciones para el dropdownButton
                    onChanged: (value) {
                      //es te value es el valor que vas a cambiar
                      setState(() {
                        languageSelected =
                            value; // cambiamos el valor de languageSelected al valor seleccionado en el dropdownbutton
                        print(languageSelected);
                      });
                      context
                          .read<LanguageProvider>()
                          .setLocale(Locale("$value"));
                    },
                    value:
                        context.watch<LanguageProvider>().locale.languageCode)),
            SwitchListTile(
              title: Text(AppLocalizations.of(context)!.darkTheme),
              value: context.watch<ThemeProvider>().isDarkMode,
              onChanged: (bool value) {
                context.read<ThemeProvider>().toggleTheme();
              },
            )
            // Añade más opciones según sea necesario
          ],
        ),
      ),
      body: pages[selectedIndex],
      //CARGAMOS LA PAGINA DEPENDIENDO DEL INDICE EN EL QUE HAGAMOS CLICK
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: bottomNavColors["background"],
        // Usar el color de fondo de acuerdo al modo
        selectedItemColor: bottomNavColors["selectedItem"],
        // Usar el color para el ítem seleccionado
        unselectedItemColor: bottomNavColors["unselectedItem"],
        // Usar el color para los ítems no seleccionados
        items: [
          BottomNavigationBarItem(
            // PRODUCTOS
            icon: Icon(Icons.fastfood),
            label: (AppLocalizations.of(context)!.products).toString(),
          ),
          BottomNavigationBarItem(
            // COMPRA
            icon: Icon(Icons.shopping_cart_outlined),
            label: (AppLocalizations.of(context)!.shoppingList).toString(),
          ),
          BottomNavigationBarItem(
            // GASTOS
            icon: Icon(Icons.attach_money),
            label: (AppLocalizations.of(context)!.receipt).toString(),
          ),
          BottomNavigationBarItem(
            // RECETAS
            icon: Icon(Icons.restaurant_menu),
            label: (AppLocalizations.of(context)!.recipes).toString(),
          ),
        ],
        currentIndex: selectedIndex,
        // INDICE EN EL QUE HACEMOS CLICK
        onTap:
            _onItemTapped, //LLAMAMOS AL METODO Y QUE SE ACTUALICE LA PAGINA A VISUALIZAR
      ),
    );
  }

  /*---------------------------------------------------------------------------------------*/
  // METODO PARA CAMBIAR LA PAGINA SELECCIONADA CON EL INDEX DEL BottomNavigationBar
  void _onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }
} /*---------------------------------------------------------------------------------------*/
