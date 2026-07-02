import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'legal_document_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const Color _orange = Color(0xFFFF8A00);
  static const Color _ink = Color(0xFF17212B);
  static const Color _surface = Color(0xFFF6F7FB);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _auth = AuthService();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedLegal = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nomeController.dispose();
    _telefoneController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(bool login) {
    if (_isLoading || _isLogin == login) return;
    setState(() {
      _isLogin = login;
      if (login) _acceptedLegal = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin && !_acceptedLegal) {
      _showSnack(
        'Tens de aceitar a politica de privacidade e os termos.',
        Colors.red,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _auth.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await _auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          nome: _nomeController.text.trim(),
          telefone: _telefoneController.text.trim(),
          acceptedLegal: true,
        );
      }

      await _saveMessagingToken();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMessagingToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await DatabaseService().updateUserProfile(
      uid: user.uid,
      dados: {'fcmToken': token},
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithGoogle();
      await _saveMessagingToken();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithApple();
      await _saveMessagingToken();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text);
    bool loadingDialog = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Recuperar password',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Indica o email da tua conta para receberes o link de recuperacao.',
                    style: TextStyle(color: Colors.grey[700], height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      loadingDialog ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: loadingDialog
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          if (!email.contains('@')) return;

                          setStateDialog(() => loadingDialog = true);
                          try {
                            await _auth.forgotPassword(email);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            _showSnack(
                              'Email de recuperacao enviado.',
                              Colors.green,
                            );
                          } catch (e) {
                            _showSnack(
                              e.toString().replaceAll('Exception: ', ''),
                              Colors.red,
                            );
                            setStateDialog(() => loadingDialog = false);
                          }
                        },
                  child: loadingDialog
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
      ),
      validator: validator,
    );
  }

  Widget _buildModeSwitch() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: 'Entrar',
            selected: _isLogin,
            onTap: () => _switchMode(true),
          ),
          _ModeButton(
            label: 'Criar conta',
            selected: !_isLogin,
            onTap: () => _switchMode(false),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Column(
        key: ValueKey(_isLogin),
        children: [
          if (!_isLogin) ...[
            _buildField(
              controller: _nomeController,
              label: 'Nome completo',
              icon: Icons.person_outline_rounded,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Insere o teu nome';
                if (!text.contains(' ')) return 'Insere primeiro e ultimo nome';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _telefoneController,
              label: 'Telemovel',
              icon: Icons.phone_iphone_rounded,
              keyboardType: TextInputType.phone,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Insere o teu telemovel';
                if (text.length < 9) return 'Numero invalido';
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          _buildField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              final text = value?.trim() ?? '';
              if (!text.contains('@')) return 'Email invalido';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            onToggleObscure: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            validator: (value) {
              if ((value ?? '').length < 6) return 'Minimo 6 caracteres';
              return null;
            },
          ),
          if (!_isLogin) ...[
            const SizedBox(height: 14),
            _buildField(
              controller: _confirmPasswordController,
              label: 'Confirmar password',
              icon: Icons.verified_user_outlined,
              obscure: _obscureConfirmPassword,
              onToggleObscure: () {
                setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                );
              },
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'As passwords nao coincidem';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  void _openLegalDocument(String title, String assetPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(
          title: title,
          assetPath: assetPath,
        ),
      ),
    );
  }

  Widget _buildLegalConsent() {
    if (_isLogin) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _acceptedLegal,
            activeColor: _orange,
            onChanged: (value) {
              setState(() => _acceptedLegal = value ?? false);
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Li e aceito a ',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  InkWell(
                    onTap: () => _openLegalDocument(
                      'Política de Privacidade',
                      LegalDocumentScreen.privacyAsset,
                    ),
                    child: const Text(
                      'Política de Privacidade',
                      style: TextStyle(
                        color: _orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Text(
                    ' e os ',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  InkWell(
                    onTap: () => _openLegalDocument(
                      'Termos e Condições',
                      LegalDocumentScreen.termsAsset,
                    ),
                    child: const Text(
                      'Termos e Condições',
                      style: TextStyle(
                        color: _orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Text(
                    '.',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _isLogin ? 'Entrar' : 'Criar conta',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          side: const BorderSide(color: Color(0xFFE0E4EA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: Colors.white,
        ),
        icon: const FaIcon(FontAwesomeIcons.google, size: 18),
        label: const Text(
          'Continuar com Google',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildAppleButton() {
    return FutureBuilder<bool>(
      future: SignInWithApple.isAvailable(),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _signInWithApple,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                backgroundColor: _ink,
              ),
              icon: const FaIcon(FontAwesomeIcons.apple, size: 20),
              label: const Text(
                'Continuar com Apple',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 126,
      height: 126,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/mega_cachorro_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.delivery_dining_rounded,
            color: _orange,
            size: 56,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 42),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildLogo(),
                    const SizedBox(height: 18),
                    const Text(
                      'Mega Delivery',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLogin
                          ? 'Entra para fazer o teu pedido'
                          : 'Cria a tua conta em poucos segundos',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 26,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildModeSwitch(),
                            const SizedBox(height: 18),
                            _buildFormFields(),
                            _buildLegalConsent(),
                            if (_isLogin)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  child: const Text('Esqueci a password'),
                                ),
                              )
                            else
                              const SizedBox(height: 18),
                            _buildSubmitButton(),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    'ou',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _buildGoogleButton(),
                            _buildAppleButton(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _AuthScreenState._ink : Colors.grey[600],
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
