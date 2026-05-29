import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Blueprint data for a single item type fetched from the server.
class ItemBlueprintData {
  const ItemBlueprintData({
    required this.id,
    required this.slot,
    required this.name,
    required this.basePower,
    required this.iconPath,
  });

  final String id;
  final String slot;
  final String name;
  final int basePower;
  final String iconPath;

  factory ItemBlueprintData.fromJson(Map<String, dynamic> json) {
    return ItemBlueprintData(
      id: json['id'] as String? ?? '',
      slot: json['slot'] as String? ?? '',
      name: json['name'] as String? ?? '',
      basePower: (json['base_power'] as num?)?.toInt() ?? 1,
      iconPath: json['icon_path'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slot': slot,
    'name': name,
    'base_power': basePower,
    'icon_path': iconPath,
  };
}

/// Offline-first service that syncs item blueprints from the API
/// and caches them in SharedPreferences.
///
/// Usage: call [syncBlueprints] on app start (non-blocking).
/// Use [getBlueprintsForSlot] to query blueprints.
class ItemCatalogService {
  ItemCatalogService._();
  static final ItemCatalogService instance = ItemCatalogService._();

  static const _cacheKey = 'idle_forge.item_blueprints_cache.v1';

  List<ItemBlueprintData> _blueprints = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<ItemBlueprintData> get all => List.unmodifiable(_blueprints);

  /// Load cached blueprints from SharedPreferences synchronously.
  Future<void> loadFromCache() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _blueprints = list
            .map((e) => ItemBlueprintData.fromJson(e as Map<String, dynamic>))
            .toList();
        _loaded = true;
      }
    } catch (_) {
      // silently fail — will use empty list or fetch from API
    }
  }

  /// Sync blueprints from the API and update local cache.
  /// Merges new items with existing cached ones (keeps items not in API response).
  /// Call this in the background on app start.
  Future<void> syncBlueprints() async {
    final remote = await ApiService.instance.fetchItemBlueprints();
    if (remote.isEmpty) return;

    final remoteBlueprints = remote
        .map((e) => ItemBlueprintData.fromJson(e))
        .toList();

    // Merge: remote takes precedence over cache for matching IDs
    final merged = <String, ItemBlueprintData>{
      for (final bp in _blueprints) bp.id: bp,
      for (final bp in remoteBlueprints) bp.id: bp,
    };

    _blueprints = merged.values.toList();
    _loaded = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_blueprints.map((e) => e.toJson()).toList());
      await prefs.setString(_cacheKey, json);
    } catch (_) {
      // silently fail
    }
  }

  /// Get all blueprints for a given slot name (e.g. 'weapon', 'armor').
  List<ItemBlueprintData> getBlueprintsForSlot(String slot) {
    return _blueprints.where((bp) => bp.slot == slot).toList(growable: false);
  }

  /// Find a blueprint by ID.
  ItemBlueprintData? findById(String id) {
    try {
      return _blueprints.firstWhere((bp) => bp.id == id);
    } catch (_) {
      return null;
    }
  }
}
