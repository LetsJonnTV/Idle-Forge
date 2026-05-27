import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateChecker {
  static const String _releasesApiUrl =
      'https://api.github.com/repos/LetsJonnTV/Idle-Forge/releases/latest';
  static const String _releasesPageUrl =
      'https://github.com/LetsJonnTV/Idle-Forge/releases/latest';

  String get releasesPageUrl => _releasesPageUrl;

  /// Returns the latest version tag (e.g. "1.2.3") or null on failure.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"

      final response = await http
          .get(Uri.parse(_releasesApiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? '';
      final latestVersion = tagName.replaceFirst(RegExp(r'^v'), '');
      final htmlUrl = json['html_url'] as String? ?? _releasesPageUrl;

      if (latestVersion.isEmpty) return null;

      // Extract platform-specific download URL from assets
      String? downloadUrl;
      final assets = json['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        final url = asset['browser_download_url'] as String? ?? '';
        if (defaultTargetPlatform == TargetPlatform.android && name.endsWith('.apk')) {
          downloadUrl = url;
          break;
        } else if (defaultTargetPlatform == TargetPlatform.windows && name.endsWith('.zip')) {
          downloadUrl = url;
          break;
        }
      }

      if (_isNewer(latestVersion, currentVersion)) {
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          releaseUrl: htmlUrl,
          downloadUrl: downloadUrl,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isNewer(String latest, String current) {
    final l = _parse(latest);
    final c = _parse(current);
    for (int i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  List<int> _parse(String v) {
    final parts = v.split('.');
    return List.generate(3, (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0);
  }
}

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    this.downloadUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String? downloadUrl;
}
