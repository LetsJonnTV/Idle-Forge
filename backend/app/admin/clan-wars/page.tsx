'use client';
import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';

interface Clan { id: string; name: string; }
interface War {
  id: string;
  status: string;
  clan_a_name: string;
  clan_b_name: string;
  clan_a_points: number;
  clan_b_points: number;
  winner_name: string | null;
  participant_count: number;
  started_at: string;
  ends_at: string;
}

function useAdminAuth() {
  const router = useRouter();
  const [token, setToken] = useState<string | null>(null);
  useEffect(() => {
    const t = localStorage.getItem('idle_forge_jwt');
    if (!t) { router.replace('/login'); return; }
    setToken(t);
  }, [router]);
  return token;
}

export default function ClanWarsPage() {
  const token = useAdminAuth();
  const [wars, setWars] = useState<War[]>([]);
  const [clans, setClans] = useState<Clan[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [clanAId, setClanAId] = useState('');
  const [clanBId, setClanBId] = useState('');
  const [durationDays, setDurationDays] = useState('7');
  const [creating, setCreating] = useState(false);

  const headers = useCallback(() => ({
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  }), [token]);

  const fetchWars = useCallback(async () => {
    if (!token) return;
    setLoading(true);
    try {
      const res = await fetch('/api/admin/clan_wars', { headers: headers() });
      if (!res.ok) throw new Error('Failed');
      const data = await res.json();
      setWars(data.wars ?? []);
    } catch {
      setError('Fehler beim Laden der Gildenkämpfe.');
    } finally {
      setLoading(false);
    }
  }, [token, headers]);

  const fetchClans = useCallback(async () => {
    if (!token) return;
    try {
      const res = await fetch('/api/clans', { headers: headers() });
      if (!res.ok) return;
      const data = await res.json();
      setClans(data.clans ?? []);
    } catch { /* ignore */ }
  }, [token, headers]);

  useEffect(() => {
    fetchWars();
    fetchClans();
  }, [fetchWars, fetchClans]);

  async function createWar() {
    if (!clanAId || !clanBId) { setError('Bitte beide Clans auswählen.'); return; }
    if (clanAId === clanBId) { setError('Clans müssen verschieden sein.'); return; }
    setCreating(true);
    setError('');
    setSuccess('');
    try {
      const res = await fetch('/api/admin/clan_wars', {
        method: 'POST',
        headers: headers(),
        body: JSON.stringify({ clan_a_id: clanAId, clan_b_id: clanBId, duration_days: Number(durationDays) }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? 'Fehler');
      setSuccess('Gildenkampf gestartet!');
      setClanAId(''); setClanBId('');
      fetchWars();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Fehler');
    } finally {
      setCreating(false);
    }
  }

  async function cancelWar(id: string) {
    if (!confirm('Gildenkampf wirklich abbrechen?')) return;
    try {
      const res = await fetch(`/api/admin/clan_wars?id=${id}`, { method: 'DELETE', headers: headers() });
      if (!res.ok) throw new Error('Fehler');
      setSuccess('Krieg abgebrochen.');
      fetchWars();
    } catch {
      setError('Fehler beim Abbrechen.');
    }
  }

  const activeWars = wars.filter(w => w.status === 'active');
  const pastWars = wars.filter(w => w.status !== 'active');

  return (
    <div style={{ minHeight: '100vh', padding: '20px 16px', maxWidth: 960, margin: '0 auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <span style={{ fontSize: 18, fontWeight: 'bold', letterSpacing: 3, color: 'var(--gold)' }}>⚒ IDLE FORGE — Admin</span>
        <nav style={{ display: 'flex', gap: 8 }}>
          <a href="/admin/auctions" style={{ padding: '5px 12px', fontSize: 12, color: 'var(--text2)' }}>Auktionen</a>
        </nav>
      </div>

      <h2 style={{ color: 'var(--gold)', marginBottom: 20 }}>⚔️ Gildenkämpfe</h2>

      {error && <div style={{ color: 'var(--red)', background: '#2a0a0a', padding: '10px 14px', borderRadius: 8, marginBottom: 14 }}>{error}</div>}
      {success && <div style={{ color: '#50c878', background: '#0a2a14', padding: '10px 14px', borderRadius: 8, marginBottom: 14 }}>{success}</div>}

      {/* Create War */}
      <div className="card" style={{ marginBottom: 24 }}>
        <div style={{ fontWeight: 'bold', marginBottom: 14 }}>Neuen Gildenkampf starten</div>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'flex-end' }}>
          <div>
            <div style={{ fontSize: 11, color: 'var(--text2)', marginBottom: 4 }}>Clan A</div>
            <select value={clanAId} onChange={e => setClanAId(e.target.value)} style={{ padding: '8px 12px', borderRadius: 6, background: 'var(--card)', border: '1px solid var(--border)', color: 'var(--text1)', minWidth: 180 }}>
              <option value="">— Clan wählen —</option>
              {clans.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </div>
          <div>
            <div style={{ fontSize: 11, color: 'var(--text2)', marginBottom: 4 }}>Clan B</div>
            <select value={clanBId} onChange={e => setClanBId(e.target.value)} style={{ padding: '8px 12px', borderRadius: 6, background: 'var(--card)', border: '1px solid var(--border)', color: 'var(--text1)', minWidth: 180 }}>
              <option value="">— Clan wählen —</option>
              {clans.filter(c => c.id !== clanAId).map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </div>
          <div>
            <div style={{ fontSize: 11, color: 'var(--text2)', marginBottom: 4 }}>Dauer (Tage)</div>
            <select value={durationDays} onChange={e => setDurationDays(e.target.value)} style={{ padding: '8px 12px', borderRadius: 6, background: 'var(--card)', border: '1px solid var(--border)', color: 'var(--text1)' }}>
              {[1, 3, 5, 7, 14].map(d => <option key={d} value={d}>{d}</option>)}
            </select>
          </div>
          <button className="btn-outline" onClick={createWar} disabled={creating} style={{ padding: '9px 18px' }}>
            {creating ? 'Wird erstellt...' : 'Starten'}
          </button>
        </div>
      </div>

      {/* Active Wars */}
      <div style={{ fontWeight: 'bold', marginBottom: 10, color: '#50c878' }}>Aktive Kämpfe ({activeWars.length})</div>
      {loading ? <div style={{ color: 'var(--text2)', padding: 20 }}>Lade...</div> : activeWars.length === 0 ? (
        <div style={{ color: 'var(--text2)', fontSize: 13, marginBottom: 20 }}>Keine aktiven Kämpfe.</div>
      ) : (
        <div style={{ marginBottom: 24 }}>
          {activeWars.map(w => (
            <WarRow key={w.id} war={w} onCancel={() => cancelWar(w.id)} />
          ))}
        </div>
      )}

      {/* Past Wars */}
      {pastWars.length > 0 && (
        <>
          <div style={{ fontWeight: 'bold', marginBottom: 10, color: 'var(--text2)' }}>Vergangene Kämpfe</div>
          {pastWars.map(w => <WarRow key={w.id} war={w} />)}
        </>
      )}
    </div>
  );
}

function WarRow({ war, onCancel }: { war: War; onCancel?: () => void }) {
  const aWins = war.clan_a_points > war.clan_b_points;
  const bWins = war.clan_b_points > war.clan_a_points;
  return (
    <div className="card" style={{ marginBottom: 10 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          <span style={{ fontWeight: 'bold', color: aWins ? '#50c878' : 'var(--text1)' }}>{war.clan_a_name}</span>
          <span style={{ fontSize: 18, fontWeight: 'bold', color: 'var(--gold)' }}>{war.clan_a_points} — {war.clan_b_points}</span>
          <span style={{ fontWeight: 'bold', color: bWins ? '#50c878' : 'var(--text1)' }}>{war.clan_b_name}</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: 11, color: 'var(--text2)' }}>{war.participant_count} Teilnehmer</span>
          <span style={{ fontSize: 11, color: war.status === 'active' ? '#50c878' : 'var(--text2)' }}>
            {war.status === 'active' ? '🟢 Aktiv' : war.winner_name ? `✓ ${war.winner_name} gewonnen` : '— Unentschieden'}
          </span>
          {onCancel && (
            <button className="btn-danger" onClick={onCancel} style={{ fontSize: 11, padding: '4px 10px' }}>Abbrechen</button>
          )}
        </div>
      </div>
      <div style={{ fontSize: 11, color: 'var(--text2)', marginTop: 6 }}>
        {new Date(war.started_at).toLocaleDateString('de')} → {new Date(war.ends_at).toLocaleDateString('de')}
      </div>
    </div>
  );
}
