
import 'package:flutter/material.dart';

enum ProxyProtocol { http, https, socks5, socks5s }

class ProxyProfile {
  final String id;
  String name;
  String host;
  int port;
  ProxyProtocol protocol;
  String? username;
  String? password;
  int colorValue;

  ProxyProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.protocol = ProxyProtocol.http,
    this.username,
    this.password,
    this.colorValue = 0xFF2196F3,
  });

  // Convert to Map for JSON/SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'protocol': protocol.index,
      'username': username,
      'password': password,
      'colorValue': colorValue,
    };
  }

  // Create from Map
  factory ProxyProfile.fromJson(Map<String, dynamic> json) {
    return ProxyProfile(
      id: json['id'],
      name: json['name'],
      host: json['host'],
      port: json['port'],
      protocol: ProxyProtocol.values[json['protocol'] ?? 0],
      username: json['username'],
      password: json['password'],
      colorValue: json['colorValue'] ?? 0xFF2196F3,
    );
  }

  // Helper to get formatted URL for tun2socks
  // Format: scheme://[user:pass@]host:port
  String toUrl() {
    String scheme;
    switch (protocol) {
      case ProxyProtocol.http:
        scheme = 'http';
        break;
      case ProxyProtocol.https:
        scheme = 'https';
        break;
      case ProxyProtocol.socks5:
        scheme = 'socks5';
        break;
      case ProxyProtocol.socks5s:
        scheme = 'socks5s';
        break;
    }
    
    String auth = '';
    if (username != null && username!.isNotEmpty && password != null && password!.isNotEmpty) {
      final encodedUser = Uri.encodeComponent(username!);
      final encodedPass = Uri.encodeComponent(password!);
      auth = '$encodedUser:$encodedPass@';
    }
    return '$scheme://$auth$host:$port';
  }

  Color get color => Color(colorValue);
}
