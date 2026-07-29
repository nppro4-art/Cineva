import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

enum AuthFormMode { signIn, signUp }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.title, required this.surface});

  final String title;
  final AppSurface surface;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AuthFormMode _mode = AuthFormMode.signIn;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final actionState = ref.watch(loginControllerProvider);

    ref.listen<AsyncValue<void>?>(loginControllerProvider, (previous, next) {
      next?.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
        },
        data: (_) {
          if (previous is AsyncLoading<void>) {
            final message = _mode == AuthFormMode.signUp
                ? 'Compte créé. Vérifiez votre email si la confirmation est activée.'
                : 'Connexion réussie.';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
          }
        },
      );
    });

    return Scaffold(
      body: CinevaScaffoldContainer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                CinevaPageHeader(
                  title: widget.title,
                  subtitle: widget.surface == AppSurface.admin
                      ? 'Connexion administrateur sécurisée'
                      : 'Connectez-vous pour accéder à votre catalogue, vos appareils et vos abonnements.',
                ),
                const SizedBox(height: CinevaSpacing.xl),
                CinevaGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (session != null && !session.supabaseReady) ...<Widget>[
                        CinevaStatusBanner(
                          title: 'Supabase non configuré',
                          message: session.message ?? 'Ajoutez SUPABASE_URL et SUPABASE_ANON_KEY pour activer la connexion réelle.',
                          tone: CinevaBannerTone.warning,
                        ),
                        const SizedBox(height: CinevaSpacing.lg),
                      ],
                      if (_mode == AuthFormMode.signUp) ...<Widget>[
                        CinevaTextField(
                          controller: _fullNameController,
                          label: 'Nom complet',
                          prefixIcon: Icons.person_rounded,
                        ),
                        const SizedBox(height: CinevaSpacing.md),
                      ],
                      CinevaTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'nom@cineva.app',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.mail_outline_rounded,
                      ),
                      const SizedBox(height: CinevaSpacing.md),
                      CinevaTextField(
                        controller: _passwordController,
                        label: 'Mot de passe',
                        obscureText: true,
                        prefixIcon: Icons.lock_outline_rounded,
                      ),
                      const SizedBox(height: CinevaSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: CinevaPrimaryButton(
                          label: _mode == AuthFormMode.signIn ? 'Se connecter' : 'Créer un compte',
                          icon: _mode == AuthFormMode.signIn ? Icons.login_rounded : Icons.person_add_alt_1_rounded,
                          isLoading: actionState is AsyncLoading<void>,
                          onPressed: _submit,
                        ),
                      ),
                      const SizedBox(height: CinevaSpacing.md),
                      TextButton(
                        onPressed: () => setState(() {
                          _mode = _mode == AuthFormMode.signIn ? AuthFormMode.signUp : AuthFormMode.signIn;
                          ref.read(loginControllerProvider.notifier).clear();
                        }),
                        child: Text(
                          _mode == AuthFormMode.signIn
                              ? 'Créer un compte utilisateur'
                              : 'J’ai déjà un compte',
                        ),
                      ),
                      if (_mode == AuthFormMode.signIn)
                        TextButton(
                          onPressed: _resetPassword,
                          child: const Text('Réinitialiser le mot de passe'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final controller = ref.read(loginControllerProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName = _fullNameController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un email valide.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le mot de passe doit contenir au moins 6 caractères.')),
      );
      return;
    }

    if (_mode == AuthFormMode.signIn) {
      await controller.signIn(email: email, password: password);
      return;
    }

    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir votre nom complet.')),
      );
      return;
    }

    await controller.signUp(
      fullName: fullName,
      email: email,
      password: password,
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saisissez votre email.')));
      return;
    }

    await ref.read(loginControllerProvider.notifier).resetPassword(email: email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Si le compte existe, un email de réinitialisation a été envoyé.')),
      );
    }
  }
}
