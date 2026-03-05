
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/proxy_profile.dart';
import '../services/preferences_service.dart';
import '../vpn_channel.dart';
import 'profile_editor_screen.dart';

class ProfileListScreen extends StatefulWidget {
  const ProfileListScreen({Key? key}) : super(key: key);

  @override
  State<ProfileListScreen> createState() => _ProfileListScreenState();
}

class _ProfileListScreenState extends State<ProfileListScreen> {
  final _prefs = PreferencesService();
  List<ProxyProfile> _profiles = [];
  String? _selectedId;
  bool _isConnected = false;
  bool _isConnecting = false;
  StreamSubscription<String>? _vpnStatusSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _vpnStatusSub = VpnChannel.statusStream.listen(_onVpnStatus);
  }

  @override
  void dispose() {
    _vpnStatusSub?.cancel();
    super.dispose();
  }

  void _onVpnStatus(String status) {
    if (!mounted) return;

    if (status == "connected") {
      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
    } else if (status == "disconnected") {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
    } else if (status.startsWith("error:")) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status.substring(6))),
      );
    }
  }

  void _loadData() async {
    final profiles = await _prefs.getProfiles();
    final selected = await _prefs.getSelectedProfileId();
    setState(() {
      _profiles = profiles;
      _selectedId = selected;

      if (_selectedId == null && _profiles.isNotEmpty) {
        _selectedId = _profiles.first.id;
        _prefs.setSelectedProfileId(_selectedId);
      }
    });
  }

  void _addInfo() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileEditorScreen()),
    );
    if (result == true) _loadData();
  }

  void _edit(ProxyProfile profile) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditorScreen(profile: profile)),
    );
    if (result == true) _loadData();
  }

  void _delete(String id) async {
    await _prefs.deleteProfile(id);
    if (_selectedId == id) {
       await _prefs.setSelectedProfileId(null);
    }
    _loadData();
  }

  void _select(String id) async {
    if (_isConnected) return; // Don't switch while connected
    await _prefs.setSelectedProfileId(id);
    setState(() => _selectedId = id);
  }

  void _toggleConnect() async {
    if (_profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add a server first")),
      );
      return;
    }
    if (_selectedId == null) return;

    final profile = _profiles.firstWhere((p) => p.id == _selectedId);

    // Validate proxy configuration before connecting
    if (profile.host.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server address is empty")),
      );
      return;
    }
    if (profile.port <= 0 || profile.port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid port number (must be 1–65535)")),
      );
      return;
    }

    setState(() => _isConnecting = true);

    try {
      if (_isConnected) {
        await VpnChannel.stopVpn();
        // State updated via EventChannel
      } else {
        await VpnChannel.startVpn(profile.toUrl());
        // State updated via EventChannel
      }
    } catch (e) {
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('RouteFlux VPN'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
         actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addInfo,
          )
        ],
      ),
      body: Column(
        children: [
          // Header / Status
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.shield, color: _isConnected ? Colors.green : Colors.grey, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isConnected ? "CONNECTED" : "DISCONNECTED",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(_isConnected ? "Your traffic is secured" : "Select a server to connect",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
          
          Expanded(
            child: _profiles.isEmpty
                ? Center(child: Text("No servers yet.\nTap + to add one.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _profiles.length,
                    itemBuilder: (ctx, i) {
                      final p = _profiles[i];
                      final isSelected = p.id == _selectedId;
                      return Dismissible(
                        key: ValueKey(p.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _delete(p.id),
                        child: Card(
                          elevation: isSelected ? 4 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isSelected ? const BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: () => _select(p.id),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
                                    child: Icon(Icons.public, color: isSelected ? Colors.white : Colors.grey),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Text("${p.host}:${p.port}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4)
                                          ),
                                          child: Text(
                                            p.protocol == ProxyProtocol.http ? "HTTP" :
                                            p.protocol == ProxyProtocol.https ? "HTTPS" :
                                            p.protocol == ProxyProtocol.socks5 ? "SOCKS5" : "SOCKS5+TLS", 
                                            style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                                        )
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.grey),
                                    onPressed: () => _edit(p),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))]
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isConnected ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: _isConnecting ? null : _toggleConnect,
                icon: _isConnecting 
                   ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                   : Icon(_isConnected ? Icons.stop : Icons.power_settings_new),
                label: Text(_isConnecting 
                   ? "Connecting..." 
                   : (_isConnected ? "Disconnect" : "Connect"), 
                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
