import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'legal_document_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  final AppUser user;

  const CompleteProfileScreen({super.key, required this.user});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  static const Color _orange = Color(0xFFFF8A00);
  static const Color _ink = Color(0xFF17212B);
  static const Color _surface = Color(0xFFF6F7FB);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final AuthService _auth = AuthService();

  bool _isLoading = false;
  bool _isSendingSms = false;
  bool _acceptedLegal = false;
  String? _verificationId;
  PhoneAuthCredential? _autoPhoneCredential;
  String? _verifiedPhone;

  @override
  void initState() {
    super.initState();
    _nameController.text =
        widget.user.nome == 'Cliente' ? '' : widget.user.nome.trim();
    _phoneController.text = widget.user.telefone;
    if (widget.user.idade != null) {
      _ageController.text = widget.user.idade.toString();
    }
    _phoneController.addListener(_resetPhoneVerificationIfChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_resetPhoneVerificationIfChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  void _resetPhoneVerificationIfChanged() {
    final currentPhone = _phoneController.text.trim();
    if (_verifiedPhone != null && currentPhone != _verifiedPhone) {
      setState(() {
        _verificationId = null;
        _autoPhoneCredential = null;
        _verifiedPhone = null;
        _smsCodeController.clear();
      });
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

  Future<void> _sendSmsCode() async {
    setState(() => _isSendingSms = true);

    try {
      final normalizedPhone =
          _auth.normalizePhoneNumber(_phoneController.text.trim());
      await _auth.sendPhoneVerificationCode(
        phoneNumber: normalizedPhone,
        verificationCompleted: (credential) {
          if (!mounted) return;
          setState(() {
            _autoPhoneCredential = credential;
            _verifiedPhone = normalizedPhone;
          });
          _showSnack('Telemovel verificado automaticamente.', Colors.green);
        },
        verificationFailed: (message) {
          _showSnack(message, Colors.red);
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _verifiedPhone = normalizedPhone;
            _smsCodeController.clear();
          });
          _showSnack('Codigo enviado por SMS.', Colors.green);
        },
      );
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isSendingSms = false);
    }
  }

  PhoneAuthCredential? _buildPhoneCredential() {
    if (_autoPhoneCredential != null) return _autoPhoneCredential;
    final verificationId = _verificationId;
    final smsCode = _smsCodeController.text.trim();
    if (verificationId == null || smsCode.length < 6) return null;
    return _auth.phoneCredentialFromCode(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedLegal) {
      _showSnack(
        'Tens de aceitar a politica de privacidade e os termos.',
        Colors.red,
      );
      return;
    }

    final credential = _buildPhoneCredential();
    if (credential == null) {
      _showSnack(
        'Envia e insere o codigo SMS antes de continuar.',
        Colors.red,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await _auth.completeProfile(
        nome: _nameController.text.trim(),
        telefone: _phoneController.text.trim(),
        idade: _auth.validateAge(_ageController.text),
        phoneCredential: credential,
        acceptedLegal: true,
      );
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }

  Widget _phoneVerificationCard() {
    final codeSent = _verificationId != null || _autoPhoneCredential != null;
    final autoVerified = _autoPhoneCredential != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                autoVerified ? Icons.verified_rounded : Icons.sms_outlined,
                color: autoVerified ? Colors.green : _orange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  autoVerified
                      ? 'Telemovel verificado'
                      : codeSent
                          ? 'Codigo SMS enviado'
                          : 'Verificacao por SMS',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isSendingSms ? null : _sendSmsCode,
                child: Text(codeSent ? 'Reenviar' : 'Enviar'),
              ),
            ],
          ),
          if (!autoVerified) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _smsCodeController,
              enabled: codeSent,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Codigo recebido por SMS',
                counterText: '',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              validator: (value) {
                if (_verificationId == null) {
                  return 'Envia primeiro o codigo SMS';
                }
                if ((value ?? '').trim().length < 6) {
                  return 'Insere o codigo de 6 digitos';
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

  Widget _legalConsent() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withValues(alpha: 0.18)),
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
                      'Politica de Privacidade',
                      LegalDocumentScreen.privacyAsset,
                    ),
                    child: const Text(
                      'Politica de Privacidade',
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
                      'Termos e Condicoes',
                      LegalDocumentScreen.termsAsset,
                    ),
                    child: const Text(
                      'Termos e Condicoes',
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

  Widget _logo() {
    return Container(
      width: 104,
      height: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/mega_cachorro_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.delivery_dining_rounded,
            color: _orange,
            size: 48,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            children: [
              _logo(),
              const SizedBox(height: 18),
              const Text(
                'Completa o perfil',
                style: TextStyle(
                  color: _ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Precisamos destes dados antes de aceitares pedidos e pagamentos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _field(
                        controller: _nameController,
                        label: 'Nome completo',
                        icon: Icons.person_outline_rounded,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return 'Insere o teu nome';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _field(
                        controller: _phoneController,
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
                      _phoneVerificationCard(),
                      const SizedBox(height: 14),
                      _field(
                        controller: _ageController,
                        label: 'Idade',
                        icon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          try {
                            _auth.validateAge(value ?? '');
                            return null;
                          } catch (e) {
                            return e.toString().replaceAll('Exception: ', '');
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _legalConsent(),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _completeProfile,
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
                              : const Text(
                                  'Guardar e continuar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isLoading ? null : _auth.signOut,
                        child: const Text('Sair desta conta'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
