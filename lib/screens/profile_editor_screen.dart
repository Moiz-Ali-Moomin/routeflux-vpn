
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/proxy_profile.dart';
import '../services/preferences_service.dart';

class ProfileEditorScreen extends StatefulWidget {
  final ProxyProfile? profile;

  const ProfileEditorScreen({Key? key, this.profile}) : super(key: key);

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  
  ProxyProtocol _selectedProtocol = ProxyProtocol.http;
  bool _useAuth = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    _hostController = TextEditingController(text: widget.profile?.host ?? '');
    _portController = TextEditingController(text: widget.profile?.port.toString() ?? '');
    _usernameController = TextEditingController(text: widget.profile?.username ?? '');
    _passwordController = TextEditingController(text: widget.profile?.password ?? '');
    
    if (widget.profile != null) {
      _selectedProtocol = widget.profile!.protocol;
      _useAuth = (widget.profile!.username?.isNotEmpty == true);
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final profile = ProxyProfile(
        id: widget.profile?.id ?? const Uuid().v4(),
        name: _nameController.text,
        host: _hostController.text.replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r'^socks5s?://'), ''),
        port: int.parse(_portController.text),
        protocol: _selectedProtocol,
        username: _useAuth ? _usernameController.text.trim() : null,
        password: _useAuth ? _passwordController.text.trim() : null,
        colorValue: widget.profile?.colorValue ?? 0xFF2196F3,
      );

      await PreferencesService().saveProfile(profile);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text(widget.profile == null ? 'Add Proxy' : 'Edit Proxy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Profile name'),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecor('e.g. USA Server'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              _buildSectionTitle('Protocol'),
              DropdownButtonFormField<ProxyProtocol>(
                value: _selectedProtocol,
                decoration: _inputDecor(''),
                items: const [
                  DropdownMenuItem(value: ProxyProtocol.http, child: Text('HTTP')),
                  DropdownMenuItem(value: ProxyProtocol.https, child: Text('HTTP + TLS (HTTPS)')),
                  DropdownMenuItem(value: ProxyProtocol.socks5, child: Text('SOCKS5')),
                  DropdownMenuItem(value: ProxyProtocol.socks5s, child: Text('SOCKS5 + TLS')),
                ],
                onChanged: (v) => setState(() => _selectedProtocol = v!),
              ),
              const SizedBox(height: 16),

              _buildSectionTitle('Server'),
              TextFormField(
                controller: _hostController, // Using standard controller
                decoration: _inputDecor('IP Address or Hostname'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              _buildSectionTitle('Port'),
              TextFormField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: _inputDecor('e.g. 1080'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              // Auth Section
              _buildSectionTitle('Authentication'),
              DropdownButtonFormField<bool>(
                value: _useAuth,
                decoration: _inputDecor('Auth Method'),
                items: const [
                   DropdownMenuItem(value: false, child: Text('None (Public)')),
                   DropdownMenuItem(value: true, child: Text('Username/Password')),
                ],
                onChanged: (v) => setState(() => _useAuth = v!),
              ),
              
              if (_useAuth) ...[
                const SizedBox(height: 16),
                _buildSectionTitle('Username'),
                TextFormField(
                  controller: _usernameController,
                  decoration: _inputDecor('Username'),
                ),
                const SizedBox(height: 8),
                _buildSectionTitle('Password'),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _inputDecor('Password'),
                ),
              ],
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: _save,
                  child: const Text('Save', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
      ),
    );
  }

  InputDecoration _inputDecor(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }
}
