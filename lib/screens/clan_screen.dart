import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../l10n/app_text.dart';
import '../services/api_service.dart';

/// Full clan screen — browse/create/join clans, chat, invite members.
class ClanScreen extends StatefulWidget {
  const ClanScreen({super.key, required this.text, required this.controller});

  final AppText text;
  final GameController controller;

  @override
  State<ClanScreen> createState() => _ClanScreenState();
}

class _ClanScreenState extends State<ClanScreen>
    with SingleTickerProviderStateMixin {
  // ------------------------------------------------------------------ //
  // State
  // ------------------------------------------------------------------ //

  String? _playerClanId;
  Map<String, dynamic>? _clanData;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _clans = [];
  List<Map<String, dynamic>> _chatMessages = [];
  List<Map<String, dynamic>> _invites = [];
  bool _isLoading = true;

  late final TabController _tabController;
  Timer? _chatTimer;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // ------------------------------------------------------------------ //
  // Theme helpers
  // ------------------------------------------------------------------ //

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF191919) : const Color(0xFFF4F4F4);
  Color get _cardBg =>
      _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF);
  Color get _accent => const Color(0xFFD4A84B);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFE2E2E2) : const Color(0xFF1A1A1A);
  Color get _textSecondary =>
      _isDark ? const Color(0xFFB5B5B5) : const Color(0xFF555555);
  Color get _border =>
      _isDark ? const Color(0xFF3B3B3B) : const Color(0xFFDDDDDD);

  AppText get t => widget.text;
  ApiService get api => ApiService.instance;

  // ------------------------------------------------------------------ //
  // Lifecycle
  // ------------------------------------------------------------------ //

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    if (_playerClanId != null && _tabController.index == 1) {
      _startChatPolling();
    } else {
      _stopChatPolling();
    }
  }

  void _startChatPolling() {
    _chatTimer?.cancel();
    _chatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _playerClanId != null) _loadChat();
    });
    _loadChat();
  }

  void _stopChatPolling() {
    _chatTimer?.cancel();
    _chatTimer = null;
  }

  // ------------------------------------------------------------------ //
  // Data loading
  // ------------------------------------------------------------------ //

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final profile = await api.getMyProfile();
      final clanId = profile?['clan_id'] as String?;

      if (clanId != null) {
        await _loadClanData(clanId);
      } else {
        final clans = await api.getClans();
        final invites = await api.getMyInvites();
        if (!mounted) return;
        setState(() {
          _playerClanId = null;
          _clanData = null;
          _members = [];
          _clans = clans;
          _invites = invites;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClanData(String clanId) async {
    try {
      final members = await api.getClanMembers(clanId);
      final clans = await api.getClans();
      final clanList = clans
          .where((c) => c['id'] == clanId)
          .toList(growable: false);
      final clanData = clanList.isNotEmpty ? clanList.first : null;

      if (!mounted) return;
      setState(() {
        _playerClanId = clanId;
        _clanData = clanData;
        _members = members;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChat() async {
    if (_playerClanId == null) return;
    try {
      final messages = await api.getClanChat(_playerClanId!);
      if (!mounted) return;
      setState(() => _chatMessages = messages);
      _scrollChatToBottom();
    } catch (_) {}
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ------------------------------------------------------------------ //
  // Actions
  // ------------------------------------------------------------------ //

  Future<void> _createClan() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          t.tr('clanCreate'),
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.tr('clanCreateCost'),
                  style: TextStyle(color: _accent, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: t.tr('clanNameHint'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 2
                      ? t.tr('validationMin3')
                      : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descController,
                  decoration: InputDecoration(
                    hintText: t.tr('clanDescHint'),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.tr('close')),
          ),
          FilledButton.tonal(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(t.tr('clanCreate')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (widget.controller.gold < 1000) {
      if (!mounted) return;
      _showSnack(t.tr('clanNotEnoughGold'), error: true);
      return;
    }

    final spent = widget.controller.spendGold(1000);
    if (!spent) {
      if (!mounted) return;
      _showSnack(t.tr('clanNotEnoughGold'), error: true);
      return;
    }

    try {
      final clan = await api.createClan(
        nameController.text.trim(),
        description: descController.text.trim(),
      );
      if (!mounted) return;
      if (clan != null) {
        _showSnack(t.tr('clanCreated'));
        await _load();
      } else {
        // Refund if creation failed
        widget.controller.spendGold(-1000);
        _showSnack(t.tr('errorUnexpected'), error: true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // Refund on error
      widget.controller.spendGold(-1000);
      _showSnack(e.message, error: true);
    }
  }

  Future<void> _joinClan(String clanId) async {
    try {
      final ok = await api.joinClan(clanId);
      if (!mounted) return;
      if (ok) {
        _showSnack(t.tr('clanJoined'));
        await _load();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, error: true);
    }
  }

  Future<void> _leaveClan() async {
    if (_playerClanId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          t.tr('clanLeave'),
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          t.tr('clanLeaveConfirm'),
          style: TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.tr('close')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE07070),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.tr('clanLeave')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final ok = await api.leaveClan(_playerClanId!);
      if (!mounted) return;
      if (ok) {
        _stopChatPolling();
        _showSnack(t.tr('clanLeft'));
        await _load();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, error: true);
    }
  }

  Future<void> _invitePlayer() async {
    final usernameController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          t.tr('clanInvite'),
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: usernameController,
          decoration: InputDecoration(
            hintText: t.tr('loginUsername'),
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.tr('close')),
          ),
          FilledButton.tonal(
            onPressed: () {
              if (usernameController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(t.tr('clanInvite')),
          ),
        ],
      ),
    );

    if (confirmed != true || _playerClanId == null) return;

    try {
      final ok = await api.invitePlayerToClan(
        _playerClanId!,
        usernameController.text.trim(),
      );
      if (!mounted) return;
      if (ok) _showSnack(t.tr('clanInviteSent'));
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, error: true);
    }
  }

  Future<void> _respondToInvite(String inviteId, bool accept) async {
    try {
      final ok = await api.respondToInvite(inviteId, accept);
      if (!mounted) return;
      if (ok) {
        _showSnack(accept ? t.tr('clanAccepted') : t.tr('clanDeclined'));
        await _load();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, error: true);
    }
  }

  Future<void> _sendMessage() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty || _playerClanId == null) return;
    _messageController.clear();
    try {
      await api.sendClanMessage(_playerClanId!, msg);
      await _loadChat();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, error: true);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? const Color(0xFFE07070)
            : const Color(0xFF7AC97A),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ------------------------------------------------------------------ //
  // Build
  // ------------------------------------------------------------------ //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          t.tr('clanTitle'),
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_playerClanId != null)
            TextButton.icon(
              onPressed: _leaveClan,
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFE07070)),
              label: Text(
                t.tr('clanLeave'),
                style: const TextStyle(color: Color(0xFFE07070)),
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: _textSecondary),
            onPressed: _load,
            tooltip: t.tr('refresh'),
          ),
        ],
        bottom: _isLoading
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: _accent,
                labelColor: _accent,
                unselectedLabelColor: _textSecondary,
                tabs: _playerClanId != null
                    ? [
                        Tab(text: t.tr('clanMembers')),
                        Tab(text: t.tr('clanChat')),
                      ]
                    : [
                        Tab(text: t.tr('clanBrowse')),
                        Tab(text: t.tr('clanInvites')),
                      ],
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _playerClanId != null
                  ? [_buildMembersTab(), _buildChatTab()]
                  : [_buildBrowseTab(), _buildInvitesTab()],
            ),
    );
  }

  // ------------------------------------------------------------------ //
  // NOT IN CLAN
  // ------------------------------------------------------------------ //

  Widget _buildBrowseTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Create clan button
          _buildCreateClanCard(),
          const SizedBox(height: 16),
          if (_clans.isEmpty)
            Center(
              child: Text(
                t.tr('clanNoClan'),
                style: TextStyle(color: _textSecondary),
              ),
            )
          else
            ..._clans.map(_buildClanCard),
        ],
      ),
    );
  }

  Widget _buildCreateClanCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withAlpha(100)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_rounded, color: _accent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.tr('clanCreate'),
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  t.tr('clanCreateCost'),
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: _createClan,
            child: Text(t.tr('clanCreate')),
          ),
        ],
      ),
    );
  }

  Widget _buildClanCard(Map<String, dynamic> clan) {
    final name = clan['name'] as String? ?? '';
    final level = clan['level'] as int? ?? 1;
    final description = clan['description'] as String? ?? '';
    final clanId = clan['id'] as String? ?? '';
    final leader = clan['leader'] as Map<String, dynamic>?;
    final leaderName = leader?['username'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _accent.withAlpha(60),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: _accent, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${t.tr('clanLevel')} $level · ${t.tr('pvpStrLabel')}: $leaderName',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => _joinClan(clanId),
                child: Text(t.tr('clanJoin')),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvitesTab() {
    if (_invites.isEmpty) {
      return Center(
        child: Text(
          t.tr('friendsNoRequests'),
          style: TextStyle(color: _textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _invites.length,
        itemBuilder: (_, i) => _buildInviteCard(_invites[i]),
      ),
    );
  }

  Widget _buildInviteCard(Map<String, dynamic> invite) {
    final inviteId = invite['id'] as String? ?? '';
    final clan = invite['clan'] as Map<String, dynamic>? ?? {};
    final inviter = invite['inviter'] as Map<String, dynamic>? ?? {};
    final clanName = clan['name'] as String? ?? '';
    final inviterName = inviter['username'] as String? ?? '';
    final clanLevel = clan['level'] as int? ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withAlpha(100)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _accent.withAlpha(60),
            child: Text(
              clanName.isNotEmpty ? clanName[0].toUpperCase() : '?',
              style: TextStyle(color: _accent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clanName,
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${t.tr('clanLevel')} $clanLevel · von $inviterName',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF7AC97A),
            ),
            onPressed: () => _respondToInvite(inviteId, true),
            tooltip: t.tr('friendsAccept'),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: Color(0xFFE07070)),
            onPressed: () => _respondToInvite(inviteId, false),
            tooltip: t.tr('friendsReject'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ //
  // IN CLAN
  // ------------------------------------------------------------------ //

  Widget _buildMembersTab() {
    final clanName = _clanData?['name'] as String? ?? '';
    final clanLevel = _clanData?['level'] as int? ?? 1;
    final description = _clanData?['description'] as String? ?? '';
    final leader = _clanData?['leader'] as Map<String, dynamic>?;
    final leaderId = leader?['id'] as String?;
    final myId = api.currentPlayerId;
    final isLeader = myId != null && leaderId == myId;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Clan header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withAlpha(80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_rounded, color: _accent, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        clanName,
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _accent.withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${t.tr('clanLevel')} $clanLevel',
                        style: TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Invite button (leader only)
          if (isLeader)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.tonal(
                onPressed: _invitePlayer,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text(t.tr('clanInvite')),
                  ],
                ),
              ),
            ),

          // Member count
          Text(
            '${t.tr('clanMembers')} (${_members.length})',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Members list
          ..._members.map((m) => _buildMemberCard(m, leaderId)),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, String? leaderId) {
    final playerId = member['player_id'] as String? ?? '';
    final username = member['username'] as String? ?? 'Unbekannt';
    final strength = member['total_strength'] as int? ?? 0;
    final prestige = member['prestige_level'] as int? ?? 0;
    final isLeader = leaderId == playerId;
    final isMe = api.currentPlayerId == playerId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLeader ? _accent.withAlpha(100) : _border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isLeader
                ? _accent.withAlpha(60)
                : Colors.grey.withAlpha(60),
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: TextStyle(
                color: isLeader ? _accent : _textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isLeader) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _accent.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Leader',
                          style: TextStyle(color: _accent, fontSize: 10),
                        ),
                      ),
                    ],
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${t.tr('you')})',
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${t.tr('totalStrength')}: $strength · Prestige: $prestige',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        // Messages
        Expanded(
          child: _chatMessages.isEmpty
              ? Center(
                  child: Text(
                    t.tr('clanChatSoon'),
                    style: TextStyle(color: _textSecondary),
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _chatMessages.length,
                  itemBuilder: (_, i) => _buildChatMessage(_chatMessages[i]),
                ),
        ),
        // Input
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: _cardBg,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: t.tr('clanSendMessage'),
                    hintStyle: TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _isDark
                        ? const Color(0xFF252525)
                        : const Color(0xFFF0F0F0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                  ),
                  style: TextStyle(color: _textPrimary),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sendMessage,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatMessage(Map<String, dynamic> msg) {
    final username = msg['username'] as String? ?? '';
    final message = msg['message'] as String? ?? '';
    final createdAt = msg['created_at'] as String? ?? '';
    final isMe = username == api.currentUsername;

    String timeLabel = '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      timeLabel =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isMe
                ? _accent.withAlpha(60)
                : Colors.grey.withAlpha(60),
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: TextStyle(
                color: isMe ? _accent : _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        color: isMe ? _accent : _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeLabel,
                      style: TextStyle(color: _textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(color: _textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
