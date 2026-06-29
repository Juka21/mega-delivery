import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import '../services/auth_service.dart';
import '../services/database_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService db = DatabaseService();
  
  // Pega o utilizador atual do Firebase Auth/Firestore.
  final AppUser? user = AuthService().currentUser;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();

  File? _imageFile; 
  bool _isLoading = false;
  String? _currentPhotoUrl; 

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    if (user != null) {
      _nameCtrl.text = user!.nome;
      _emailCtrl.text = user!.email;
      _currentPhotoUrl = user!.photoURL;
      // Assume que o teu AppUser agora tem o campo telefone
      _phoneCtrl.text = user!.telefone; 
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 50);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao escolher imagem: $e")));
    }
    if(mounted) Navigator.pop(context); 
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Alterar Foto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Tirar Foto'),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Escolher da Galeria'),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      String? finalPhotoUrl = _currentPhotoUrl;

      // Upload de imagem via Firebase Storage.
      if (_imageFile != null) {
        finalPhotoUrl = await db.uploadImage(_imageFile!);
      }

      // Atualiza os dados no Firestore.
      final sucesso = await db.updateUserProfile(
        uid: user!.uid,
        dados: {
          'nome': _nameCtrl.text.trim(),
          'telefone': _phoneCtrl.text.trim(),
          'photoURL': finalPhotoUrl,
        },
      );

      if (sucesso && mounted) {
        // Atualiza os dados locais no AuthService para o resto da app saber
        await AuthService().refreshUser(); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perfil atualizado com sucesso! ✅")),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider bgImage;
    if (_imageFile != null) {
      bgImage = FileImage(_imageFile!); 
    } else if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      bgImage = NetworkImage(_currentPhotoUrl!); 
    } else {
      bgImage = const AssetImage('assets/icon/icon.png'); 
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        appBar: AppBar(
          title: const Text("Editar Perfil", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black), onPressed: () => Navigator.pop(context)),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildAvatarSection(bgImage),
                    const SizedBox(height: 40),
                    _buildTextField(controller: _nameCtrl, label: "Nome Completo", icon: Icons.person_outline),
                    const SizedBox(height: 20),
                    _buildTextField(controller: _phoneCtrl, label: "Telemóvel", icon: Icons.phone_android, keyboardType: TextInputType.phone),
                    const SizedBox(height: 20),
                    _buildTextField(controller: _emailCtrl, label: "Email (Fixo)", icon: Icons.email_outlined, isReadOnly: true),
                    const SizedBox(height: 40),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection(ImageProvider bgImage) {
    return Center(
      child: GestureDetector(
        onTap: _isLoading ? null : () => _showImageSourceActionSheet(context),
        child: Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: bgImage,
              backgroundColor: Colors.grey[200],
            ),
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: _isLoading ? null : _saveProfile,
        child: const Text("GUARDAR ALTERAÇÕES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isReadOnly = false, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller, readOnly: isReadOnly, keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, color: isReadOnly ? Colors.grey : Colors.blueAccent),
        filled: true, fillColor: isReadOnly ? Colors.grey[100] : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}
