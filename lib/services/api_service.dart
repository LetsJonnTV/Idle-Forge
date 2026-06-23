import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Exception thrown by ApiService on network or server errors.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.isOffline = false,
  });

  final String message;
  final int? statusCode;
  final bool isOffline;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Holds leaderboard entry data from the API.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.id,
    required this.username,
    required this.totalStrength,
    required this.prestigeLevel,
    required this.chapter,
  });

  final int rank;
  final String id;
  final String username;
  final int totalStrength;
  final int prestigeLevel;
  final int chapter;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      totalStrength: (json['totalStrength'] as num?)?.toInt() ?? 0,
      prestigeLevel: (json['prestigeLevel'] as num?)?.toInt() ?? 0,
      chapter: (json['chapter'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Singleton service for all backend API communication.
/// Never throws — always degrades gracefully.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.idle-forge.jonn2008.me',
  );

  static void validateConfig() {
    if (_baseUrl.isEmpty || !_baseUrl.startsWith('http')) {
      debugPrint(
        '[ApiService] WARNING: API_BASE_URL is misconfigured ("$_baseUrl"). '
        'Pass --dart-define=API_BASE_URL=https://... at build time.',
      );
    } else {
      debugPrint('[ApiService] Base URL: $_baseUrl');
    }
  }

  static const String _tokenKey = 'idle_forge_jwt';
  static const String _playerIdKey = 'idle_forge_player_id';
  static const String _usernameKey = 'idle_forge_username';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cachedToken;
  String? _cachedPlayerId;
  String? _cachedUsername;

  // ------------------------------------------------------------------ //
  //  Auth State
  // ------------------------------------------------------------------ //

  bool get isLoggedIn => _cachedToken != null;

  String? get currentPlayerId => _cachedPlayerId;
  String? get currentUsername => _cachedUsername;

  /// Load stored credentials on app start. Returns true if token found.
  Future<bool> loadStoredCredentials() async {
    try {
      _cachedToken = await _storage.read(key: _tokenKey);
      _cachedPlayerId = await _storage.read(key: _playerIdKey);
      _cachedUsername = await _storage.read(key: _usernameKey);
      return _cachedToken != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistCredentials(
    String token,
    String playerId,
    String username,
  ) async {
    _cachedToken = token;
    _cachedPlayerId = playerId;
    _cachedUsername = username;
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _playerIdKey, value: playerId);
      await _storage.write(key: _usernameKey, value: username);
    } catch (_) {
      // Secure storage unavailable — keep in-memory only
    }
  }

  Future<void> logout() async {
    _cachedToken = null;
    _cachedPlayerId = null;
    _cachedUsername = null;
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _playerIdKey);
      await _storage.delete(key: _usernameKey);
    } catch (_) {}
    await logoutGoogle();
  }

  // ------------------------------------------------------------------ //
  //  HTTP Helpers
  // ------------------------------------------------------------------ //

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_cachedToken != null) 'Authorization': 'Bearer $_cachedToken',
  };

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  /// Makes a POST request. Returns parsed JSON or throws ApiException.
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(_uri(path), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException(
        message: 'No internet connection',
        isOffline: true,
      );
    } on HttpException {
      throw const ApiException(message: 'Network error', isOffline: true);
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw const ApiException(message: 'Request timed out', isOffline: true);
      }
      throw ApiException(message: e.toString());
    } catch (e, stack) {
      debugPrint('_post unhandled error [$path]: $e\n$stack');
      throw ApiException(message: e.toString());
    }
  }

  /// Makes a GET request. Returns parsed JSON or throws ApiException.
  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await http
          .get(_uri(path), headers: _headers)
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException(
        message: 'No internet connection',
        isOffline: true,
      );
    } on HttpException {
      throw const ApiException(message: 'Network error', isOffline: true);
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw const ApiException(message: 'Request timed out', isOffline: true);
      }
      throw ApiException(message: e.toString());
    } catch (e, stack) {
      debugPrint('_get unhandled error [$path]: $e\n$stack');
      throw ApiException(message: e.toString());
    }
  }

  /// Makes a PUT request. Returns parsed JSON or throws ApiException.
  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .put(_uri(path), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException(
        message: 'No internet connection',
        isOffline: true,
      );
    } on HttpException {
      throw const ApiException(message: 'Network error', isOffline: true);
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw const ApiException(message: 'Request timed out', isOffline: true);
      }
      throw ApiException(message: e.toString());
    } catch (e, stack) {
      debugPrint('_put unhandled error [$path]: $e\n$stack');
      throw ApiException(message: e.toString());
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = _decodeResponseBody(response);
    if (response.statusCode == 401) {
      // Token expired or invalid — clear credentials
      logout();
      throw ApiException(
        message: _extractErrorMessage(body, 'Unauthorized'),
        statusCode: 401,
      );
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        message: _extractErrorMessage(body, 'Request failed'),
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Map<String, dynamic> _decodeResponseBody(http.Response response) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        message: 'Server returned an invalid response',
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic>) return decoded;

    throw ApiException(
      message: 'Server returned an unexpected response format',
      statusCode: response.statusCode,
    );
  }

  String _extractErrorMessage(Map<String, dynamic> body, String fallback) {
    final error = body['error'] ?? body['message'];
    if (error is String && error.trim().isNotEmpty) return error;
    return fallback;
  }

  // ------------------------------------------------------------------ //
  //  Auth
  // ------------------------------------------------------------------ //

  /// Register a new account. Returns true on success.
  Future<bool> register(String username, String password) async {
    try {
      final data = await _post('/api/auth/register', {
        'username': username,
        'password': password,
      });
      await _persistCredentials(
        data['token'] as String,
        data['playerId'] as String,
        data['username'] as String,
      );
      return true;
    } on ApiException {
      rethrow;
    } catch (e, stack) {
      debugPrint('register unexpected error: $e\n$stack');
      throw ApiException(message: e.toString());
    }
  }

  /// Login with username and password. Returns true on success.
  Future<bool> login(String username, String password) async {
    try {
      final data = await _post('/api/auth/login', {
        'username': username,
        'password': password,
      });
      await _persistCredentials(
        data['token'] as String,
        data['playerId'] as String,
        data['username'] as String,
      );
      return true;
    } on ApiException {
      rethrow;
    } catch (e, stack) {
      debugPrint('login unexpected error: $e\n$stack');
      throw ApiException(message: e.toString());
    }
  }

  /// Login with Google account. Returns true on success.
  /// Shows Google sign-in dialog to user.
  Future<bool> loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: <String>['email']);

      final account = await googleSignIn.signIn();
      if (account == null) {
        // User cancelled
        return false;
      }

      final authentication = await account.authentication;
      final idToken = authentication.idToken;

      if (idToken == null) {
        debugPrint('loginWithGoogle: No ID token received');
        return false;
      }

      // Send idToken to backend
      final data = await _post('/api/auth/google', {'idToken': idToken});

      await _persistCredentials(
        data['token'] as String,
        data['playerId'] as String,
        data['username'] as String,
      );

      debugPrint('loginWithGoogle: Success - playerId ${data['playerId']}');
      return true;
    } catch (e) {
      debugPrint('loginWithGoogle error: $e');
      return false;
    }
  }

  /// Logout from Google
  Future<void> logoutGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (e) {
      debugPrint('logoutGoogle error: $e');
    }
  }

  // ------------------------------------------------------------------ //
  //  Player Stats
  // ------------------------------------------------------------------ //

  /// Upload local game stats to the server.
  Future<bool> uploadStats({
    required int totalStrength,
    required int prestigeLevel,
    required int chapter,
  }) async {
    if (!isLoggedIn || _cachedPlayerId == null) return false;
    try {
      await _put('/api/players/$_cachedPlayerId', {
        'total_strength': totalStrength,
        'prestige_level': prestigeLevel,
        'chapter': chapter,
      });
      return true;
    } on ApiException catch (e) {
      if (e.isOffline) return false;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetch and atomically consume all pending admin rewards for the current player.
  /// Returns a list of reward maps: [{ 'reward_type': 'gold', 'amount': 100 }, ...]
  Future<List<Map<String, dynamic>>> claimPendingRewards() async {
    if (!isLoggedIn) return [];
    try {
      final data = await _post('/api/players/me/rewards', {});
      return List<Map<String, dynamic>>.from(data['rewards'] as List? ?? []);
    } on ApiException {
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch all active item blueprints from the API.
  /// Returns a list of blueprint maps or empty list on error.
  Future<List<Map<String, dynamic>>> fetchItemBlueprints() async {
    try {
      final data = await _get('/api/items');
      return List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
    } on ApiException {
      return [];
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------------ //
  //  Leaderboard
  // ------------------------------------------------------------------ //

  /// Fetch global or weekly leaderboard. Returns entries or empty list.
  Future<List<LeaderboardEntry>> getLeaderboard({bool weekly = false}) async {
    try {
      final path = weekly
          ? '/api/leaderboard?scope=weekly'
          : '/api/leaderboard';
      final data = await _get(path);
      final entries = (data['entries'] as List<dynamic>?) ?? [];
      return entries
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------------ //
  //  Friends
  // ------------------------------------------------------------------ //

  /// Get friends list (accepted + pending).
  Future<List<Map<String, dynamic>>> getFriends() async {
    if (!isLoggedIn) return [];
    try {
      final data = await _get('/api/friends');
      return List<Map<String, dynamic>>.from(data['friends'] as List? ?? []);
    } on ApiException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  /// Send a friend request by username.
  Future<bool> sendFriendRequest(String targetUsername) async {
    if (!isLoggedIn) return false;
    try {
      await _post('/api/friends', {'targetUsername': targetUsername});
      return true;
    } on ApiException {
      rethrow;
    } catch (_) {
      return false;
    }
  }

  /// Accept, reject or block a friend request by relationship ID.
  Future<bool> respondToFriendRequest(
    String friendshipId,
    String action, // 'accept' | 'reject' | 'block'
  ) async {
    if (!isLoggedIn) return false;
    try {
      await _put('/api/friends/$friendshipId', {'action': action});
      return true;
    } on ApiException {
      rethrow;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------ //
  //  Clans
  // ------------------------------------------------------------------ //

  /// List all clans.
  Future<List<Map<String, dynamic>>> getClans() async {
    try {
      final data = await _get('/api/clans');
      return List<Map<String, dynamic>>.from(data['clans'] as List? ?? []);
    } on ApiException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  /// Create a new clan.
  Future<Map<String, dynamic>?> createClan(
    String name, {
    String description = '',
  }) async {
    if (!isLoggedIn) return null;
    try {
      final data = await _post('/api/clans', {
        'name': name,
        'description': description,
      });
      return data['clan'] as Map<String, dynamic>?;
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// Join a clan by ID.
  Future<bool> joinClan(String clanId) async {
    if (!isLoggedIn) return false;
    try {
      await _post('/api/clans/$clanId/join', {});
      return true;
    } on ApiException {
      rethrow;
    } catch (_) {
      return false;
    }
  }

  /// Get members of a clan.
  Future<List<Map<String, dynamic>>> getClanMembers(String clanId) async {
    try {
      final data = await _get('/api/clans/$clanId/members');
      return List<Map<String, dynamic>>.from(data['members'] as List? ?? []);
    } on ApiException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  /// Get current player's profile (clan_id, etc.).
  Future<Map<String, dynamic>?> getMyProfile() async {
    if (!isLoggedIn) return null;
    try {
      final data = await _get('/api/players/me');
      return data['player'] as Map<String, dynamic>?;
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// Get chat messages for a clan.
  Future<List<Map<String, dynamic>>> getClanChat(String clanId) async {
    if (!isLoggedIn) return [];
    try {
      final data = await _get('/api/clans/$clanId/chat');
      return List<Map<String, dynamic>>.from(data['messages'] as List? ?? []);
    } on ApiException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  /// Send a chat message to a clan.
  Future<bool> sendClanMessage(String clanId, String message) async {
    if (!isLoggedIn) return false;
    try {
      await _post('/api/clans/$clanId/chat', {'message': message});
      return true;
    } on ApiException {
      rethrow;
    } catch (_) {
      return false;
    }
  }

  /// Invite a player to a clan by username (leader only).
  Future<bool> invitePlayerToClan(String clanId, String username) async {
    if (!isLoggedIn) return false;
    try {
      await _post('/api/clans/$clanId/invite', {'username': username});
      return true;
    } on ApiException {
      rethrow;
    } catch (_) {
      return false;
    }
  }

  /// Get pending invites for the current player.
  Future<List<Map<String, dynamic>>> getMyInvites() async {
    if (!isLoggedIn) return [];
    try {
      final data = await _get('/api/clans/invites');
      return List<Map<String, dynamic>>.from(data['invites'] as List? ?? []);
    } on ApiException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  /// Respond to a clan invite.
  Future<bool> respondToInvite(String inviteId, bool accept) async {
    if (!isLoggedIn) return false;
    try {
      await _put('/api/clans/invites', {
        'inviteId': inviteId,
        'accept': accept,
      });
      return true;
    } on ApiException {
      rethrow;
    } catch (_) {
      return false;
    }
  }

  /// Leave a clan.
  Future<bool> leaveClan(String clanId) async {
    if (!isLoggedIn) return false;
    try {
      await _post('/api/clans/$clanId/leave', {});
      return true;
    } on ApiException {
      rethrow;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------ //
  //  Player Profiles
  // ------------------------------------------------------------------ //

  /// Get public profile of a player by their ID.
  /// Returns { player: {...}, equippedItems: [...] } or null.
  Future<Map<String, dynamic>?> getPlayerProfile(String playerId) async {
    try {
      return await _get('/api/players/$playerId/profile');
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ //
  //  PVP
  // ------------------------------------------------------------------ //

  /// Challenge a player by username. Returns battle result or null.
  Future<Map<String, dynamic>?> challengePvp(String defenderUsername) async {
    if (!isLoggedIn) return null;
    try {
      final data = await _post('/api/pvp', {
        'defenderUsername': defenderUsername,
      });
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// Get a specific PVP battle result.
  Future<Map<String, dynamic>?> getPvpResult(String battleId) async {
    if (!isLoggedIn) return null;
    try {
      final data = await _get('/api/pvp/$battleId');
      return data['battle'] as Map<String, dynamic>?;
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// List recent PVP battles for the current player.
  Future<List<Map<String, dynamic>>> getPvpBattles() async {
    if (!isLoggedIn) return [];
    try {
      final data = await _get('/api/pvp');
      return List<Map<String, dynamic>>.from(data['battles'] as List? ?? []);
    } on ApiException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------------ //
  //  Coop
  // ------------------------------------------------------------------ //

  /// Create a new coop session. Returns the session or null.
  Future<Map<String, dynamic>?> createCoopSession() async {
    if (!isLoggedIn) return null;
    try {
      final data = await _post('/api/coop', {});
      return data['session'] as Map<String, dynamic>?;
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// Join an existing coop session by ID.
  Future<Map<String, dynamic>?> joinCoopSession(String sessionId) async {
    if (!isLoggedIn) return null;
    try {
      final data = await _put('/api/coop/$sessionId', {'action': 'join'});
      return data['session'] as Map<String, dynamic>?;
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// Get current status of a coop session.
  Future<Map<String, dynamic>?> getCoopSession(String sessionId) async {
    if (!isLoggedIn) return null;
    try {
      final data = await _get('/api/coop/$sessionId');
      return data['session'] as Map<String, dynamic>?;
    } on ApiException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// List active coop sessions for the current player.
  Future<List<Map<String, dynamic>>> getCoopSessions() async {
    if (!isLoggedIn) return [];
    try {
      final data = await _get('/api/coop');
      return List<Map<String, dynamic>>.from(data['sessions'] as List? ?? []);
    } on ApiException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------------ //
  //  Cloud Save
  // ------------------------------------------------------------------ //

  /// Upload the full game save JSON to the server.
  Future<bool> uploadSave(Map<String, dynamic> saveData) async {
    if (!isLoggedIn) return false;
    try {
      await _put('/api/saves', {'save_data': saveData});
      return true;
    } on ApiException catch (e) {
      if (e.isOffline) return false;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Download the full game save JSON from the server.
  /// Returns null if no save exists on the server or on any error.
  Future<Map<String, dynamic>?> downloadSave() async {
    if (!isLoggedIn) return null;
    try {
      final data = await _get('/api/saves');
      final save = data['save'];
      if (save == null) {
        debugPrint('downloadSave: no save on server');
        return null;
      }
      final saveMap = Map<String, dynamic>.from(save as Map);
      debugPrint('downloadSave: loaded ${saveMap.length} fields');
      return saveMap;
    } on ApiException catch (e) {
      debugPrint('downloadSave ApiException: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('downloadSave error: $e');
      return null;
    }
  }

  // ------------------------------------------------------------------ //
  //  Inventory Sync
  // ------------------------------------------------------------------ //

  /// Upload the full inventory to the dedicated player_items table.
  /// [items] is the raw JSON list from GameItem.toJson().
  /// [equippedBySlot] maps slot names to equipped item IDs.
  Future<bool> uploadInventory(
    List<Map<String, dynamic>> items,
    Map<String, String> equippedBySlot,
  ) async {
    if (!isLoggedIn) return false;
    try {
      await _put('/api/players/me/inventory', {
        'items': items,
        'equippedBySlot': equippedBySlot,
      });
      return true;
    } on ApiException catch (e) {
      if (e.isOffline) return false;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Download inventory from the dedicated player_items table.
  /// Returns null if no items exist on the server or on any error.
  Future<List<Map<String, dynamic>>?> downloadInventory() async {
    if (!isLoggedIn) return null;
    try {
      final data = await _get('/api/players/me/inventory');
      final raw = data['items'] as List?;
      if (raw == null || raw.isEmpty) return null;
      return raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
