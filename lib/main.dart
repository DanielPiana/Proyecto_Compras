import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:proyectocompras/Providers/detalleRecetaProvider.dart';
import 'package:proyectocompras/Providers/facturaProvider.dart';
import 'package:proyectocompras/Providers/recetaProvider.dart';
import 'package:proyectocompras/Providers/userProvider.dart';
import 'package:proyectocompras/View/gastos.dart';
import 'package:proyectocompras/View/compra.dart';
import 'package:proyectocompras/View/login.dart';
import 'package:proyectocompras/View/producto.dart';
import 'package:proyectocompras/View/recetas.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Providers/compraProvider.dart';
import 'Providers/languageProvider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'Providers/productoProvider.dart';
import 'Providers/themeProvider.dart';
import 'l10n/app_localizations.dart';

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

  final prefs = await SharedPreferences.getInstance();
  final uuid = prefs.getString('usuarioUUID');

  final userProvider = UserProvider();
  if (uuid != null) {
    userProvider.setUuid(uuid);
  }

  runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider(create: (_) => DetalleRecetaProvider()),
          ChangeNotifierProvider(
            create: (_) => ProductoProvider(
              Supabase.instance.client,
              uuid,
            )..cargarProductos(),
          ),
          ChangeNotifierProvider(
              create: (_) => CompraProvider(
                Supabase.instance.client,
                uuid,
              )..setUserAndReload(uuid)
          ),
          ChangeNotifierProvider(
              create: (_) => FacturaProvider(
                Supabase.instance.client,
                uuid,
              )..setUserAndReload(uuid)
          ),
          ChangeNotifierProvider(
              create: (_) => RecetaProvider(
                Supabase.instance.client,
                uuid,
              )..setUserAndReload(uuid)
          ),
        ],
        child: MainApp(isLoggedIn: uuid != null),
      )
  );
}

/*---------------------------------------------------------------------------------------*/
class MainApp extends StatelessWidget {
  final bool isLoggedIn;

  const MainApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4CAF50),
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          surface: Colors.white,
          onSurface: Colors.black87,
          error: Color(0xFFF44336),
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F8E9),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: Colors.grey[700]!,
              width: 0.8,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xFF4CAF50),
              width: 1.6,
            ),
          ),
          labelStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700]!,
          ),
          hintStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700]!,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shadowColor: Colors.black,
            side: BorderSide(
              color: Colors.grey[700]!,
              width: 0.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4CAF50),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4CAF50),
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white70,
          error: Color(0xFFF44336),
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Colors.white38,
              width: 0.8,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Colors.white54,
              width: 0.8,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xFF4CAF50),
              width: 1.6,
            ),
          ),
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
          hintStyle: const TextStyle(
            fontSize: 14,
            color: Colors.white54,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shadowColor: Colors.black,
            side: const BorderSide(
              color: Colors.white24,
              width: 0.8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2C6B31),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        useMaterial3: true,
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

      initialRoute: isLoggedIn ? '/home' : '/login',
      routes: {
        '/home': (_) => const Main(),
        '/login': (_) => const Login(),
      },
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
      const Producto(),
      const Compra(),
      const Gastos(),
      const Recetas(),
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
      const DropdownMenuItem(
        value: "en",
        child: Text("English"),
      ),
      const DropdownMenuItem(
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
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.logout),
              color: Colors.white,
              onPressed: () async {
                // CERRAR SESIÓN
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('usuarioUUID');

                final userProvider = context.read<UserProvider>();
                userProvider.setUuid(null);

                await Supabase.instance.client.auth.signOut();

                context.read<ProductoProvider>().setUserAndReload(null);
                context.read<CompraProvider>().setUserAndReload(null);
                context.read<FacturaProvider>().setUserAndReload(null);
                context.read<RecetaProvider>().setUserAndReload(null);

                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },

            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(AppLocalizations.of(context)!.menuSettings),
            ),
            ListTile(
                title: Text(AppLocalizations.of(context)!.language),
                trailing: DropdownButton(
                    items: language,
                    onChanged: (value) {

                      setState(() {
                        languageSelected =
                            value;
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
          ],
        ),
      ),
      body: pages[selectedIndex],
      //CARGAMOS LA PAGINA DEPENDIENDO DEL INDICE EN EL QUE HAGAMOS CLICK
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: bottomNavColors["background"],
        selectedItemColor: bottomNavColors["selectedItem"],
        unselectedItemColor: bottomNavColors["unselectedItem"],
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
        onTap: _onItemTapped, //LLAMAMOS AL METODO Y QUE SE ACTUALICE LA PAGINA A VISUALIZAR
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
