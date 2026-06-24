'use client';
import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';

interface AuctionEntry {
  id: string;
  status: string;
  item: { name: string; slot: string; tier: string; power: number };
  minPrice: number;
  buyNowPrice: number | null;
  currentBid: number;
  bidCount: number;
  claimed: boolean;
  endsAt: string;
  createdAt: string;
  sellerName: string;
  highestBidderName: string | null;
}

interface Stats {
  active: number;
  sold: number;
  expired: number;
  cancelled: number;
  total_volume: string;
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

export default function AuctionsPage() {
  const token = useAdminAuth();
  const [auctions, setAuctions] = useState<AuctionEntry[]>([]);
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [statusFilter, setStatusFilter] = useState('active');
  const [page, setPage] = useState(1);

  const headers = useCallback(() => ({
    Authorization: `Bearer ${token}`,
  }), [token]);

  const fetchAuctions = useCallback(async () => {
    if (!token) return;
    setLoading(true);
    setError('');
    try {
      const res = await fetch(`/api/admin/auctions?status=${statusFilter}&page=${page}`, { headers: headers() });
      if (!res.ok) throw new Error('Failed');
      const data = await res.json();
      setAuctions(data.auctions ?? []);
      setStats(data.stats ?? null);
    } catch {
      setError('Fehler beim Laden der Auktionen.');
    } finally {
      setLoading(false);
    }
  }, [token, statusFilter, page, headers]);

  useEffect(() => { fetchAuctions(); }, [fetchAuctions]);

  async function cancelAuction(id: string) {
    if (!confirm('Auktion wirklich stornieren und Item zurückgeben?')) return;
    try {
      const res = await fetch(`/api/admin/auctions?id=${id}`, { method: 'DELETE', headers: headers() });
      if (!res.ok) throw new Error('Fehler');
      setSuccess('Auktion storniert.');
      fetchAuctions();
    } catch {
      setError('Fehler beim Stornieren.');
    }
  }

  const TIER_COLORS: Record<string, string> = {
    legendary: '#FFAA00', epic: '#AA44FF', rare: '#4488FF', uncommon: '#44BB44', common: '#BBBBBB',
  };

  return (
    <div style={{ minHeight: '100vh', padding: '20px 16px', maxWidth: 1100, margin: '0 auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <span style={{ fontSize: 18, fontWeight: 'bold', letterSpacing: 3, color: 'var(--gold)' }}>⚒ IDLE FORGE — Admin</span>
        <nav style={{ display: 'flex', gap: 8 }}>
          <a href="/admin/clan-wars" style={{ padding: '5px 12px', fontSize: 12, color: 'var(--text2)' }}>Gildenkämpfe</a>
        </nav>
      </div>

      <h2 style={{ color: 'var(--gold)', marginBottom: 20 }}>🏪 Auktionshaus</h2>

      {error && <div style={{ color: 'var(--red)', background: '#2a0a0a', padding: '10px 14px', borderRadius: 8, marginBottom: 14 }}>{error}</div>}
      {success && <div style={{ color: '#50c878', background: '#0a2a14', padding: '10px 14px', borderRadius: 8, marginBottom: 14 }}>{success}</div>}

      {/* Stats */}
      {stats && (
        <div style={{ display: 'flex', gap: 12, marginBottom: 24, flexWrap: 'wrap' }}>
          {[
            { label: 'Aktiv', value: stats.active, color: '#50c878' },
            { label: 'Verkauft', value: stats.sold, color: 'var(--gold)' },
            { label: 'Abgelaufen', value: stats.expired, color: 'var(--text2)' },
            { label: 'Storniert', value: stats.cancelled, color: 'var(--red)' },
            { label: 'Gesamtvolumen', value: `${Number(stats.total_volume).toLocaleString()} Gold`, color: 'var(--gold)' },
          ].map(s => (
            <div key={s.label} className="card" style={{ padding: '10px 16px', flex: '1 1 120px' }}>
              <div style={{ fontSize: 18, fontWeight: 'bold', color: s.color }}>{s.value}</div>
              <div style={{ fontSize: 11, color: 'var(--text2)', marginTop: 2 }}>{s.label}</div>
            </div>
          ))}
        </div>
      )}

      {/* Filters */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {['active', 'sold', 'expired', 'cancelled', 'all'].map(s => (
          <button
            key={s}
            onClick={() => { setStatusFilter(s); setPage(1); }}
            style={{
              padding: '6px 14px', fontSize: 12, borderRadius: 20,
              background: statusFilter === s ? 'var(--gold)' : 'transparent',
              border: `1.5px solid ${statusFilter === s ? 'var(--gold)' : 'var(--border2)'}`,
              color: statusFilter === s ? '#1a1000' : 'var(--text2)',
              fontWeight: statusFilter === s ? 'bold' : 'normal',
            }}
          >{s}</button>
        ))}
        <button className="btn-outline" onClick={fetchAuctions} style={{ marginLeft: 'auto', padding: '6px 12px', fontSize: 12 }}>↻ Aktualisieren</button>
      </div>

      {loading ? (
        <div style={{ color: 'var(--text2)', padding: 20 }}>Lade Auktionen...</div>
      ) : auctions.length === 0 ? (
        <div style={{ color: 'var(--text2)', padding: 20 }}>Keine Auktionen gefunden.</div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: 12 }}>
          {auctions.map(a => (
            <div key={a.id} className="card">
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                <span style={{ fontWeight: 'bold', color: TIER_COLORS[a.item?.tier] ?? 'var(--text1)', fontSize: 14 }}>
                  {a.item?.name ?? '?'}
                </span>
                <span style={{
                  fontSize: 11, padding: '2px 8px', borderRadius: 10,
                  background: a.status === 'active' ? '#0a2a14' : a.status === 'sold' ? '#1a1200' : '#1a0a0a',
                  color: a.status === 'active' ? '#50c878' : a.status === 'sold' ? 'var(--gold)' : 'var(--red)',
                }}>{a.status}</span>
              </div>
              <div style={{ fontSize: 12, color: 'var(--text2)', marginBottom: 4 }}>
                {a.item?.slot} · {a.item?.tier} · ⚡{a.item?.power}
              </div>
              <div style={{ fontSize: 12, marginBottom: 4 }}>
                <span style={{ color: 'var(--text2)' }}>Startpreis: </span>
                <span style={{ color: 'var(--gold)' }}>{a.minPrice}</span>
                {a.buyNowPrice && <span style={{ color: 'var(--text2)' }}> · Sofort: <span style={{ color: '#50c878' }}>{a.buyNowPrice}</span></span>}
              </div>
              {a.currentBid > 0 && (
                <div style={{ fontSize: 12, marginBottom: 4 }}>
                  <span style={{ color: 'var(--text2)' }}>Höchstgebot: </span>
                  <span style={{ color: 'var(--gold)', fontWeight: 'bold' }}>{a.currentBid}</span>
                  {a.highestBidderName && <span style={{ color: 'var(--text2)' }}> von {a.highestBidderName}</span>}
                </div>
              )}
              <div style={{ fontSize: 11, color: 'var(--text2)', marginBottom: 8 }}>
                Verkäufer: {a.sellerName} · {a.bidCount} Gebote
              </div>
              <div style={{ fontSize: 11, color: 'var(--text2)', marginBottom: 8 }}>
                Endet: {new Date(a.endsAt).toLocaleString('de')}
              </div>
              {a.status === 'active' && (
                <button className="btn-danger" onClick={() => cancelAuction(a.id)} style={{ fontSize: 11, padding: '4px 10px' }}>
                  Stornieren
                </button>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Pagination */}
      {auctions.length === 25 || page > 1 ? (
        <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginTop: 20 }}>
          <button className="btn-outline" onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>← Zurück</button>
          <span style={{ padding: '8px 16px', color: 'var(--text2)' }}>Seite {page}</span>
          <button className="btn-outline" onClick={() => setPage(p => p + 1)} disabled={auctions.length < 25}>Weiter →</button>
        </div>
      ) : null}
    </div>
  );
}
