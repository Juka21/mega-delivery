import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'address_screen.dart';
import 'edit_profile_screen.dart';
import 'legal_document_screen.dart';
import 'support_tickets_screen.dart';
import '../services/database_service.dart';

class ProfileScreen extends StatefulWidget {
  final Function(String) onDriverLogin;

  const ProfileScreen({super.key, required this.onDriverLogin});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
        initialData: AuthService().currentUser,
        stream: AuthService().userChanges,
        builder: (context, snapshot) {
          final user = snapshot.data;

          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FD),
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeaderCard(user),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildSectionTitle("ÁREA RESTRITA"),
                      _buildMenuCard([
                        // 1. O Botao do Estafeta (aparece para todos)
                        _buildMenuItem(Icons.motorcycle_rounded, Colors.blue,
                            "Área de Estafeta", "Entrar com PIN", () {
                          _mostrarLoginEstafeta(context);
                        }),

                        // 2. O botao do Admin so aparece se for o chefe.
                        if (user?.role == 'admin') ...[
                          _buildDivider(),
                          _buildMenuItem(
                              Icons.admin_panel_settings,
                              Colors.red,
                              "Painel de Administração",
                              "Gestão do Mega Delivery", () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AdminDashboardScreen()));
                          }),
                        ],
                      ]),
                      const SizedBox(height: 25),
                      _buildSectionTitle("A MINHA CONTA"),
                      _buildMenuCard([
                        _buildMenuItem(
                            Icons.location_on_rounded,
                            Colors.deepOrange,
                            "Minhas Moradas",
                            "Gerir locais de entrega", () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AddressScreen()));
                        }),
                        _buildDivider(),
                        _buildMenuItem(
                            Icons.notifications_active_rounded,
                            Colors.orange,
                            "Notificações",
                            "Alertas de pedidos", () {
                          setState(() =>
                              _notificationsEnabled = !_notificationsEnabled);
                        }, isSwitch: true),
                        _buildDivider(),
                        _buildMenuItem(
                            Icons.download_rounded,
                            Colors.teal,
                            "Exportar os meus dados",
                            "Ver e copiar dados guardados", () {
                          _exportUserData();
                        }),
                      ]),
                      const SizedBox(height: 25),
                      _buildSectionTitle("SUPORTE & LEGAL"),
                      _buildMenuCard([
                        _buildMenuItem(Icons.help_center_rounded, Colors.purple,
                            "Ajuda e Suporte", "Fale connosco", () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const SupportTicketsScreen()));
                        }),
                        _buildDivider(),
                        _buildMenuItem(Icons.policy_rounded, Colors.grey,
                            "Política de Privacidade", null, () {
                          _openLegalDocument(
                            'Politica de Privacidade',
                            LegalDocumentScreen.privacyAsset,
                          );
                        }),
                        _buildDivider(),
                        _buildMenuItem(Icons.description_rounded, Colors.grey,
                            "Termos e Condições", null, () {
                          _openLegalDocument(
                            'Termos e Condicoes',
                            LegalDocumentScreen.termsAsset,
                          );
                        }),
                        _buildDivider(),
                        _buildMenuItem(Icons.info_outline_rounded, Colors.grey,
                            "Alergénios, Reembolsos e Contactos", null, () {
                          _openLegalDocument(
                            'Alergénios, Reembolsos e Contactos',
                            'docs/ALERGENIOS_REEMBOLSOS_CONTACTOS.md',
                          );
                        }),
                      ]),
                      const SizedBox(height: 30),
                      _buildLogoutButton(),
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: () => _confirmDelete(context),
                        child: Text("Apagar conta",
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                                decoration: TextDecoration.underline)),
                      ),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
          );
        });
  }

  void _mostrarLoginEstafeta(BuildContext context) {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Acesso Estafeta"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Insere o teu PIN de 4 dígitos:"),
            const SizedBox(height: 10),
            TextField(
              controller: pinController,
              autofocus: true,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, letterSpacing: 5, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                  hintText: "0000",
                  counterText: "",
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              String pinDigitado = pinController.text;
              if (pinDigitado.length != 4) {
                return; // So avanca se tiver 4 numeros
              }

              try {
                // Agora chama diretamente o Node.js.
                final driver =
                    await DatabaseService().getDriverByPin(pinDigitado);

                if (ctx.mounted) Navigator.pop(ctx); // Fecha a janela do PIN

                if (driver != null) {
                  // PIN CERTO!
                  String driverId = (driver['id'] ?? driver['_id']).toString();

                  widget.onDriverLogin(driverId); // Abre o ecra do estafeta

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Bem-vindo! Modo Estafeta ativado."),
                      backgroundColor: Colors.green,
                    ));
                  }
                } else {
                  // PIN ERRADO
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("PIN incorreto."),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              } catch (e) {
                debugPrint("Erro de ligação: $e");
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Erro a ligar ao servidor."),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            child: const Text("Entrar"),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(AppUser? user) {
    // Logica de nome restaurada para o design original.
    String displayNome = "Visitante";
    String displayEmail = "Sem email";

    if (user != null) {
      if (user.nome.isNotEmpty && user.nome != 'Cliente') {
        displayNome = user.nome;
      } else if (user.email.isNotEmpty) {
        displayNome = user.email.split('@')[0];
      } else {
        displayNome = "Cliente";
      }

      if (user.email.isNotEmpty) {
        displayEmail = user.email;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E272E), Color(0xFF485460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 15, offset: Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.white24, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white,
                  backgroundImage: user?.photoURL.isNotEmpty == true
                      ? NetworkImage(user!.photoURL)
                      : null,
                  child: user?.photoURL.isNotEmpty == true
                      ? null
                      : const Icon(Icons.person, size: 40, color: Colors.grey),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: Colors.blue, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.edit, color: Colors.white, size: 18),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 15),
          Text(
            displayNome,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
            child: Text(
              displayEmail,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10),
      child: Text(title,
          style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2)),
    );
  }

  Widget _buildMenuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(IconData icon, Color color, String title,
      String? subtitle, VoidCallback onTap,
      {bool isSwitch = false}) {
    return ListTile(
      onTap: isSwitch ? null : onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF2D3436))),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]))
          : null,
      trailing: isSwitch
          ? Switch(
              value: _notificationsEnabled,
              activeThumbColor: Colors.green,
              onChanged: (val) => setState(() => _notificationsEnabled = val))
          : const Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: Colors.grey),
    );
  }

  Widget _buildDivider() {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Divider(height: 1, color: Colors.grey[100]));
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.red.withOpacity(0.1))),
        ),
        onPressed: () async {
          await AuthService().signOut();
        },
        child: const Text("Terminar Sessão",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Pedir apagamento da conta?"),
        content: const Text("Esta ação é irreversível."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text("Cancelar")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(c);
                await _requestAccountDeletion();
              },
              child:
                  const Text("Apagar", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Future<void> _exportUserData() async {
    try {
      final data = await DatabaseService().exportCurrentUserData();
      const encoder = JsonEncoder.withIndent('  ');
      final text = encoder.convert(data);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Os meus dados'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dados copiados.')),
                );
              },
              child: const Text('Copiar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel exportar: $e')),
      );
    }
  }

  Future<void> _requestAccountDeletion() async {
    try {
      await DatabaseService().requestAccountDeletion();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido de apagamento registado.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao pedir apagamento: $e')),
      );
    }
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
}
