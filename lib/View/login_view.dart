import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Providers/shopping_list_provider.dart';
import '../Providers/receipts_provider.dart';
import '../Providers/products_provider.dart';
import '../Providers/recipe_provider.dart';
import '../Providers/user_provider.dart';
import '../Widgets/awesome_snackbar.dart';
import '../l10n/app_localizations.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart' as asc;

import '../utils/regex.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginView> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLoading = false;
  String error = '';
  bool isRegistering = false;

  // Estados para validación
  bool emailTouched = false;
  bool passwordTouched = false;
  bool confirmPasswordTouched = false;

  bool validEmail = false;
  bool validPassword = false;
  bool validConfirmPassword = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------- LOGIN ----------
  Future<void> login() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _setupUserSession(response.user!.id);
        if (!mounted) return;

        showAwesomeSnackBar(
          context,
          title: AppLocalizations.of(context)!.success,
          message: AppLocalizations.of(context)!.login_try_ok,
          contentType: asc.ContentType.success,
        );

        Navigator.pushReplacementNamed(context, '/home');
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      if (e.message.contains("Invalid login credentials")) {
        showAwesomeSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: AppLocalizations.of(context)!.login_try_error,
          contentType: asc.ContentType.failure,
        );
        // IRRELEVANTE SI NO AÑADO CONFIRMACION DE EMAIL
      } else if (e.message.contains("Email not confirmed")) {
        showAwesomeSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: AppLocalizations.of(context)!.confirm_email,
          contentType: asc.ContentType.warning,
        );
      } else {
        showAwesomeSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: e.message,
          contentType: asc.ContentType.failure,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.error,
        message: AppLocalizations.of(context)!.unknown_error,
        contentType: asc.ContentType.failure,
      );
      print("Error en login: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------- REGISTRO ----------
  Future<void> register() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      final signUp = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (signUp.user != null) {
        final userUuid = signUp.user!.id;
        final creationDate = DateTime.now().toIso8601String();

        await Supabase.instance.client.from('usuario').insert({
          'usuariouuid': userUuid,
          'nombreusuario': email.split('@').first,
          'correo': email,
          'fechacreacion': creationDate,
        });

        await _setupUserSession(userUuid);
        if (!mounted) return;

        showAwesomeSnackBar(
          context,
          title: AppLocalizations.of(context)!.success,
          message: AppLocalizations.of(context)!.register_try_ok,
          contentType: asc.ContentType.success,
        );

        Navigator.pushReplacementNamed(context, '/home');
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      if (e.message.contains("User already registered")) {
        showAwesomeSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: AppLocalizations.of(context)!.register_registered_email,
          contentType: asc.ContentType.failure,
        );
      } else if (e.message.contains("Password should be at least")) {
        showAwesomeSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: AppLocalizations.of(context)!.password_short_error,
          contentType: asc.ContentType.failure,
        );
      } else {
        showAwesomeSnackBar(
          context,
          title: AppLocalizations.of(context)!.error,
          message: e.message,
          contentType: asc.ContentType.failure,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAwesomeSnackBar(
        context,
        title: AppLocalizations.of(context)!.error,
        message: '${AppLocalizations.of(context)!.register_try_error} $e',
        contentType: asc.ContentType.failure,
      );
      print("Error en registro: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _setupUserSession(String uuid) async {
    await saveUuid(uuid);
    if (!mounted) return;

    context.read<UserProvider>().setUuid(uuid);
    await context.read<ProductProvider>().setUserAndReload(uuid);
    await context.read<ShoppingListProvider>().setUserAndReload(uuid);
    await context.read<ReceiptProvider>().setUserAndReload(uuid);
    await context.read<RecipeProvider>().setUserAndReload(uuid);
  }

  Future<void> saveUuid(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('usuarioUUID', uuid);
  }

  // ---------- INTERFAZ ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isRegistering
            ? AppLocalizations.of(context)!.register
            : AppLocalizations.of(context)!.login),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRegistering ? Icons.person_add : Icons.login,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 40),

              // EMAIL
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.mail,
                  prefixIcon: const Icon(Icons.email),
                  suffixIcon: emailTouched
                      ? (validEmail
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.cancel, color: Colors.red))
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    emailTouched = true;
                    validEmail = emailRegex.hasMatch(value.trim());
                  });
                },
              ),
              if (emailTouched && !validEmail)
                Text(AppLocalizations.of(context)!.invalid_email,
                    style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),

              // PASSWORD
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.password,
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: passwordTouched
                      ? (validPassword
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.cancel, color: Colors.red))
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    passwordTouched = true;
                    validPassword = value.trim().length >= 6;
                    if (isRegistering && confirmPasswordTouched) {
                      validConfirmPassword =
                          value.trim() == confirmPasswordController.text.trim();
                    }
                  });
                },
              ),
              if (passwordTouched && !validPassword)
                Text(AppLocalizations.of(context)!.password_short_error,
                    style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),

              // CONFIRMAR CONTRASEÑA
              if (isRegistering) ...[
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.confirm_password,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: confirmPasswordTouched
                        ? (validConfirmPassword
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : const Icon(Icons.cancel, color: Colors.red))
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      confirmPasswordTouched = true;
                      validConfirmPassword =
                          value.trim() == passwordController.text.trim();
                    });
                  },
                ),
                if (confirmPasswordTouched && !validConfirmPassword)
                  Text(AppLocalizations.of(context)!.password_matching_error,
                      style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 24),
              ],

              // BOTÓN PRINCIPAL
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isRegistering
                              ? AppLocalizations.of(context)!.register
                              : AppLocalizations.of(context)!.login,
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // CAMBIO DE MODO
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isRegistering
                      ? AppLocalizations.of(context)!.have_an_account
                      : AppLocalizations.of(context)!.dont_have_an_account),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isRegistering = !isRegistering;
                        error = '';
                        confirmPasswordController.clear();
                        emailTouched =
                            passwordTouched = confirmPasswordTouched = false;
                      });
                    },
                    child: Text(
                      isRegistering
                          ? AppLocalizations.of(context)!.login
                          : AppLocalizations.of(context)!.register,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- VALIDAR Y ENVIAR ----------
  Future<void> _handleSubmit() async {
    if (!validEmail || !validPassword) {
      setState(() {
        error = AppLocalizations.of(context)!.fill_fields_correctly;
      });
      return;
    }

    if (isRegistering) {
      if (!validConfirmPassword) {
        setState(() {
          error = AppLocalizations.of(context)!.password_matching_error;
        });
        return;
      }
      await register();
    } else {
      await login();
    }
  }
}
