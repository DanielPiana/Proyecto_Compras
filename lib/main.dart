import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:food_manager/Providers/recipe_detail_provider.dart';
import 'package:food_manager/Providers/receipts_provider.dart';
import 'package:food_manager/Providers/recipe_provider.dart';
import 'package:food_manager/Providers/user_provider.dart';
import 'package:food_manager/View/receipts_view.dart';
import 'package:food_manager/View/shopping_list_view.dart';
import 'package:food_manager/View/login_view.dart';
import 'package:food_manager/View/product_view.dart';
import 'package:food_manager/View/recipes_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Providers/shopping_list_provider.dart';
import 'Providers/language_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'Providers/products_provider.dart';
import 'Providers/theme_provider.dart';
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
          ChangeNotifierProvider(create: (_) => RecipeDetailProvider()),
          ChangeNotifierProvider(
            create: (_) => ProductProvider(
              Supabase.instance.client,
              uuid,
            )..loadProducts(),
          ),
          ChangeNotifierProvider(
              create: (_) => ShoppingListProvider(
                Supabase.instance.client,
                uuid,
              )..setUserAndReload(uuid)
          ),
          ChangeNotifierProvider(
              create: (_) => ReceiptProvider(
                Supabase.instance.client,
                uuid,
              )..setUserAndReload(uuid)
          ),
          ChangeNotifierProvider(
              create: (_) => RecipeProvider(
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
          onSurface: Colors.black,
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
            color: Theme.of(context).colorScheme.onSurface
          ),
          hintStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface
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
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF4CAF50),
          titleTextStyle: TextStyle(
            color:Theme.of(context).colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
        ),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4CAF50),
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          surface: Color(0xFF424242),
          onSurface: Colors.white70,
          error: Color(0xFFF44336),
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.onPrimary,
              width: 0.8,
            ),
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
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
          hintStyle: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shadowColor: Theme.of(context).colorScheme.onSecondary,
            side: const BorderSide(
              color: Color(0xFF4CAF50),
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
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF2C6B31),
          titleTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
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
        '/login': (_) => const LoginView(),
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
      // DEBEMOS PASAR A TODAS COMO PARAMETRO LA BASE DE DATOS
      const ProductsView(),
      const ShoppingListView(),
      const ReceiptsView(),
      const RecipesView(),
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
                  style: const TextStyle(color: Colors.black),
                  onChanged: (query) {
                    _onSearchChanged(query);
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.black),
                    hintText: AppLocalizations.of(context)!.search,
                    hintStyle: const TextStyle(color: Colors.black54),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2C6B31) // Tema oscuro
                    : const Color(0xFF4CAF50), // Tema claro
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.menuSettings,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
                title: Text(AppLocalizations.of(context)!.language),
                trailing: DropdownButton(
                    items: language,
                    onChanged: (value) {
                      setState(() {
                        languageSelected =
                            value;
                      });
                      context
                          .read<LanguageProvider>()
                          .setLocale(Locale("$value"));
                    },
                    value:
                    context.watch<LanguageProvider>().locale.languageCode)
            ),
            SwitchListTile(
              title: Text(AppLocalizations.of(context)!.darkTheme),
              value: context.watch<ThemeProvider>().isDarkMode,
              onChanged: (bool value) {
                context.read<ThemeProvider>().toggleTheme();
              },
            ),
            ListTile(
                title: Text(AppLocalizations.of(context)!.logout),
                trailing: IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    // CERRAR SESIÓN
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('usuarioUUID');

                    final userProvider = context.read<UserProvider>();
                    userProvider.setUuid(null);

                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      context.read<ProductProvider>().setUserAndReload(null);
                      context.read<ShoppingListProvider>().setUserAndReload(null);
                      context.read<ReceiptProvider>().setUserAndReload(null);
                      context.read<RecipeProvider>().setUserAndReload(null);
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                ),
            ),
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
            icon: const Icon(Icons.fastfood),
            label: (AppLocalizations.of(context)!.products).toString(),
          ),
          BottomNavigationBarItem(
            // COMPRA
            icon: const Icon(Icons.shopping_cart_outlined),
            label: (AppLocalizations.of(context)!.shoppingList).toString(),
          ),
          BottomNavigationBarItem(
            // GASTOS
            icon: const Icon(Icons.attach_money),
            label: (AppLocalizations.of(context)!.receipt).toString(),
          ),
          BottomNavigationBarItem(
            // RECETAS
            icon: const Icon(Icons.restaurant_menu),
            label: (AppLocalizations.of(context)!.recipes).toString(),
          ),
        ],
        currentIndex: selectedIndex,
        //LLAMAMOS AL METODO Y QUE SE ACTUALICE LA PAGINA A VISUALIZAR
        onTap: _onItemTapped,
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

  void _onSearchChanged(String query) {
    switch (selectedIndex) {
      case 0:
        context.read<ProductProvider>().setSearchText(query);
        break;

      case 1:
        context.read<ShoppingListProvider>().setSearchText(query);
        break;

      case 2:
        context.read<ReceiptProvider>().setSearchText(query);
        break;

      case 3:
        context.read<RecipeProvider>().setSearchText(query);
        break;
    }
  }

}