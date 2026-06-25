import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../l10n/app_text.dart';
import '../services/api_service.dart';

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

  // War state
  Map<String, dynamic>? _warData;
  bool _warLoading = false;
  bool _contributing = false;
  String? _warError;
  String? _warSuccess;
  Timer? _warCountdownTimer;
  Duration _warTimeLeft = Duration.zero;

  late TabController _tabController;
  Timer? _chatTimer;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // ------------------------------------------------------------------ //
  // Theme helpers
  // ------------------------------------------------------------------ //

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0C0F16) : const Color(0xFFF0E8D8);
  Color get _cardBg =>
      _isDark ? const Color(0xFF191E2C) : const Color(0xFFFFF8EC);
  Color get _accent => const Color(0xFFD4A84B);
  Color get _red => const Color(0xFFE05050);
  Color get _green => const Color(0xFF50C878);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFDED0B0) : const Color(0xFF2A1E08);
  Color get _textSecondary =>
      _isDark ? const Color(0xFF9A8860) : const Color(0xFF6A5028);
  Color get _border =>
      _isDark ? const Color(0xFF7A5818) : const Color(0xFF9A7420);

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
    _warCountdownTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _setTabCount(int count) {
    if (_tabController.length == count) return;
    final old = _tabController;
    old.removeListener(_onTabChanged);
    _tabController = TabController(length: count, vsync: this);
    _tabController.addListener(_onTabChanged);
    old.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    if (_playerClanId != null) {
      if (_tabController.index == 1) {
        _startChatPolling();
        _stopWarCountdown();
      } else if (_tabController.index == 2) {
        _stopChatPolling();
        _loadWarData();
      } else {
        _stopChatPolling();
        _stopWarCountdown();
      }
    } else {
      _stopChatPolling();
      _stopWarCountdown();
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

  void _stopWarCountdown() {
    _warCountdownTimer?.cancel();
    _warCountdownTimer = null;
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
        widget.controller.setClanInfo(0, null);
        final clans = await api.getClans();
        final invites = await api.getMyInvites();
        if (!mounted) return;
        _setTabCount(2);
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
      final clanFuture = api.getClan(clanId);
      final membersFuture = api.getClanMembers(clanId);
      final clanData = await clanFuture;
      final members = await membersFuture;

      if (!mounted) return;

      final level = (clanData?['level'] as num?)?.toInt() ?? 1;
      final name = clanData?['name'] as String?;
      widget.controller.setClanInfo(level, name);

      _setTabCount(3);
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

  // ── War helpers ───────────────────────────────────────────────────── //

  Future<void> _loadWarData() async {
    if (_playerClanId == null) return;
    setState(() {
      _warLoading = true;
      _warError = null;
    });
    try {
      final data = await api.getClanWar();
      if (!mounted) return;
      setState(() {
        _warData = data;
        _warLoading = false;
      });
      _startWarCountdown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _warLoading = false;
        _warError = e.isOffline ? t.tr('clanWarOffline') : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _warLoading = false;
        _warError = t.tr('clanWarOffline');
      });
    }
  }

  void _startWarCountdown() {
    _warCountdownTimer?.cancel();
    final endsAt = _warEndsAt;
    if (endsAt == null) return;
    _updateWarTimeLeft(endsAt);
    _warCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateWarTimeLeft(endsAt);
    });
  }

  void _updateWarTimeLeft(DateTime endsAt) {
    final diff = endsAt.difference(DateTime.now());
    setState(() => _warTimeLeft = diff.isNegative ? Duration.zero : diff);
  }

  DateTime? get _warEndsAt {
    final str = _warData?['war']?['endsAt'] as String?;
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  String _formatDuration(Duration d) {
    if (d.inDays >= 1) {
      final h = d.inHours % 24;
      return '${d.inDays}d ${h.toString().padLeft(2, '0')}h';
    }
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _contribute() async {
    if (_contributing) return;
    setState(() {
      _contributing = true;
      _warError = null;
      _warSuccess = null;
    });
    try {
      final result = await api.contributeClanWar();
      if (!mounted) return;
      setState(() {
        _warSuccess = t
            .tr('clanWarContributed')
            .replaceFirst('{points}', '${result?['pointsAdded'] ?? 0}');
      });
      await _loadWarData();
      // Refresh clan data (level/xp may have changed)
      if (_playerClanId != null) {
        final updated = await api.getClan(_playerClanId!);
        if (!mounted) return;
        final level = (updated?['level'] as num?)?.toInt() ?? 1;
        final name = updated?['name'] as String?;
        widget.controller.setClanInfo(level, name);
        setState(() => _clanData = updated);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _warError = e.isOffline ? t.tr('clanWarOffline') : e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _warError = t.tr('errorUnexpected'));
    } finally {
      if (mounted) setState(() => _contributing = false);
    }
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
        final newClanId = clan['id'] as String?;
        if (newClanId != null) {
          await _loadClanData(newClanId);
        } else {
          await _load();
        }
      } else {
        widget.controller.spendGold(-1000);
        _showSnack(t.tr('errorUnexpected'), error: true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
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
        await _loadClanData(clanId);
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
        _stopWarCountdown();
        widget.controller.setClanInfo(0, null);
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
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield, size: 14),
                              const SizedBox(width: 4),
                              Text(t.tr('clanWarTitle')),
                            ],
                          ),
                        ),
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
                  ? [_buildMembersTab(), _buildChatTab(), _buildWarTab()]
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
    final level = (clan['level'] as num?)?.toInt() ?? 1;
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
    final clanLevel = (clan['level'] as num?)?.toInt() ?? 1;

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
  // IN CLAN — Members Tab
  // ------------------------------------------------------------------ //

  Widget _buildMembersTab() {
    final clanName = _clanData?['name'] as String? ?? '';
    final clanLevel = (_clanData?['level'] as num?)?.toInt() ?? 1;
    final clanXp = (_clanData?['xp'] as num?)?.toInt() ?? 0;
    final xpForNextLevel = clanLevel * 1000;
    final xpFraction = xpForNextLevel > 0
        ? (clanXp / xpForNextLevel).clamp(0.0, 1.0)
        : 1.0;
    final description = _clanData?['description'] as String? ?? '';
    final leader = _clanData?['leader'] as Map<String, dynamic>?;
    final leaderId = leader?['id'] as String?;
    final myId = api.currentPlayerId;
    final isLeader = myId != null && leaderId == myId;

    // Gold bonus from clan level
    final goldBonus = (clanLevel * 5);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ── Clan header with XP bar ────────────────────────────────
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
                        horizontal: 10,
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
                          fontSize: 13,
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
                const SizedBox(height: 12),
                // XP bar
                Row(
                  children: [
                    Text(
                      'XP',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: xpFraction,
                          minHeight: 8,
                          backgroundColor: _border.withAlpha(60),
                          valueColor: AlwaysStoppedAnimation<Color>(_accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$clanXp / $xpForNextLevel',
                      style: TextStyle(color: _textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Clan bonuses
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _accent.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: _accent, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Clan-Boni: +$goldBonus% Gold',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (clanLevel >= 5) ...[
                        const SizedBox(width: 8),
                        Text(
                          '· +${clanLevel * 2}% Scherben',
                          style: TextStyle(color: _accent, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
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
    final strength = (member['total_strength'] as num?)?.toInt() ?? 0;
    final prestige = (member['prestige_level'] as num?)?.toInt() ?? 0;
    final isLeader = leaderId == playerId;
    final isMe = api.currentPlayerId == playerId;

    // Get war contribution for this member if available
    final warLeaderboard = (_warData?['leaderboard'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final warEntry = warLeaderboard.where(
      (e) => e['playerId'] == playerId,
    ).firstOrNull;
    final warPoints = (warEntry?['points'] as num?)?.toInt();

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
          // War contribution badge
          if (warPoints != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _green.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _green.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield, size: 12, color: _green),
                  const SizedBox(width: 3),
                  Text(
                    '$warPoints',
                    style: TextStyle(
                      color: _green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ //
  // IN CLAN — Chat Tab
  // ------------------------------------------------------------------ //

  Widget _buildChatTab() {
    return Column(
      children: [
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

  // ------------------------------------------------------------------ //
  // IN CLAN — War Tab
  // ------------------------------------------------------------------ //

  Widget _buildWarTab() {
    if (_warLoading) {
      return Center(child: CircularProgressIndicator(color: _accent));
    }

    if (!_warLoading && _warData == null) {
      // Not loaded yet — trigger load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _warData == null && !_warLoading) _loadWarData();
      });
    }

    if (_warError != null && _warData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: _textSecondary),
              const SizedBox(height: 12),
              Text(
                _warError!,
                style: TextStyle(color: _textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadWarData,
                style: ElevatedButton.styleFrom(backgroundColor: _accent),
                child: Text(t.tr('retry')),
              ),
            ],
          ),
        ),
      );
    }

    final war = _warData?['war'];

    if (war == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 56, color: _textSecondary),
              const SizedBox(height: 16),
              Text(
                t.tr('clanWarNoActive'),
                style: TextStyle(color: _textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final clanA = war['clanA'] as Map<String, dynamic>?;
    final clanB = war['clanB'] as Map<String, dynamic>?;
    final myPoints = (_warData?['myPoints'] as num?)?.toInt() ?? 0;
    final canContribute = _warData?['canContribute'] as bool? ?? false;
    final playerStrength = (_warData?['playerStrength'] as num?)?.toInt() ?? 0;
    final leaderboard =
        (_warData?['leaderboard'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final myPlayerId = api.currentPlayerId;
    final playerClanId = war['playerClanId'] as String?;
    final clanAId = clanA?['id'] as String?;

    final myClansPoints = (war['playerClanPoints'] as num?)?.toInt() ?? 0;
    final opponentPoints = (war['opponentClanPoints'] as num?)?.toInt() ?? 0;
    final totalPoints = myClansPoints + opponentPoints;
    final myFraction = totalPoints > 0 ? myClansPoints / totalPoints : 0.5;

    final myClanName = playerClanId == clanAId
        ? (clanA?['name'] as String? ?? '?')
        : (clanB?['name'] as String? ?? '?');
    final opponentName = playerClanId == clanAId
        ? (clanB?['name'] as String? ?? '?')
        : (clanA?['name'] as String? ?? '?');

    return RefreshIndicator(
      onRefresh: _loadWarData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // War card
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accent.withAlpha(80)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.shield, size: 40, color: _accent),
                  const SizedBox(height: 8),
                  Text(
                    t.tr('clanWarTitle'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${t.tr("clanWarEndsIn")}: ${_formatDuration(_warTimeLeft)}',
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              myClanName,
                              style: TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '$myClansPoints',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: _green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              opponentName,
                              style: TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '$opponentPoints',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: _red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: myFraction,
                      minHeight: 12,
                      backgroundColor: _red.withAlpha(80),
                      valueColor: AlwaysStoppedAnimation<Color>(_green),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${t.tr("clanWarMyPoints")}: $myPoints',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: canContribute && !_contributing
                          ? _contribute
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _textSecondary.withAlpha(80),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _contributing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_circle_outline),
                      label: Text(
                        canContribute
                            ? '${t.tr("clanWarContribute")} (+$playerStrength)'
                            : t.tr('clanWarAlreadyContributed'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  if (!canContribute) ...[
                    const SizedBox(height: 6),
                    Text(
                      t.tr('clanWarCooldown'),
                      style: TextStyle(color: _textSecondary, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            if (_warSuccess != null) ...[
              const SizedBox(height: 8),
              Text(
                _warSuccess!,
                style: TextStyle(color: _green, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            if (_warError != null) ...[
              const SizedBox(height: 8),
              Text(
                _warError!,
                style: TextStyle(color: _red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            if (leaderboard.isNotEmpty) ...[
              Text(
                t.tr('clanWarLeaderboard'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...leaderboard.map((entry) {
                final rank = entry['rank'] as int? ?? 0;
                final username = entry['username'] as String? ?? '?';
                final clanId = entry['clanId'] as String?;
                final points = (entry['points'] as num?)?.toInt() ?? 0;
                final isMe = entry['playerId'] == myPlayerId;
                final isMyClan = clanId == playerClanId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isMe ? _accent.withAlpha(40) : _cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isMe ? _accent.withAlpha(120) : _cardBg,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            color: rank <= 3 ? _accent : _textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          isMe
                              ? '${t.tr("you")} ($username)'
                              : username,
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: isMe
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isMyClan ? _green : _red).withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$points',
                          style: TextStyle(
                            color: isMyClan ? _green : _red,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
