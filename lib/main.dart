import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/View/gastos.dart';
import 'package:proyectocompras/View/compra.dart';
import 'package:proyectocompras/View/producto.dart';
import 'package:proyectocompras/View/recetas.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Providers/languageProvider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'Providers/themeProvider.dart';

/*---------------------------------------------------------------------------------------*/
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CARGAMOS EL ARCHIVO .env
  await dotenv.load(fileName: ".env");

  // INICIALIZAMOS Supabase CON LAS VARIABLES DE ENTORNO
  await Supabase.initialize(
    url: dotenv.env['PROJECT_URL']!,
    anonKey: dotenv.env['API_KEY']!,
  );

  SupabaseClient database = Supabase.instance.client;

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider())
    ],
    child: MainApp(),
  ));
}

/*---------------------------------------------------------------------------------------*/
class MainApp extends StatelessWidget {


  const MainApp({super.key});

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
      themeMode: context.watch<ThemeProvider>().isDarkMode
          ? ThemeMode.dark
          : ThemeMode.light,
      supportedLocales: const [Locale("es"), Locale("en")],
      locale: context.watch<LanguageProvider>().locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Main()
    );
  }
}

/*---------------------------------------------------------------------------------------*/
class Main extends StatefulWidget {


  const Main({super.key});

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
      Producto(),
      Compra(),
      Gastos(),
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
