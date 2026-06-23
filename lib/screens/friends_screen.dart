import 'package:flutter/material.dart';
import '../l10n/app_text.dart';
import '../services/api_service.dart';
import 'player_profile_screen.dart';

/// Friends list and friend requests screen.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, required this.text});

  final AppText text;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _friendships = [];
  bool _loading = true;
  bool _offline = false;

  final _searchController = TextEditingController();
  bool _sendingRequest = false;
  String? _sendError;
  String? _sendSuccess;

  String? _challengingUsername;
  String? _challengeError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final friends = await ApiService.instance.getFriends();
      if (!mounted) return;
      setState(() {
        _friendships = friends;
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

  Future<void> _sendRequest() async {
    final username = _searchController.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _sendingRequest = true;
      _sendError = null;
      _sendSuccess = null;
    });

    try {
      await ApiService.instance.sendFriendRequest(username);
      if (!mounted) return;
      setState(() {
        _sendSuccess = '${widget.text.tr('friendsRequestSent')} $username!';
        _searchController.clear();
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sendError = e.isOffline
            ? widget.text.tr('errorOffline')
            : (e.message.isNotEmpty
                  ? e.message
                  : widget.text.tr('friendsFailedSend'));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendError = widget.text.tr('errorUnexpected'));
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  Future<void> _respond(String id, String action) async {
    try {
      await ApiService.instance.respondToFriendRequest(id, action);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {}
  }

  Future<void> _duelFriend(String username) async {
    setState(() {
      _challengingUsername = username;
      _challengeError = null;
    });

    try {
      final result = await ApiService.instance.challengePvp(username);
      if (!mounted) return;
      setState(() => _challengingUsername = null);
      if (result != null) {
        await _showDuelResult(result, username);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _challengingUsername = null;
        _challengeError = e.isOffline
            ? widget.text.tr('errorOffline')
            : (e.message.isNotEmpty
                  ? e.message
                  : widget.text.tr('pvpChallengeFailed'));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _challengingUsername = null;
        _challengeError = widget.text.tr('errorUnexpected');
      });
    }
  }

  Future<void> _showDuelResult(
    Map<String, dynamic> result,
    String opponentName,
  ) async {
    final battleResult = result['result'] as Map<String, dynamic>? ?? {};
    final won = battleResult['challengerWon'] as bool? ?? false;
    final cStr = (battleResult['challengerStrength'] as num?)?.toInt() ?? 0;
    final dStr = (battleResult['defenderStrength'] as num?)?.toInt() ?? 0;

    final winColor = const Color(0xFF7AC97A);
    final loseColor = const Color(0xFFE07070);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _isDark ? const Color(0xFF1F1F2E) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: won ? winColor : loseColor, width: 2),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                won ? Icons.emoji_events_rounded : Icons.sports_kabaddi_rounded,
                size: 56,
                color: won ? const Color(0xFFFFD700) : loseColor,
              ),
              const SizedBox(height: 10),
              Text(
                won
                    ? '⚔️ ${widget.text.tr('pvpWon').toUpperCase()}'
                    : '💀 ${widget.text.tr('pvpLost').toUpperCase()}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: won ? const Color(0xFFFFD700) : loseColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'vs $opponentName',
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.text.tr('pvpYourStr')}: $cStr\n'
                '${widget.text.tr('pvpOpponentStr')}: $dStr',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
              child: Text(widget.text.tr('pvpContinue')),
            ),
          ],
        );
      },
    );
    setState(() => _challengeError = null);
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF191919) : const Color(0xFFF4F4F4);
  Color get _cardBg =>
      _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF);
  Color get _accent => const Color(0xFFD4A84B);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFE2E2E2) : const Color(0xFF1A1A1A);
  Color get _textSecondary =>
      _isDark ? const Color(0xFFB5B5B5) : const Color(0xFF555555);

  List<Map<String, dynamic>> get _accepted => _friendships
      .where((f) => f['status'] == 'accepted')
      .toList(growable: false);

  List<Map<String, dynamic>> get _pending => _friendships
      .where((f) => f['status'] == 'pending')
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          widget.text.tr('friendsTitle'),
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _textSecondary),
            onPressed: _load,
            tooltip: widget.text.tr('refresh'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: _accent,
          unselectedLabelColor: _textSecondary,
          tabs: [
            Tab(
              text: '${widget.text.tr('friendsTitle')} (${_accepted.length})',
            ),
            Tab(
              text: '${widget.text.tr('friendsRequests')} (${_pending.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Add friend search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: widget.text.tr('friendsAddHint'),
                          prefixIcon: const Icon(Icons.person_add_outlined),
                          filled: true,
                          fillColor: _isDark
                              ? const Color(0xFF252525)
                              : const Color(0xFFF0F0F0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendRequest(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _sendingRequest ? null : _sendRequest,
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
                      child: _sendingRequest
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(widget.text.tr('friendsAdd')),
                    ),
                  ],
                ),
                if (_sendError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _sendError!,
                      style: const TextStyle(
                        color: Color(0xFFE07070),
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (_sendSuccess != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _sendSuccess!,
                      style: const TextStyle(
                        color: Color(0xFF7AC97A),
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (_challengeError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _challengeError!,
                      style: const TextStyle(
                        color: Color(0xFFE07070),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _offline
                ? _buildOffline()
                : TabBarView(
                    controller: _tabController,
                    children: [_buildFriendsList(), _buildRequestsList()],
                  ),
          ),
        ],
      ),
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

  Widget _buildFriendsList() {
    if (_accepted.isEmpty) {
      return Center(
        child: Text(
          widget.text.tr('friendsEmpty'),
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _accepted.length,
        itemBuilder: (context, index) {
          final f = _accepted[index];
          final myId = ApiService.instance.currentPlayerId;
          final requester = f['requester'] as Map<String, dynamic>? ?? {};
          final addressee = f['addressee'] as Map<String, dynamic>? ?? {};
          final friend = requester['id'] == myId ? addressee : requester;

          final username = (friend['username'] as String?) ?? '';
          final isChallenging = _challengingUsername == username;

          final friendId = (friend['id'] as String?) ?? '';

          return _FriendCard(
            friend: friend,
            isDark: _isDark,
            cardBg: _cardBg,
            textPrimary: _textPrimary,
            textSecondary: _textSecondary,
            accent: _accent,
            text: widget.text,
            isChallenging: isChallenging,
            onChallenge: (_challengingUsername != null || username.isEmpty)
                ? null
                : () => _duelFriend(username),
            onTap: friendId.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlayerProfileScreen(
                        playerId: friendId,
                        username: username,
                        text: widget.text,
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_pending.isEmpty) {
      return Center(
        child: Text(
          widget.text.tr('friendsNoRequests'),
          style: TextStyle(color: _textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pending.length,
        itemBuilder: (context, index) {
          final f = _pending[index];
          final myId = ApiService.instance.currentPlayerId;
          final requester = f['requester'] as Map<String, dynamic>? ?? {};
          final isIncoming = requester['id'] != myId;

          return _RequestCard(
            friendship: f,
            isIncoming: isIncoming,
            isDark: _isDark,
            cardBg: _cardBg,
            textPrimary: _textPrimary,
            textSecondary: _textSecondary,
            accent: _accent,
            onAccept: isIncoming ? () => _respond(f['id'], 'accept') : null,
            onReject: isIncoming ? () => _respond(f['id'], 'reject') : null,
            text: widget.text,
          );
        },
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.friend,
    required this.isDark,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.text,
    required this.isChallenging,
    required this.onChallenge,
    required this.onTap,
  });

  final Map<String, dynamic> friend;
  final bool isDark;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final AppText text;
  final bool isChallenging;
  final VoidCallback? onChallenge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final username = friend['username'] as String? ?? 'Unbekannt';
    final strength = (friend['total_strength'] as num?)?.toInt() ?? 0;
    final prestige = (friend['prestige_level'] as num?)?.toInt() ?? 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF3B3B3B) : const Color(0xFFDDDDDD),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: accent.withAlpha(60),
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(color: accent, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    '${text.tr('totalStrength')}: $strength · Prestige: $prestige',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isChallenging
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                : FilledButton.tonal(
                    onPressed: onChallenge,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent.withAlpha(40),
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sports_kabaddi_rounded, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          text.tr('pvpChallenge'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.friendship,
    required this.isIncoming,
    required this.isDark,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccept,
    required this.onReject,
    required this.text,
  });

  final Map<String, dynamic> friendship;
  final bool isIncoming;
  final bool isDark;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final AppText text;

  @override
  Widget build(BuildContext context) {
    final myId = ApiService.instance.currentPlayerId;
    final requester = friendship['requester'] as Map<String, dynamic>? ?? {};
    final addressee = friendship['addressee'] as Map<String, dynamic>? ?? {};
    final otherUser = requester['id'] == myId ? addressee : requester;
    final username = otherUser['username'] as String? ?? 'Unbekannt';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isIncoming
              ? accent.withAlpha(100)
              : (isDark ? const Color(0xFF3B3B3B) : const Color(0xFFDDDDDD)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isIncoming
                ? accent.withAlpha(60)
                : Colors.grey.withAlpha(60),
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: TextStyle(
                color: isIncoming ? accent : textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  isIncoming
                      ? text.tr('friendsIncoming')
                      : text.tr('friendsOutgoing'),
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          if (isIncoming) ...[
            IconButton(
              icon: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF7AC97A),
              ),
              onPressed: onAccept,
              tooltip: text.tr('friendsAccept'),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Color(0xFFE07070)),
              onPressed: onReject,
              tooltip: text.tr('friendsReject'),
            ),
          ],
        ],
      ),
    );
  }
}
