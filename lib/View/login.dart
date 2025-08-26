import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Providers/userProvider.dart';
import '../main.dart';

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
    final password = passwordController.text;

    try {
      // Intentar iniciar sesión
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Si funciona, guardar UUID y continuar
      if (response.user != null) {
        await guardarUUID(response.user!.id);
        context.read<UserProvider>().setUuid(response.user!.id);
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }
    } catch (e) {
      // Si falla, intentar registrar el usuario
      try {
        final signUp = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );

        final user = signUp.user;
        if (user != null) {
          final usuarioUUID = user.id;
          final fechaCreacion = DateTime.now().toIso8601String();

          // Insertar en tabla usuario
          await Supabase.instance.client.from('usuario').insert({
            'usuariouuid': usuarioUUID,
            'nombreusuario': email.split('@').first,
            'correo': email,
            'fechacreacion': fechaCreacion,
          });

          await guardarUUID(usuarioUUID);
          context.read<UserProvider>().setUuid(usuarioUUID);
          Navigator.pushReplacementNamed(context, '/home');
          return;
        }
      } catch (e) {
        setState(() => error = 'Error al registrar: $e');
      }
    }

    setState(() {
      isLoading = false;
      if (error.isEmpty) error = 'Usuario o contraseña incorrectos';
    });
  }

  Future<void> guardarUUID(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('usuarioUUID', uuid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar Sesión o Registrarse')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : loginORegistro,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Entrar / Registrar'),
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
