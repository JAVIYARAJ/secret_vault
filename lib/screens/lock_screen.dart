import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import 'home_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _submit(bool hasMasterPassword) {
    if (_passwordController.text.isEmpty) return;
    if (hasMasterPassword) {
      context.read<AuthBloc>().add(UnlockVault(_passwordController.text));
    } else {
      context.read<AuthBloc>().add(SetMasterPassword(_passwordController.text));
    }
  }


  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
        if (state is AuthUnlocked) {
          AppToast.show(
            context,
            message: 'Vault unlocked successfully',
            type: ToastType.success,
          );
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const HomeScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        } else if (state is AuthError) {
          AppToast.show(
            context,
            message: state.message,
            type: ToastType.error,
          );
        }
      },
    ),
  ],
  child: Scaffold(
    backgroundColor: colors.background,
        body: Stack(
          children: [
            // Background glow orbs
            Positioned(
              top: -120,
              left: -80,
              child: _GlowOrb(color: colors.accent.withValues(alpha: 0.18), size: 420),
            ),
            Positioned(
              bottom: -100,
              right: -60,
              child: _GlowOrb(color: const Color(0xFF00D8FF).withValues(alpha: 0.10), size: 360),
            ),
            // Content
            Center(
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        if (state is AuthInitial) {
                          return const CircularProgressIndicator();
                        }
                        final hasMasterPassword = state is AuthLocked
                            ? state.hasMasterPassword
                            : true;
                            
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.card.withValues(alpha: 0.85)
                                    : Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: colors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.accent.withValues(alpha: 0.08),
                                    blurRadius: 60,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Shield icon with glow
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          colors.accent,
                                          const Color(0xFF00D8FF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.accentGlow,
                                          blurRadius: 24,
                                          spreadRadius: 4,
                                        )
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.shield_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Text(
                                    hasMasterPassword ? 'Welcome Back' : 'Create Vault',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    hasMasterPassword
                                        ? 'Enter your master password to unlock'
                                        : 'Set a strong master password.\nThis cannot be recovered if lost.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                  ),
                                  const SizedBox(height: 36),
                                  // Password field
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: _obscureText,
                                    onSubmitted: (_) => _submit(hasMasterPassword),
                                    style: const TextStyle(fontSize: 16, letterSpacing: 1),
                                    decoration: InputDecoration(
                                      labelText: 'Master Password',
                                      prefixIcon: Icon(Icons.lock_outline_rounded,
                                          color: colors.accent),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureText
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                        onPressed: () =>
                                            setState(() => _obscureText = !_obscureText),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // CTA button
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 52,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [colors.accent, const Color(0xFF9C27B0)],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              ),
                                              borderRadius: BorderRadius.circular(14),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: colors.accentGlow,
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                              ),
                                              onPressed: () => _submit(hasMasterPassword),
                                              child: Text(
                                                hasMasterPassword ? 'Unlock Vault' : 'Create & Unlock',
                                                style: const TextStyle(
                                                    fontSize: 16, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: const SizedBox.expand(),
      ),
    );
  }
}
