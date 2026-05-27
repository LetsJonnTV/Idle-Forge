import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';

/// Coop session screen — create or join a boss fight with a friend.
class CoopScreen extends StatefulWidget {
  const CoopScreen({super.key});

  @override
  State<CoopScreen> createState() => _CoopScreenState();
}

class _CoopScreenState extends State<CoopScreen> {
  final _sessionCodeController = TextEditingController();

  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  bool _offline = false;
  bool _creating = false;
  bool _joining = false;
  String? _errorMessage;

  // Active session state
  Map<String, dynamic>? _activeSession;
  RealtimeChannel? _channel;
  int _bossHp = 1000;
  final int _bossMaxHp = 1000;
  int _myDamage = 0;
  int _partnerDamage = 0;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _leaveChannel();
    _sessionCodeController.dispose();
    super.dispose();
  }

  void _leaveChannel() {
    _channel?.unsubscribe();
    _channel = null;
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final sessions = await ApiService.instance.getCoopSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
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

  Future<void> _createSession() async {
    setState(() {
      _creating = true;
      _errorMessage = null;
    });
    try {
      final session = await ApiService.instance.createCoopSession();
      if (!mounted) return;
      if (session != null) {
        await _enterSession(session);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.isOffline
            ? 'No internet connection.'
            : (e.message.isNotEmpty ? e.message : 'Failed to create session.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unexpected error.');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _joinSession() async {
    final code = _sessionCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _joining = true;
      _errorMessage = null;
    });
    try {
      final session = await ApiService.instance.joinCoopSession(code);
      if (!mounted) return;
      if (session != null) {
        _sessionCodeController.clear();
        await _enterSession(session);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.isOffline
            ? 'No internet connection.'
            : (e.message.isNotEmpty ? e.message : 'Failed to join session.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unexpected error.');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _enterSession(Map<String, dynamic> session) async {
    setState(() {
      _activeSession = session;
      _bossHp = (session['boss_hp'] as int?) ?? _bossMaxHp;
      _myDamage = 0;
      _partnerDamage = 0;
    });

    // Subscribe to Supabase Realtime for damage events
    try {
      final supabase = Supabase.instance.client;
      final sessionId = session['id'] as String;
      _channel = supabase.channel('coop_session_$sessionId')
        ..onBroadcast(
          event: 'damage',
          callback: (payload) {
            if (!mounted) return;
            final damage = (payload['damage'] as num?)?.toInt() ?? 0;
            final senderId = payload['sender_id'] as String?;
            final myId = ApiService.instance.currentPlayerId;
            setState(() {
              _bossHp = (_bossHp - damage).clamp(0, _bossMaxHp);
              if (senderId == myId) {
                _myDamage += damage;
              } else {
                _partnerDamage += damage;
              }
            });
          },
        );
      _channel!.subscribe();
    } catch (_) {
      // Realtime not available — fall back to polling only
    }
  }

  Future<void> _dealDamage() async {
    if (_activeSession == null || _bossHp <= 0) return;
    final damage = 50 + (DateTime.now().millisecond % 50); // 50-99
    final myId = ApiService.instance.currentPlayerId ?? '';

    try {
      await _channel?.sendBroadcastMessage(
        event: 'damage',
        payload: {'damage': damage, 'sender_id': myId},
      );
      if (mounted) {
        setState(() {
          _bossHp = (_bossHp - damage).clamp(0, _bossMaxHp);
          _myDamage += damage;
        });
      }
    } catch (_) {
      // Fallback: apply locally
      if (mounted) {
        setState(() {
          _bossHp = (_bossHp - damage).clamp(0, _bossMaxHp);
          _myDamage += damage;
        });
      }
    }
  }

  void _leaveSession() {
    _leaveChannel();
    setState(() {
      _activeSession = null;
      _bossHp = _bossMaxHp;
      _myDamage = 0;
      _partnerDamage = 0;
    });
    _loadSessions();
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

  @override
  Widget build(BuildContext context) {
    if (_activeSession != null) {
      return _buildBattleView();
    }
    return _buildLobbyView();
  }

  Widget _buildLobbyView() {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          'Co-op',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _textSecondary),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: _offline
          ? _buildOffline()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Create session card
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Create Session',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a co-op boss fight and invite a friend.',
                          style: TextStyle(fontSize: 13, color: _textSecondary),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _creating ? null : _createSession,
                          icon: _creating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add_circle_outline),
                          label: const Text('Create'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Join session card
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Join Session',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _sessionCodeController,
                          decoration: InputDecoration(
                            hintText: 'Paste session ID...',
                            prefixIcon: const Icon(Icons.link_rounded),
                            filled: true,
                            fillColor: _isDark
                                ? const Color(0xFF252525)
                                : const Color(0xFFF0F0F0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _joinSession(),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _joining ? null : _joinSession,
                          icon: _joining
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: const Text('Join'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4A7A6A),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFE07070),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Active sessions
                  if (!_loading && _sessions.isNotEmpty) ...[
                    Text(
                      'Your Active Sessions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._sessions.map(
                      (s) => _SessionCard(
                        session: s,
                        isDark: _isDark,
                        cardBg: _cardBg,
                        textPrimary: _textPrimary,
                        textSecondary: _textSecondary,
                        accent: _accent,
                        onJoin: () => _enterSession(s),
                      ),
                    ),
                  ],
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDark ? const Color(0xFF3B3B3B) : const Color(0xFFDDDDDD),
        ),
      ),
      child: child,
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
            'Co-op not available offline',
            style: TextStyle(color: _textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: _loadSessions,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleView() {
    final session = _activeSession!;
    final sessionId = session['id'] as String? ?? '';
    final host = session['host'] as Map<String, dynamic>? ?? {};
    final guest = session['guest'] as Map<String, dynamic>? ?? {};
    final hostName = host['username'] as String? ?? 'Host';
    final guestName = guest['username'] as String? ?? 'Waiting...';
    final hpRatio = _bossHp / _bossMaxHp;
    final bossDefeated = _bossHp <= 0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          'Co-op Battle',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: _textSecondary),
          onPressed: _leaveSession,
          tooltip: 'Leave session',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Session ID (for sharing)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: sessionId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Session ID copied to clipboard'),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isDark
                      ? const Color(0xFF252525)
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 16, color: _textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Session: $sessionId',
                        style: TextStyle(fontSize: 11, color: _textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Players
            Row(
              children: [
                Expanded(
                  child: _PlayerBox(
                    name: hostName,
                    damage: _myDamage,
                    accent: _accent,
                    textPrimary: _textPrimary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: _PlayerBox(
                    name: guestName,
                    damage: _partnerDamage,
                    accent: const Color(0xFF7AC97A),
                    textPrimary: _textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Boss HP bar
            Text(
              '👹 Boss',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: hpRatio,
                minHeight: 20,
                backgroundColor: _isDark
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFFDDDDDD),
                valueColor: AlwaysStoppedAnimation<Color>(
                  hpRatio > 0.5
                      ? const Color(0xFF7AC97A)
                      : hpRatio > 0.25
                      ? const Color(0xFFD4A84B)
                      : const Color(0xFFE07070),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_bossHp / $_bossMaxHp HP',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 32),

            // Attack button
            if (!bossDefeated)
              FilledButton.icon(
                onPressed: _dealDamage,
                icon: const Icon(Icons.flash_on_rounded, size: 22),
                label: const Text(
                  'Attack!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB84040),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )
            else
              Column(
                children: [
                  const Text(
                    '🏆 Boss Defeated!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _leaveSession,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Collect Reward'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerBox extends StatelessWidget {
  const _PlayerBox({
    required this.name,
    required this.damage,
    required this.accent,
    required this.textPrimary,
  });

  final String name;
  final int damage;
  final Color accent;
  final Color textPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(80)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: accent.withAlpha(60),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: accent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textPrimary,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            '$damage dmg',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isDark,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onJoin,
  });

  final Map<String, dynamic> session;
  final bool isDark;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final host = session['host'] as Map<String, dynamic>? ?? {};
    final status = session['status'] as String? ?? 'waiting';
    final hostName = host['username'] as String? ?? 'Unknown';

    return Container(
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
          Icon(
            status == 'active'
                ? Icons.sports_esports_rounded
                : Icons.hourglass_empty_rounded,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Host: $hostName',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  status == 'waiting' ? 'Waiting for partner' : 'Active',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          FilledButton.tonal(onPressed: onJoin, child: const Text('Enter')),
        ],
      ),
    );
  }
}
