import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/compraProvider.dart';
import '../Providers/facturaProvider.dart';
import '../Providers/productoProvider.dart';
import '../Providers/recetaProvider.dart';
import '../Providers/userProvider.dart';
import '../Widgets/awesomeSnackbar.dart';
import '../l10n/app_localizations.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<Login> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  String error = '';

  Future<void> loginORegistro() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      // INTENTO DE INICIO DE SESION
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // SI FUNCIONA, GUARDAMOS USUARIO
      if (response.user != null) {
        final uid = response.user!.id;

        await guardarUUID(uid);
        context.read<UserProvider>().setUuid(uid);

        // RECARGAMOS LOS PROVIDERS
        await context.read<ProductoProvider>().setUserAndReload(uid);
        await context.read<CompraProvider>().setUserAndReload(uid);
        await context.read<FacturaProvider>().setUserAndReload(uid);
        await context.read<RecetaProvider>().setUserAndReload(uid);

        if (!mounted) return;

        showAwesomeSnackBar(
          context,
          title: AppLocalizations.of(context)!.success,
          message: AppLocalizations.of(context)!.login_try_ok,
          contentType: asc.ContentType.success,
        );

        Navigator.pushReplacementNamed(context, '/home');
        return;
      }
    } catch (e) {
      final errorMsg = e.toString();

      if (errorMsg.contains("Invalid login credentials")) {
        // EL CORREO EXISTE PERO LA CONTRASEÑA NO COINCIDE
        if (mounted) {
          showAwesomeSnackBar(
            context,
            title: AppLocalizations.of(context)!.error,
            message: AppLocalizations.of(context)!.login_try_error,
            contentType: asc.ContentType.failure,
          );
        }
      } else if (errorMsg.contains("User not found") ||
          errorMsg.contains("Email not confirmed") ||
          errorMsg.contains("Invalid login credentials")) {
        // INTENTAMOS REGISTRAR SI EL USUARIO NO EXISTE
        try {
          final signUp = await Supabase.instance.client.auth.signUp(
            email: email,
            password: password,
          );

          final user = signUp.user;

          if (user != null) {
            final usuarioUUID = user.id;
            final fechaCreacion = DateTime.now().toIso8601String();

            // INSERTAMOS EL USUARIO
            await Supabase.instance.client.from('usuario').insert({
              'usuariouuid': usuarioUUID,
              'nombreusuario': email.split('@').first,
              'correo': email,
              'fechacreacion': fechaCreacion,
            });

            // ESTABLECEMOS EL USUARIO LOGEADO Y RESETEAMOS PROVEEDORES
            await guardarUUID(usuarioUUID);
            context.read<UserProvider>().setUuid(usuarioUUID);

            if (mounted) {
              showAwesomeSnackBar(
                context,
                title: AppLocalizations.of(context)!.success,
                message: AppLocalizations.of(context)!.register_try_ok,
                contentType: asc.ContentType.success,
              );
            }

            // LE MANDAMOS A LA PESTAÑA PRINCIPAL
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/home');
            return;
          }
        } catch (signupError) {
          // ERROR AL REGISTRAR
          if (mounted) {
            showAwesomeSnackBar(
              context,
              title: AppLocalizations.of(context)!.error,
              message:
              '${AppLocalizations.of(context)!.register_try_error} $signupError',
              contentType: asc.ContentType.failure,
            );
          }
        }
      } else {
        // ERROR GENÉRICO
        if (mounted) {
          showAwesomeSnackBar(
            context,
            title: AppLocalizations.of(context)!.error,
            message: AppLocalizations.of(context)!.unknown_error,
            contentType: asc.ContentType.failure,
          );
          print("Error: $errorMsg");
        }
      }
    }

    setState(() {
      isLoading = false;
    });
  }



  Future<void> guardarUUID(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('usuarioUUID', uuid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:Text(AppLocalizations.of(context)!.register_or_login)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.mail),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.password),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : loginORegistro,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : Text(AppLocalizations.of(context)!.login_register),
            ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(error, style: const TextStyle(color: Colors.red)),
            ]
          ],
        ),
      ),
    );
  }
}
