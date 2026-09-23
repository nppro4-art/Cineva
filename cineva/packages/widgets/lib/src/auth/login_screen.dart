import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'login_controller.dart';

enum AuthFormMode { signIn, signUp }

/// Connexion / création de compte Cineva.
///
/// Mobile d'abord : wordmark, formulaire sur une surface sombre, bouton
/// principal doré, clavier pris en charge (scroll + insets). Utilisée par les
/// surfaces abonné et admin — mêmes contrôleurs, mêmes validations.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.title, required this.surface});

  final String title;
  final AppSurface surface;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
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
    final SessionSnapshot? session = ref.watch(sessionControllerProvider).valueOrNull;
    final AsyncValue<void>? actionState = ref.watch(loginControllerProvider);
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final bool busy = actionState is AsyncLoading<void>;

    ref.listen<AsyncValue<void>?>(loginControllerProvider, (previous, next) {
      next?.whenOrNull(
        error: (Object error, StackTrace stackTrace) {
          _notify(error.toString());
        },
        data: (_) {
          if (previous is AsyncLoading<void>) {
            _notify(_successMessage());
          }
        },
      );
    });

    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.7),
            radius: 1.25,
            colors: <Color>[Color(0xFF121215), CinevaColors.ink],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                metrics.gutter,
                CinevaSpacing.xl,
                metrics.gutter,
                CinevaSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Center(child: CinevaWordmark()),
                    const SizedBox(height: CinevaSpacing.xs),
                    Center(
                      child: Text(
                        widget.surface == AppSurface.admin
                            ? 'Console d’administration'
                            : 'Le cinéma, sans compromis.',
                        style: CinevaTypography.meta.copyWith(fontSize: 11.5),
                      ),
                    ),
                    const SizedBox(height: CinevaSpacing.xxl),
                    Text(
                      _mode == AuthFormMode.signIn
                          ? 'Bon retour'
                          : 'Créer un compte',
                      style: CinevaTypography.screenTitle.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: CinevaSpacing.xs),
                    Text(
                      widget.surface == AppSurface.admin
                          ? 'Connexion administrateur sécurisée.'
                          : 'Accédez à votre catalogue, vos appareils et votre abonnement.',
                      style: CinevaTypography.bodyCompact,
                    ),
                    const SizedBox(height: CinevaSpacing.xl),

                    if (session != null && !session.supabaseReady) ...<Widget>[
                      CinevaStatusBanner(
                        title: 'Supabase non configuré',
                        message: session.message ??
                            'Ajoutez SUPABASE_URL et SUPABASE_ANON_KEY pour activer la connexion réelle.',
                        tone: CinevaBannerTone.warning,
                      ),
                      const SizedBox(height: CinevaSpacing.lg),
                    ],

                    AnimatedSize(
                      duration: CinevaMotion.medium,
                      curve: CinevaCurve.decelerate,
                      alignment: Alignment.topCenter,
                      child: _mode == AuthFormMode.signUp
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  CinevaTextField(
                                    controller: _fullNameController,
                                    label: 'Nom affiché (facultatif)',
                                    hint: 'Ex. Dupont',
                                    prefixIcon: Icons.badge_outlined,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: CinevaSpacing.xs),
                                  Text(
                                    'Le nom visible dans l’app — pas besoin de '
                                    'votre vrai nom. Vide, c’est votre '
                                    'identifiant qui sera affiché.',
                                    style: CinevaTypography.meta,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    CinevaTextField(
                      controller: _emailController,
                      label: 'Identifiant',
                      hint: 'noah',
                      keyboardType: TextInputType.text,
                      prefixIcon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: CinevaSpacing.xs),
                    Text(
                      'Pas d’email nécessaire : choisissez un identifiant '
                      '(3 à 24 caractères). Une adresse email reste acceptée.',
                      style: CinevaTypography.meta,
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    CinevaTextField(
                      controller: _passwordController,
                      label: 'Mot de passe',
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!busy) _submit();
                      },
                    ),
                    const SizedBox(height: CinevaSpacing.xl),
                    CinevaPlayButton(
                      label: _mode == AuthFormMode.signIn
                          ? 'Se connecter'
                          : 'Créer un compte',
                      icon: _mode == AuthFormMode.signIn
                          ? Icons.login_rounded
                          : Icons.person_add_alt_1_rounded,
                      isLoading: busy,
                      height: 52,
                      onPressed: busy ? null : _submit,
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    Center(
                      child: TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                  _mode = _mode == AuthFormMode.signIn
                                      ? AuthFormMode.signUp
                                      : AuthFormMode.signIn;
                                  ref.read(loginControllerProvider.notifier).clear();
                                }),
                        child: Text(
                          _mode == AuthFormMode.signIn
                              ? 'Créer un compte utilisateur'
                              : 'J’ai déjà un compte',
                          style: CinevaTypography.button.copyWith(
                            fontSize: 12.5,
                            color: CinevaColors.textSoft,
                          ),
                        ),
                      ),
                    ),
                    if (_mode == AuthFormMode.signIn)
                      Center(
                        child: TextButton(
                          onPressed: busy ? null : _resetPassword,
                          child: Text(
                            'Réinitialiser le mot de passe',
                            style: CinevaTypography.button.copyWith(
                              fontSize: 12.5,
                              color: CinevaColors.gold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Message de fin d'action : connexion, inscription ouverte, inscription en
  /// attente de confirmation email.
  String _successMessage() {
    if (_mode != AuthFormMode.signUp) return 'Connexion réussie.';
    final bool sessionOpened =
        ref.read(sessionControllerProvider).valueOrNull?.user != null;
    return sessionOpened
        ? 'Compte créé. Vous êtes connecté avec votre identifiant.'
        : 'Compte créé, mais aucune session n’a été ouverte : la confirmation par '
            'email est activée côté Supabase. Désactivez « Confirm email » '
            '(Authentication → Providers → Email) pour les comptes par identifiant.';
  }

  Future<void> _submit() async {
    final LoginController controller = ref.read(loginControllerProvider.notifier);
    final String password = _passwordController.text;
    final String fullName = _fullNameController.text.trim();

    final String? identifierError =
        CinevaIdentifier.validationError(_emailController.text);
    if (identifierError != null) {
      _notify(identifierError);
      return;
    }
    // Supabase n'authentifie que des adresses email : un identifiant simple est
    // converti en adresse synthétique (jamais envoyée, jamais lue).
    final String email = CinevaIdentifier.toEmail(
      CinevaIdentifier.normalize(_emailController.text),
    );

    if (password.length < 6) {
      _notify('Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }

    if (_mode == AuthFormMode.signIn) {
      await controller.signIn(email: email, password: password);
      return;
    }

    await controller.signUp(
      // Le nom affiché est décoratif : à défaut de choix, c'est l'identifiant
      // qui sert de pseudonyme (jamais l'état civil, qui n'est pas demandé).
      fullName: fullName.isEmpty ? CinevaIdentifier.displayName(email) : fullName,
      email: email,
      password: password,
    );
  }

  Future<void> _resetPassword() async {
    final String? identifierError =
        CinevaIdentifier.validationError(_emailController.text);
    if (identifierError != null) {
      _notify(identifierError);
      return;
    }
    final String email = CinevaIdentifier.toEmail(
      CinevaIdentifier.normalize(_emailController.text),
    );

    if (CinevaIdentifier.isSyntheticEmail(email)) {
      // Aucune boîte aux lettres derrière un identifiant : envoyer un email de
      // réinitialisation ne servirait à rien. On dit la vérité et on oriente.
      _notify(
        'Un compte par identifiant ne reçoit pas d’email. Contactez le '
        '${CinevaOffer.contactName} au ${CinevaOffer.supportPhoneDisplay} pour '
        'réinitialiser le mot de passe.',
      );
      return;
    }

    await ref.read(loginControllerProvider.notifier).resetPassword(email: email);
    _notify('Si le compte existe, un email de réinitialisation a été envoyé.');
  }
}
