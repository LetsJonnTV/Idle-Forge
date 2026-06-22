import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Handles downloading and installing updates on Android and Windows.
class UpdateInstaller {
  static const _androidChannel = MethodChannel(
    'com.example.idle_forge/install',
  );
  static String? _lastError;

  static String? get lastError => _lastError;

  /// Downloads the update file and reports progress via [onProgress] (0.0–1.0).
  /// Returns the path to the downloaded file, or null on failure.
  static Future<String?> download(
    String url, {
    required void Function(double progress) onProgress,
  }) async {
    try {
      _lastError = null;
      final dir = await getTemporaryDirectory();
      final fileName = defaultTargetPlatform == TargetPlatform.android
          ? 'idle_forge_update.apk'
          : 'idle_forge_update.zip';
      final filePath = '${dir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);

      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
      );

      if (streamedResponse.statusCode != 200) return null;

      final totalBytes = streamedResponse.contentLength ?? -1;
      int receivedBytes = 0;
      final sink = file.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes);
        }
      }
      await sink.close();
      onProgress(1.0);
      return filePath;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Update download failed: $e');
      return null;
    }
  }

  /// Installs the update from the given file path.
  static Future<bool> install(String filePath) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _installAndroid(filePath);
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      return _installWindows(filePath);
    }
    return false;
  }

  static Future<bool> _installAndroid(String apkPath) async {
    try {
      _lastError = null;
      final result = await _androidChannel.invokeMethod<bool>('installApk', {
        'path': apkPath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _lastError = e.message ?? e.code;
      debugPrint('APK install failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('APK install failed: $e');
      return false;
    }
  }

  static Future<bool> _installWindows(String zipPath) async {
    try {
      final exePath = Platform.resolvedExecutable;
      final appDir = File(exePath).parent.path;
      final tempDir = File(zipPath).parent.path;
      final extractDir = '$tempDir${Platform.pathSeparator}idle_forge_update';

      // Write update script
      final scriptPath = '$tempDir${Platform.pathSeparator}update.bat';
      final script =
          '''
@echo off
echo Updating Idle Forge...
timeout /t 2 /nobreak >nul
rd /s /q "$extractDir" 2>nul
powershell -NoProfile -Command "Expand-Archive -Path '$zipPath' -DestinationPath '$extractDir' -Force"
xcopy /s /y /q "$extractDir\\*" "$appDir\\"
rd /s /q "$extractDir" 2>nul
del "$zipPath" 2>nul
start "" "$exePath"
del "%~f0"
''';
      await File(scriptPath).writeAsString(script);

      // Launch updater script and exit app
      await Process.start('cmd.exe', [
        '/c',
        scriptPath,
      ], mode: ProcessStartMode.detached);

      // Exit the current app so files can be replaced
      exit(0);
    } catch (e) {
      debugPrint('Windows update failed: $e');
      return false;
    }
  }
}
