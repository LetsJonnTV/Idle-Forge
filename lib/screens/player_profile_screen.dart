import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_text.dart';
import '../services/api_service.dart';

/// Public profile screen for any player, identified by their ID.
class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({
    super.key,
    required this.playerId,
    required this.username,
    required this.text,
  });

  final String playerId;
  final String username;
  final AppText text;

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  Map<String, dynamic>? _player;
  List<Map<String, dynamic>> _equippedItems = [];
  bool _loading = true;
  bool _offline = false;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0C0F16) : const Color(0xFFF0E8D8);
  Color get _cardBg =>
      _isDark ? const Color(0xFF191E2C) : const Color(0xFFFFF8EC);
  Color get _cardBorder =>
      _isDark ? const Color(0xFF2A3048) : const Color(0xFFBEA870);
  Color get _accent => const Color(0xFFD4A84B);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFDED0B0) : const Color(0xFF2A1E08);
  Color get _textSecondary =>
      _isDark ? const Color(0xFF9A8860) : const Color(0xFF6A5028);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final data = await ApiService.instance.getPlayerProfile(widget.playerId);
      if (!mounted) return;
      setState(() {
        _player = data?['player'] as Map<String, dynamic>?;
        _equippedItems = List<Map<String, dynamic>>.from(
          data?['equippedItems'] as List? ?? [],
        );
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = e.isOffline;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          widget.username,
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: _textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _textSecondary),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _offline
          ? _buildOffline()
          : _player == null
          ? _buildNotFound()
          : _buildProfile(),
    );
  }

  Widget _buildOffline() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.signal_wifi_off_rounded, size: 56, color: _textSecondary),
          const SizedBox(height: 16),
          Text(
            widget.text.tr('friendsOffline'),
            style: TextStyle(color: _textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: _load,
            child: Text(widget.text.tr('retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Text(
        widget.text.tr('profileNotFound'),
        style: TextStyle(color: _textSecondary, fontSize: 16),
      ),
    );
  }

  Widget _buildProfile() {
    final player = _player!;
    final username = player['username'] as String? ?? widget.username;
    final strength = (player['total_strength'] as num?)?.toInt() ?? 0;
    final prestige = (player['prestige_level'] as num?)?.toInt() ?? 0;
    final chapter = (player['chapter'] as num?)?.toInt() ?? 1;
    final clanName = player['clan_name'] as String?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        _card(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: _accent.withAlpha(40),
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                username,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              if (clanName != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: _accent),
                    const SizedBox(width: 4),
                    Text(
                      clanName,
                      style: TextStyle(color: _accent, fontSize: 13),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statCell(
                    label: widget.text.tr('totalStrength'),
                    value: '$strength',
                    icon: Icons.bolt,
                  ),
                  _dividerV(),
                  _statCell(
                    label: 'Prestige',
                    value: '$prestige',
                    icon: Icons.star_rounded,
                  ),
                  _dividerV(),
                  _statCell(
                    label: widget.text.tr('chapter'),
                    value: '$chapter',
                    icon: Icons.map_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Equipped items
        if (_equippedItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              widget.text.tr('profileEquipped'),
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _card(
            child: Column(
              children: _equippedItems.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    if (i > 0)
                      Divider(height: 1, color: _cardBorder.withAlpha(80)),
                    _ItemRow(
                      item: item,
                      textPrimary: _textPrimary,
                      textSecondary: _textSecondary,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ] else ...[
          _card(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  widget.text.tr('profileNoItems'),
                  style: TextStyle(color: _textSecondary),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: child,
    );
  }

  Widget _statCell({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: _accent, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: _textSecondary)),
      ],
    );
  }

  Widget _dividerV() {
    return Container(width: 1, height: 48, color: _cardBorder);
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Map<String, dynamic> item;
  final Color textPrimary;
  final Color textSecondary;

  Color _tierColor(String tier) {
    return switch (tier) {
      'uncommon' => const Color(0xFF4CAF50),
      'rare' => const Color(0xFF2196F3),
      'epic' => const Color(0xFF9C27B0),
      'legendary' => const Color(0xFFFF9800),
      _ => const Color(0xFFAAAAAA),
    };
  }

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '—';
    final tier = item['tier'] as String? ?? 'common';
    final power = (item['power'] as num?)?.toInt() ?? 0;
    final iconPath = item['iconPath'] as String? ?? '';
    final tierColor = _tierColor(tier);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tierColor.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tierColor.withAlpha(80)),
            ),
            child: iconPath.endsWith('.svg')
                ? Padding(
                    padding: const EdgeInsets.all(6),
                    child: SvgPicture.asset(
                      iconPath,
                      colorFilter: ColorFilter.mode(tierColor, BlendMode.srcIn),
                    ),
                  )
                : Icon(Icons.inventory_2_outlined, color: tierColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tierColor.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$power ⚔',
              style: TextStyle(
                fontSize: 12,
                color: tierColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
