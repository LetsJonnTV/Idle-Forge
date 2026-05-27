import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Login / Register screen shown on first launch or after logout.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onLoggedIn,
    required this.onSkip,
  });

  final VoidCallback onLoggedIn;
  final VoidCallback onSkip;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _errorMessage = null);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _bg =>
      _isDark ? const Color(0xFF191919) : const Color(0xFFF4F4F4);

  Color get _cardBg =>
      _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF);

  Color get _accent => const Color(0xFFD4A84B);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final isLogin = _tabController.index == 0;

    try {
      final success = isLogin
          ? await ApiService.instance.login(username, password)
          : await ApiService.instance.register(username, password);

      if (!mounted) return;

      if (success) {
        widget.onLoggedIn();
      } else {
        setState(() => _errorMessage = 'Unexpected error. Please try again.');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.isOffline
            ? 'No internet connection.'
            : (e.message.isNotEmpty ? e.message : 'Login failed.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unexpected error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Title
                  Column(
                    children: [
                      Icon(
                        Icons.construction_rounded,
                        size: 64,
                        color: _accent,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'IDLE FORGE',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: _isDark
                              ? const Color(0xFFE2E2E2)
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Online Account',
                        style: TextStyle(
                          fontSize: 13,
                          color: _isDark
                              ? const Color(0xFF888888)
                              : const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Card
                  Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isDark
                            ? const Color(0xFF3B3B3B)
                            : const Color(0xFFDDDDDD),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Tabs
                        TabBar(
                          controller: _tabController,
                          indicatorColor: _accent,
                          labelColor: _accent,
                          unselectedLabelColor: _isDark
                              ? const Color(0xFF888888)
                              : const Color(0xFF666666),
                          tabs: const [
                            Tab(text: 'Login'),
                            Tab(text: 'Register'),
                          ],
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Username
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: InputDecoration(
                                    labelText: 'Username',
                                    prefixIcon: const Icon(Icons.person_outline),
                                    filled: true,
                                    fillColor: _isDark
                                        ? const Color(0xFF252525)
                                        : const Color(0xFFF0F0F0),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  validator: (v) {
                                    if (v == null || v.trim().length < 3) {
                                      return 'Min. 3 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon:
                                        const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscurePassword =
                                              !_obscurePassword),
                                    ),
                                    filled: true,
                                    fillColor: _isDark
                                        ? const Color(0xFF252525)
                                        : const Color(0xFFF0F0F0),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: (v) {
                                    if (v == null || v.length < 6) {
                                      return 'Min. 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),

                                // Error
                                if (_errorMessage != null)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFFE07070),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 4),

                                // Submit
                                FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _tabController.index == 0
                                              ? 'Login'
                                              : 'Create Account',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Skip
                  TextButton.icon(
                    onPressed: widget.onSkip,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play without account'),
                    style: TextButton.styleFrom(
                      foregroundColor: _isDark
                          ? const Color(0xFF888888)
                          : const Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Online features (leaderboard, friends, PVP, coop)\nrequire an account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isDark
                          ? const Color(0xFF666666)
                          : const Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
