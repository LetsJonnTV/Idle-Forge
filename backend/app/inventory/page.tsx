'use client';
import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';

interface Item {
  id: string;
  name: string;
  slot: string;
  tier: string;
  setId: string;
  power: number;
  sellValue: number;
  isLocked: boolean;
  isEquipped: boolean;
  enchantments: unknown[];
}

const SLOT_LABELS: Record<string, string> = {
  weapon: '⚔️ Waffe', armor: '🛡️ Rüstung', helm: '⛑️ Helm',
  gloves: '🧤 Handschuhe', boots: '👢 Stiefel', ring: '💍 Ring',
};
const TIER_ORDER = ['common', 'uncommon', 'rare', 'epic', 'legendary'];
const TIER_LABELS: Record<string, string> = {
  common: 'Gewöhnlich', uncommon: 'Ungewöhnlich', rare: 'Selten',
  epic: 'Episch', legendary: 'Legendär',
};

function useAuth() {
  const router = useRouter();
  const [token, setToken] = useState<string | null>(null);
  const [username, setUsername] = useState('');

  useEffect(() => {
    const t = localStorage.getItem('idle_forge_jwt');
    if (!t) { router.replace('/login'); return; }
    setToken(t);
    setUsername(localStorage.getItem('idle_forge_username') ?? '');
  }, [router]);

  function logout() {
    localStorage.removeItem('idle_forge_jwt');
    localStorage.removeItem('idle_forge_username');
    router.replace('/login');
  }

  return { token, username, logout };
}

export default function InventoryPage() {
  const { token, username, logout } = useAuth();
  const [items, setItems] = useState<Item[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [activeSlot, setActiveSlot] = useState<string>('all');
  const [confirmSell, setConfirmSell] = useState<Item | null>(null);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  const fetchInventory = useCallback(async () => {
    if (!token) return;
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/players/me/inventory', {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.status === 401) { logout(); return; }
      if (!res.ok) throw new Error('Fehler beim Laden');
      const data = await res.json();
      const sorted = (data.items as Item[]).sort(
        (a, b) => b.power - a.power || TIER_ORDER.indexOf(b.tier) - TIER_ORDER.indexOf(a.tier),
      );
      setItems(sorted);
    } catch {
      setError('Inventar konnte nicht geladen werden.');
    } finally {
      setLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  useEffect(() => { fetchInventory(); }, [fetchInventory]);

  async function toggleEquip(item: Item) {
    if (!token) return;
    setActionLoading(item.id);
    try {
      const res = await fetch(`/api/players/me/inventory/${item.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ equip: !item.isEquipped }),
      });
      if (!res.ok) throw new Error();
      // Optimistic update
      setItems(prev => prev.map(i => {
        if (i.slot === item.slot && i.isEquipped && !item.isEquipped) return { ...i, isEquipped: false };
        if (i.id === item.id) return { ...i, isEquipped: !item.isEquipped };
        return i;
      }));
    } catch {
      setError('Aktion fehlgeschlagen.');
    } finally {
      setActionLoading(null);
    }
  }

  async function sellItem(item: Item) {
    if (!token) return;
    setActionLoading(item.id);
    setConfirmSell(null);
    try {
      const res = await fetch(`/api/players/me/inventory/${item.id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error();
      setItems(prev => prev.filter(i => i.id !== item.id));
    } catch {
      setError('Verkauf fehlgeschlagen.');
    } finally {
      setActionLoading(null);
    }
  }

  const slots = ['all', ...Array.from(new Set(items.map(i => i.slot)))];
  const visible = activeSlot === 'all' ? items : items.filter(i => i.slot === activeSlot);
  const equippedCount = items.filter(i => i.isEquipped).length;

  if (!token) return null;

  return (
    <div style={{ minHeight: '100vh', padding: '20px 16px', maxWidth: 900, margin: '0 auto' }}>

      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <div>
          <span style={{ fontSize: 18, fontWeight: 'bold', letterSpacing: 3, color: 'var(--gold)' }}>⚒ IDLE FORGE</span>
          <span style={{ fontSize: 12, color: 'var(--text2)', marginLeft: 12 }}>Inventar</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: 13, color: 'var(--text2)' }}>{username}</span>
          <button className="btn-outline" onClick={logout} style={{ padding: '6px 12px', fontSize: 12 }}>Abmelden</button>
        </div>
      </div>

      {/* Stats bar */}
      <div style={{ display: 'flex', gap: 16, marginBottom: 20, flexWrap: 'wrap' }}>
        {[
          { label: 'Items gesamt', value: items.length },
          { label: 'Ausgerüstet', value: equippedCount },
          { label: 'Episch+', value: items.filter(i => i.tier === 'epic' || i.tier === 'legendary').length },
        ].map(s => (
          <div key={s.label} className="card" style={{ padding: '10px 18px', flex: '1 1 120px' }}>
            <div style={{ fontSize: 20, fontWeight: 'bold', color: 'var(--gold)' }}>{s.value}</div>
            <div style={{ fontSize: 11, color: 'var(--text2)', marginTop: 2 }}>{s.label}</div>
          </div>
        ))}
      </div>

      {/* Slot filter tabs */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 18, flexWrap: 'wrap' }}>
        {slots.map(slot => (
          <button
            key={slot}
            onClick={() => setActiveSlot(slot)}
            style={{
              padding: '6px 14px', fontSize: 12, borderRadius: 20,
              background: activeSlot === slot ? 'var(--gold)' : 'transparent',
              border: `1.5px solid ${activeSlot === slot ? 'var(--gold)' : 'var(--border2)'}`,
              color: activeSlot === slot ? '#1a1000' : 'var(--text2)',
              fontWeight: activeSlot === slot ? 'bold' : 'normal',
            }}
          >
            {slot === 'all' ? `Alle (${items.length})` : `${SLOT_LABELS[slot] ?? slot} (${items.filter(i => i.slot === slot).length})`}
          </button>
        ))}
      </div>

      {/* Error */}
      {error && (
        <div style={{ color: 'var(--red)', fontSize: 13, marginBottom: 14, padding: '10px 14px', background: '#2a0a0a', borderRadius: 8 }}>
          {error}
          <button onClick={() => setError('')} style={{ marginLeft: 10, background: 'none', color: 'var(--red)', fontSize: 12, padding: 0 }}>✕</button>
        </div>
      )}

      {/* Loading */}
      {loading && (
        <div style={{ textAlign: 'center', color: 'var(--text2)', padding: 48 }}>Lade Inventar...</div>
      )}

      {/* Empty state */}
      {!loading && visible.length === 0 && (
        <div style={{ textAlign: 'center', color: 'var(--text2)', padding: 48 }}>
          <div style={{ fontSize: 32, marginBottom: 10 }}>📦</div>
          <div>Keine Items gefunden.</div>
          <div style={{ fontSize: 12, marginTop: 6 }}>Öffne die App und schmied etwas!</div>
        </div>
      )}

      {/* Item grid */}
      {!loading && visible.length > 0 && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 12 }}>
          {visible.map(item => (
            <ItemCard
              key={item.id}
              item={item}
              busy={actionLoading === item.id}
              onEquip={() => toggleEquip(item)}
              onSell={() => setConfirmSell(item)}
            />
          ))}
        </div>
      )}

      {/* Sell confirm dialog */}
      {confirmSell && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24, zIndex: 100,
        }}>
          <div className="card" style={{ maxWidth: 340, width: '100%' }}>
            <div style={{ fontWeight: 'bold', marginBottom: 10 }}>Item verkaufen?</div>
            <div style={{ color: 'var(--text2)', fontSize: 13, marginBottom: 18 }}>
              <span className={`tier-${confirmSell.tier}`}>{confirmSell.name}</span>
              {' '}wird für <span style={{ color: 'var(--gold)' }}>{confirmSell.sellValue} Gold</span> verkauft und aus dem Inventar entfernt.
            </div>
            <div style={{ display: 'flex', gap: 10 }}>
              <button className="btn-outline" onClick={() => setConfirmSell(null)} style={{ flex: 1 }}>Abbrechen</button>
              <button className="btn-danger" onClick={() => sellItem(confirmSell)} style={{ flex: 1 }}>Verkaufen</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function ItemCard({ item, busy, onEquip, onSell }: {
  item: Item;
  busy: boolean;
  onEquip: () => void;
  onSell: () => void;
}) {
  return (
    <div className="card" style={{
      borderColor: item.isEquipped ? '#3a5a1a' : 'var(--border)',
      opacity: busy ? 0.6 : 1,
      transition: 'opacity 0.2s',
    }}>
      {/* Item header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 }}>
        <div>
          <div style={{ fontWeight: 'bold', fontSize: 14, marginBottom: 4 }} className={`tier-${item.tier}`}>
            {item.name}
          </div>
          <div style={{ fontSize: 11, color: 'var(--text2)' }}>
            {SLOT_LABELS[item.slot] ?? item.slot}
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
          <span className={`badge badge-${item.tier}`}>{TIER_LABELS[item.tier] ?? item.tier}</span>
          {item.isEquipped && <span className="badge badge-equipped">Ausgerüstet</span>}
          {item.isLocked && <span style={{ fontSize: 14 }}>🔒</span>}
        </div>
      </div>

      {/* Stats */}
      <div style={{ display: 'flex', gap: 16, marginBottom: 14, fontSize: 13 }}>
        <div><span style={{ color: 'var(--text2)' }}>Stärke </span><span style={{ color: 'var(--gold)', fontWeight: 'bold' }}>{item.power}</span></div>
        <div><span style={{ color: 'var(--text2)' }}>Wert </span><span>{item.sellValue}g</span></div>
        {item.enchantments.length > 0 && (
          <div><span style={{ color: 'var(--text2)' }}>Runen </span><span>{item.enchantments.length}</span></div>
        )}
      </div>

      {/* Actions */}
      <div style={{ display: 'flex', gap: 8 }}>
        <button
          className="btn-outline"
          onClick={onEquip}
          disabled={busy}
          style={{ flex: 1, fontSize: 12, padding: '7px 0' }}
        >
          {item.isEquipped ? 'Ablegen' : 'Ausrüsten'}
        </button>
        <button
          className="btn-danger"
          onClick={onSell}
          disabled={busy || item.isLocked || item.isEquipped}
          title={item.isLocked ? 'Gesperrt' : item.isEquipped ? 'Zuerst ablegen' : undefined}
          style={{ fontSize: 12, padding: '7px 12px' }}
        >
          Verkaufen
        </button>
      </div>
    </div>
  );
}
