'use client';
import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';

// ── Types ──────────────────────────────────────────────────────────────────────

interface AdminEvent {
  id: string;
  name: string;
  description: string;
  starts_at: string;
  ends_at: string;
  currency_name: string;
  banner_color: string;
  item_count: number;
  total_currency_distributed: number;
  status: 'active' | 'upcoming' | 'expired';
}

interface ShopItem {
  id: string;
  name: string;
  description: string;
  icon: string;
  currency_cost: number;
  max_per_player: number;
  sort_order: number;
  purchase_count: number;
}

// ── Auth hook ──────────────────────────────────────────────────────────────────

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

// ── Helpers ────────────────────────────────────────────────────────────────────

function fmtDate(iso: string) {
  return new Date(iso).toLocaleString('de-DE', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

function toInputLocal(iso: string) {
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function StatusBadge({ status }: { status: AdminEvent['status'] }) {
  const cfg: Record<string, { label: string; color: string; bg: string }> = {
    active:   { label: 'AKTIV',     color: '#7ac040', bg: '#1a2a0a' },
    upcoming: { label: 'GEPLANT',   color: '#4488ee', bg: '#0e1e3a' },
    expired:  { label: 'BEENDET',   color: '#9a8860', bg: '#1a1a1a' },
  };
  const s = cfg[status];
  return (
    <span className="badge" style={{ background: s.bg, color: s.color }}>{s.label}</span>
  );
}

// ── Main page ──────────────────────────────────────────────────────────────────

export default function EventsPage() {
  const { token, username, logout } = useAuth();
  const [view, setView] = useState<'list' | 'detail'>('list');
  const [events, setEvents] = useState<AdminEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Detail view state
  const [selectedEvent, setSelectedEvent] = useState<AdminEvent | null>(null);
  const [items, setItems] = useState<ShopItem[]>([]);
  const [itemsLoading, setItemsLoading] = useState(false);

  // Create event form
  const [showCreate, setShowCreate] = useState(false);
  const [createForm, setCreateForm] = useState({
    name: '', description: '', starts_at: '', ends_at: '',
    currency_name: 'Event-Münzen', banner_color: '#D4A84B',
  });
  const [creating, setCreating] = useState(false);

  // Add item form
  const [showAddItem, setShowAddItem] = useState(false);
  const [itemForm, setItemForm] = useState({
    name: '', description: '', icon: 'event',
    currency_cost: '', max_per_player: '1', sort_order: '0',
  });
  const [addingItem, setAddingItem] = useState(false);

  // Give currency form
  const [giveUsername, setGiveUsername] = useState('');
  const [giveAmount, setGiveAmount] = useState('');
  const [giving, setGiving] = useState(false);
  const [giveResult, setGiveResult] = useState('');

  // ── Fetchers ────────────────────────────────────────────────────────────────

  const fetchEvents = useCallback(async () => {
    if (!token) return;
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/admin/events', {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.status === 401) { logout(); return; }
      if (!res.ok) throw new Error();
      const data = await res.json();
      setEvents(data.events ?? []);
    } catch {
      setError('Events konnten nicht geladen werden.');
    } finally {
      setLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  const fetchItems = useCallback(async (eventId: string) => {
    if (!token) return;
    setItemsLoading(true);
    try {
      const res = await fetch(`/api/admin/events/${eventId}/items`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error();
      const data = await res.json();
      setItems(data.items ?? []);
    } catch {
      setError('Items konnten nicht geladen werden.');
    } finally {
      setItemsLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  useEffect(() => { fetchEvents(); }, [fetchEvents]);

  // ── Actions ──────────────────────────────────────────────────────────────────

  async function createEvent() {
    if (!token || creating) return;
    const { name, starts_at, ends_at } = createForm;
    if (!name.trim() || !starts_at || !ends_at) {
      setError('Name, Startdatum und Enddatum sind Pflichtfelder.');
      return;
    }
    setCreating(true);
    setError('');
    try {
      const res = await fetch('/api/admin/events', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({
          ...createForm,
          starts_at: new Date(createForm.starts_at).toISOString(),
          ends_at: new Date(createForm.ends_at).toISOString(),
        }),
      });
      if (!res.ok) {
        const d = await res.json().catch(() => ({}));
        throw new Error(d.error ?? 'Fehler');
      }
      setShowCreate(false);
      setCreateForm({ name: '', description: '', starts_at: '', ends_at: '', currency_name: 'Event-Münzen', banner_color: '#D4A84B' });
      await fetchEvents();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Event konnte nicht erstellt werden.');
    } finally {
      setCreating(false);
    }
  }

  function openDetail(event: AdminEvent) {
    setSelectedEvent(event);
    setView('detail');
    setItems([]);
    setShowAddItem(false);
    setGiveUsername('');
    setGiveAmount('');
    setGiveResult('');
    fetchItems(event.id);
  }

  function backToList() {
    setView('list');
    setSelectedEvent(null);
    fetchEvents();
  }

  async function endNow(event: AdminEvent) {
    if (!token) return;
    if (!confirm(`Event "${event.name}" jetzt beenden?`)) return;
    try {
      const res = await fetch(`/api/admin/events/${event.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ end_now: true }),
      });
      if (!res.ok) throw new Error();
      if (selectedEvent?.id === event.id) {
        const updated = await res.json();
        setSelectedEvent(updated.event);
      }
      await fetchEvents();
    } catch {
      setError('Konnte Event nicht beenden.');
    }
  }

  async function deleteEvent(event: AdminEvent) {
    if (!token) return;
    if (!confirm(`Event "${event.name}" unwiderruflich löschen?\nAlle Shop-Items und Spielerdaten werden entfernt.`)) return;
    try {
      const res = await fetch(`/api/admin/events/${event.id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error();
      if (view === 'detail') backToList();
      else await fetchEvents();
    } catch {
      setError('Event konnte nicht gelöscht werden.');
    }
  }

  async function addItem() {
    if (!token || addingItem || !selectedEvent) return;
    const { name, currency_cost } = itemForm;
    if (!name.trim() || !currency_cost) {
      setError('Name und Kosten sind Pflichtfelder.');
      return;
    }
    setAddingItem(true);
    setError('');
    try {
      const res = await fetch(`/api/admin/events/${selectedEvent.id}/items`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({
          name: itemForm.name.trim(),
          description: itemForm.description,
          icon: itemForm.icon || 'event',
          currency_cost: parseInt(itemForm.currency_cost),
          max_per_player: parseInt(itemForm.max_per_player) || 1,
          sort_order: parseInt(itemForm.sort_order) || 0,
        }),
      });
      if (!res.ok) {
        const d = await res.json().catch(() => ({}));
        throw new Error(d.error ?? 'Fehler');
      }
      setShowAddItem(false);
      setItemForm({ name: '', description: '', icon: 'event', currency_cost: '', max_per_player: '1', sort_order: '0' });
      await fetchItems(selectedEvent.id);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Item konnte nicht hinzugefügt werden.');
    } finally {
      setAddingItem(false);
    }
  }

  async function deleteItem(item: ShopItem) {
    if (!token || !selectedEvent) return;
    if (!confirm(`Item "${item.name}" löschen?`)) return;
    try {
      const res = await fetch(`/api/admin/events/${selectedEvent.id}/items/${item.id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error();
      setItems(prev => prev.filter(i => i.id !== item.id));
    } catch {
      setError('Item konnte nicht gelöscht werden.');
    }
  }

  async function giveCurrency() {
    if (!token || giving || !selectedEvent) return;
    const amount = parseInt(giveAmount);
    if (!giveUsername.trim() || !amount || amount <= 0) {
      setGiveResult('Spielername und Betrag (> 0) erforderlich.');
      return;
    }
    setGiving(true);
    setGiveResult('');
    try {
      const res = await fetch(`/api/admin/events/${selectedEvent.id}/give_currency`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ username: giveUsername.trim(), amount }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? 'Fehler');
      setGiveResult(`✓ ${giveUsername} hat jetzt ${data.new_balance} ${selectedEvent.currency_name}.`);
      setGiveUsername('');
      setGiveAmount('');
    } catch (e: unknown) {
      setGiveResult(e instanceof Error ? e.message : 'Fehler');
    } finally {
      setGiving(false);
    }
  }

  if (!token) return null;

  // ── Render ──────────────────────────────────────────────────────────────────

  return (
    <div style={{ minHeight: '100vh', padding: '20px 16px', maxWidth: 960, margin: '0 auto' }}>

      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 20 }}>
          <span style={{ fontSize: 18, fontWeight: 'bold', letterSpacing: 3, color: 'var(--gold)' }}>⚒ IDLE FORGE</span>
          <nav style={{ display: 'flex', gap: 4 }}>
            <a href="/inventory" style={{ padding: '5px 12px', fontSize: 12, borderRadius: 20, color: 'var(--text2)', border: '1.5px solid transparent' }}>Inventar</a>
            <span style={{
              padding: '5px 12px', fontSize: 12, borderRadius: 20,
              background: 'var(--gold)', color: '#1a1000', fontWeight: 'bold',
            }}>Events</span>
          </nav>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: 13, color: 'var(--text2)' }}>{username}</span>
          <button className="btn-outline" onClick={logout} style={{ padding: '6px 12px', fontSize: 12 }}>Abmelden</button>
        </div>
      </div>

      {/* Global error */}
      {error && (
        <div style={{ color: 'var(--red)', fontSize: 13, marginBottom: 14, padding: '10px 14px', background: '#2a0a0a', borderRadius: 8 }}>
          {error}
          <button onClick={() => setError('')} style={{ marginLeft: 10, background: 'none', color: 'var(--red)', fontSize: 12, padding: 0 }}>✕</button>
        </div>
      )}

      {view === 'list' ? (
        <EventListView
          events={events}
          loading={loading}
          showCreate={showCreate}
          setShowCreate={setShowCreate}
          createForm={createForm}
          setCreateForm={setCreateForm}
          creating={creating}
          onCreateSubmit={createEvent}
          onOpenDetail={openDetail}
          onEndNow={endNow}
          onDelete={deleteEvent}
        />
      ) : (
        selectedEvent && (
          <EventDetailView
            event={selectedEvent}
            items={items}
            itemsLoading={itemsLoading}
            showAddItem={showAddItem}
            setShowAddItem={setShowAddItem}
            itemForm={itemForm}
            setItemForm={setItemForm}
            addingItem={addingItem}
            giveUsername={giveUsername}
            setGiveUsername={setGiveUsername}
            giveAmount={giveAmount}
            setGiveAmount={setGiveAmount}
            giving={giving}
            giveResult={giveResult}
            onBack={backToList}
            onEndNow={() => endNow(selectedEvent)}
            onDelete={() => deleteEvent(selectedEvent)}
            onAddItem={addItem}
            onDeleteItem={deleteItem}
            onGiveCurrency={giveCurrency}
          />
        )
      )}
    </div>
  );
}

// ── List view ──────────────────────────────────────────────────────────────────

function EventListView({
  events, loading, showCreate, setShowCreate,
  createForm, setCreateForm, creating, onCreateSubmit,
  onOpenDetail, onEndNow, onDelete,
}: {
  events: AdminEvent[];
  loading: boolean;
  showCreate: boolean;
  setShowCreate: (v: boolean) => void;
  createForm: { name: string; description: string; starts_at: string; ends_at: string; currency_name: string; banner_color: string };
  setCreateForm: (f: typeof createForm) => void;
  creating: boolean;
  onCreateSubmit: () => void;
  onOpenDetail: (e: AdminEvent) => void;
  onEndNow: (e: AdminEvent) => void;
  onDelete: (e: AdminEvent) => void;
}) {
  const active = events.filter(e => e.status === 'active').length;
  const upcoming = events.filter(e => e.status === 'upcoming').length;

  return (
    <>
      {/* Stats */}
      <div style={{ display: 'flex', gap: 12, marginBottom: 20, flexWrap: 'wrap' }}>
        {[
          { label: 'Events gesamt', value: events.length },
          { label: 'Aktiv', value: active },
          { label: 'Geplant', value: upcoming },
        ].map(s => (
          <div key={s.label} className="card" style={{ padding: '10px 18px', flex: '1 1 120px' }}>
            <div style={{ fontSize: 20, fontWeight: 'bold', color: 'var(--gold)' }}>{s.value}</div>
            <div style={{ fontSize: 11, color: 'var(--text2)', marginTop: 2 }}>{s.label}</div>
          </div>
        ))}
        <div style={{ display: 'flex', alignItems: 'center', marginLeft: 'auto' }}>
          <button
            className="btn-gold"
            onClick={() => setShowCreate(!showCreate)}
            style={{ padding: '10px 18px' }}
          >
            {showCreate ? '✕ Abbrechen' : '+ Neues Event'}
          </button>
        </div>
      </div>

      {/* Create form */}
      {showCreate && (
        <div className="card" style={{ marginBottom: 20 }}>
          <div style={{ fontWeight: 'bold', marginBottom: 16, color: 'var(--gold)' }}>Neues Seasonal Event</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div style={{ gridColumn: '1 / -1' }}>
              <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 4 }}>Name *</label>
              <input
                value={createForm.name}
                onChange={e => setCreateForm({ ...createForm, name: e.target.value })}
                placeholder="z.B. Sommerfest 2025"
              />
            </div>
            <div style={{ gridColumn: '1 / -1' }}>
              <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 4 }}>Beschreibung</label>
              <input
                value={createForm.description}
                onChange={e => setCreateForm({ ...createForm, description: e.target.value })}
                placeholder="Kurze Beschreibung des Events"
              />
            </div>
            <div>
              <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 4 }}>Startdatum *</label>
              <input
                type="datetime-local"
                value={createForm.starts_at}
                onChange={e => setCreateForm({ ...createForm, starts_at: e.target.value })}
              />
            </div>
            <div>
              <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 4 }}>Enddatum *</label>
              <input
                type="datetime-local"
                value={createForm.ends_at}
                onChange={e => setCreateForm({ ...createForm, ends_at: e.target.value })}
              />
            </div>
            <div>
              <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 4 }}>Währungsname</label>
              <input
                value={createForm.currency_name}
                onChange={e => setCreateForm({ ...createForm, currency_name: e.target.value })}
                placeholder="Event-Münzen"
              />
            </div>
            <div>
              <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 4 }}>
                Banner-Farbe
                <span style={{
                  display: 'inline-block', width: 14, height: 14, borderRadius: 3, marginLeft: 6,
                  background: createForm.banner_color, verticalAlign: 'middle',
                }} />
              </label>
              <input
                value={createForm.banner_color}
                onChange={e => setCreateForm({ ...createForm, banner_color: e.target.value })}
                placeholder="#D4A84B"
              />
            </div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 16 }}>
            <button
              className="btn-gold"
              onClick={onCreateSubmit}
              disabled={creating}
              style={{ padding: '10px 24px' }}
            >
              {creating ? 'Erstelle...' : 'Event erstellen'}
            </button>
          </div>
        </div>
      )}

      {/* Events list */}
      {loading && <div style={{ textAlign: 'center', color: 'var(--text2)', padding: 48 }}>Lade Events...</div>}
      {!loading && events.length === 0 && (
        <div style={{ textAlign: 'center', color: 'var(--text2)', padding: 48 }}>
          <div style={{ fontSize: 32, marginBottom: 10 }}>🎪</div>
          <div>Noch keine Events erstellt.</div>
          <div style={{ fontSize: 12, marginTop: 6 }}>Klicke &quot;Neues Event&quot; um zu starten.</div>
        </div>
      )}
      {!loading && events.length > 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {events.map(event => (
            <div
              key={event.id}
              className="card"
              style={{ borderColor: event.status === 'active' ? '#3a5a1a' : 'var(--border)' }}
            >
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
                {/* Color swatch */}
                <div style={{
                  width: 40, height: 40, borderRadius: 8, flexShrink: 0,
                  background: event.banner_color, border: '1.5px solid rgba(255,255,255,0.1)',
                }} />

                {/* Info */}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 4, flexWrap: 'wrap' }}>
                    <span style={{ fontWeight: 'bold', fontSize: 15 }}>{event.name}</span>
                    <StatusBadge status={event.status} />
                  </div>
                  <div style={{ fontSize: 12, color: 'var(--text2)', marginBottom: 6 }}>
                    {fmtDate(event.starts_at)} → {fmtDate(event.ends_at)}
                  </div>
                  <div style={{ display: 'flex', gap: 16, fontSize: 12, flexWrap: 'wrap' }}>
                    <span><span style={{ color: 'var(--text2)' }}>Items: </span><span style={{ color: 'var(--gold)' }}>{event.item_count}</span></span>
                    <span><span style={{ color: 'var(--text2)' }}>Währung verteilt: </span><span>{Number(event.total_currency_distributed).toLocaleString('de-DE')} {event.currency_name}</span></span>
                  </div>
                </div>

                {/* Actions */}
                <div style={{ display: 'flex', gap: 8, flexShrink: 0, flexWrap: 'wrap' }}>
                  <button
                    className="btn-outline"
                    onClick={() => onOpenDetail(event)}
                    style={{ fontSize: 12, padding: '6px 14px' }}
                  >
                    Detail
                  </button>
                  {event.status === 'active' && (
                    <button
                      className="btn-outline"
                      onClick={() => onEndNow(event)}
                      style={{ fontSize: 12, padding: '6px 14px', borderColor: '#7a5020', color: '#e09050' }}
                    >
                      Beenden
                    </button>
                  )}
                  <button
                    className="btn-danger"
                    onClick={() => onDelete(event)}
                    style={{ fontSize: 12, padding: '6px 14px' }}
                  >
                    Löschen
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  );
}

// ── Detail view ────────────────────────────────────────────────────────────────

function EventDetailView({
  event, items, itemsLoading, showAddItem, setShowAddItem,
  itemForm, setItemForm, addingItem, giveUsername, setGiveUsername,
  giveAmount, setGiveAmount, giving, giveResult,
  onBack, onEndNow, onDelete, onAddItem, onDeleteItem, onGiveCurrency,
}: {
  event: AdminEvent;
  items: ShopItem[];
  itemsLoading: boolean;
  showAddItem: boolean;
  setShowAddItem: (v: boolean) => void;
  itemForm: { name: string; description: string; icon: string; currency_cost: string; max_per_player: string; sort_order: string };
  setItemForm: (f: typeof itemForm) => void;
  addingItem: boolean;
  giveUsername: string;
  setGiveUsername: (v: string) => void;
  giveAmount: string;
  setGiveAmount: (v: string) => void;
  giving: boolean;
  giveResult: string;
  onBack: () => void;
  onEndNow: () => void;
  onDelete: () => void;
  onAddItem: () => void;
  onDeleteItem: (item: ShopItem) => void;
  onGiveCurrency: () => void;
}) {
  return (
    <>
      {/* Back + header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
        <button className="btn-outline" onClick={onBack} style={{ fontSize: 12, padding: '6px 14px' }}>← Zurück</button>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 20, height: 20, borderRadius: 4, background: event.banner_color, flexShrink: 0 }} />
            <span style={{ fontWeight: 'bold', fontSize: 16 }}>{event.name}</span>
            <StatusBadge status={event.status} />
          </div>
          <div style={{ fontSize: 12, color: 'var(--text2)', marginTop: 4 }}>
            {fmtDate(event.starts_at)} → {fmtDate(event.ends_at)}
            <span style={{ marginLeft: 16 }}>Währung: <span style={{ color: 'var(--gold)' }}>{event.currency_name}</span></span>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          {event.status === 'active' && (
            <button className="btn-outline" onClick={onEndNow} style={{ fontSize: 12, padding: '6px 14px', borderColor: '#7a5020', color: '#e09050' }}>
              Jetzt beenden
            </button>
          )}
          <button className="btn-danger" onClick={onDelete} style={{ fontSize: 12, padding: '6px 14px' }}>Löschen</button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>

        {/* Shop items */}
        <div className="card" style={{ gridColumn: '1 / -1' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
            <span style={{ fontWeight: 'bold', color: 'var(--gold)' }}>Shop-Items ({items.length})</span>
            <button
              className="btn-gold"
              onClick={() => setShowAddItem(!showAddItem)}
              style={{ fontSize: 12, padding: '6px 14px' }}
            >
              {showAddItem ? '✕ Abbrechen' : '+ Item hinzufügen'}
            </button>
          </div>

          {/* Add item form */}
          {showAddItem && (
            <div style={{ marginBottom: 16, padding: 14, background: 'var(--bg3)', borderRadius: 10, border: '1px solid var(--border2)' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 10 }}>
                <div style={{ gridColumn: '1 / -1' }}>
                  <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 3 }}>Name *</label>
                  <input value={itemForm.name} onChange={e => setItemForm({ ...itemForm, name: e.target.value })} placeholder="Item-Name" />
                </div>
                <div style={{ gridColumn: '1 / -1' }}>
                  <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 3 }}>Beschreibung</label>
                  <input value={itemForm.description} onChange={e => setItemForm({ ...itemForm, description: e.target.value })} placeholder="Kurze Beschreibung" />
                </div>
                <div>
                  <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 3 }}>Kosten ({event.currency_name}) *</label>
                  <input type="number" value={itemForm.currency_cost} onChange={e => setItemForm({ ...itemForm, currency_cost: e.target.value })} placeholder="100" min="1" />
                </div>
                <div>
                  <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 3 }}>Max pro Spieler</label>
                  <input type="number" value={itemForm.max_per_player} onChange={e => setItemForm({ ...itemForm, max_per_player: e.target.value })} placeholder="1" min="1" />
                </div>
                <div>
                  <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 3 }}>Icon</label>
                  <input value={itemForm.icon} onChange={e => setItemForm({ ...itemForm, icon: e.target.value })} placeholder="event" />
                </div>
                <div>
                  <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 3 }}>Reihenfolge</label>
                  <input type="number" value={itemForm.sort_order} onChange={e => setItemForm({ ...itemForm, sort_order: e.target.value })} placeholder="0" />
                </div>
              </div>
              <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                <button className="btn-gold" onClick={onAddItem} disabled={addingItem} style={{ fontSize: 12, padding: '8px 18px' }}>
                  {addingItem ? 'Erstelle...' : 'Item erstellen'}
                </button>
              </div>
            </div>
          )}

          {itemsLoading && <div style={{ color: 'var(--text2)', fontSize: 13, padding: '12px 0' }}>Lade Items...</div>}
          {!itemsLoading && items.length === 0 && (
            <div style={{ color: 'var(--text2)', fontSize: 13, padding: '12px 0', textAlign: 'center' }}>
              Noch keine Shop-Items. Klicke &quot;Item hinzufügen&quot;.
            </div>
          )}
          {!itemsLoading && items.length > 0 && (
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
                <thead>
                  <tr style={{ color: 'var(--text2)', textAlign: 'left' }}>
                    <th style={{ padding: '6px 8px', fontWeight: 'normal' }}>Name</th>
                    <th style={{ padding: '6px 8px', fontWeight: 'normal' }}>Kosten</th>
                    <th style={{ padding: '6px 8px', fontWeight: 'normal' }}>Max</th>
                    <th style={{ padding: '6px 8px', fontWeight: 'normal' }}>Käufer</th>
                    <th style={{ padding: '6px 8px', fontWeight: 'normal' }}></th>
                  </tr>
                </thead>
                <tbody>
                  {items.map(item => (
                    <tr key={item.id} style={{ borderTop: '1px solid var(--border2)' }}>
                      <td style={{ padding: '8px 8px' }}>
                        <div style={{ fontWeight: 'bold' }}>{item.name}</div>
                        {item.description && <div style={{ fontSize: 11, color: 'var(--text2)', marginTop: 2 }}>{item.description}</div>}
                      </td>
                      <td style={{ padding: '8px 8px', color: 'var(--gold)' }}>{item.currency_cost.toLocaleString('de-DE')}</td>
                      <td style={{ padding: '8px 8px', color: 'var(--text2)' }}>{item.max_per_player}×</td>
                      <td style={{ padding: '8px 8px' }}>{item.purchase_count}</td>
                      <td style={{ padding: '8px 8px', textAlign: 'right' }}>
                        <button
                          className="btn-danger"
                          onClick={() => onDeleteItem(item)}
                          style={{ fontSize: 11, padding: '4px 10px' }}
                        >
                          Löschen
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* Give currency */}
        <div className="card">
          <div style={{ fontWeight: 'bold', color: 'var(--gold)', marginBottom: 14 }}>Währung vergeben</div>
          <div style={{ marginBottom: 10 }}>
            <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 4 }}>Spielername</label>
            <input
              value={giveUsername}
              onChange={e => setGiveUsername(e.target.value)}
              placeholder="Username des Spielers"
              onKeyDown={e => { if (e.key === 'Enter') onGiveCurrency(); }}
            />
          </div>
          <div style={{ marginBottom: 14 }}>
            <label style={{ fontSize: 12, color: 'var(--text2)', display: 'block', marginBottom: 4 }}>
              Betrag ({event.currency_name})
            </label>
            <input
              type="number"
              value={giveAmount}
              onChange={e => setGiveAmount(e.target.value)}
              placeholder="500"
              min="1"
              onKeyDown={e => { if (e.key === 'Enter') onGiveCurrency(); }}
            />
          </div>
          <button
            className="btn-gold"
            onClick={onGiveCurrency}
            disabled={giving}
            style={{ width: '100%', padding: '10px 0' }}
          >
            {giving ? 'Vergebe...' : 'Vergeben'}
          </button>
          {giveResult && (
            <div style={{
              marginTop: 10, fontSize: 12, padding: '8px 12px', borderRadius: 8,
              color: giveResult.startsWith('✓') ? '#7ac040' : 'var(--red)',
              background: giveResult.startsWith('✓') ? '#1a2a0a' : '#2a0a0a',
            }}>
              {giveResult}
            </div>
          )}
        </div>

        {/* Event details */}
        <div className="card">
          <div style={{ fontWeight: 'bold', color: 'var(--gold)', marginBottom: 14 }}>Event-Infos</div>
          <InfoRow label="ID" value={event.id} mono />
          {event.description && <InfoRow label="Beschreibung" value={event.description} />}
          <InfoRow label="Start" value={fmtDate(event.starts_at)} />
          <InfoRow label="Ende" value={fmtDate(event.ends_at)} />
          <InfoRow label="Währung" value={event.currency_name} />
          <InfoRow label="Banner-Farbe" value={
            <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ width: 14, height: 14, borderRadius: 3, background: event.banner_color, display: 'inline-block' }} />
              {event.banner_color}
            </span>
          } />
          <InfoRow label="Währung verteilt" value={Number(event.total_currency_distributed).toLocaleString('de-DE')} />
        </div>

      </div>
    </>
  );
}

function InfoRow({ label, value, mono }: { label: string; value: React.ReactNode; mono?: boolean }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 0', borderBottom: '1px solid var(--border2)', fontSize: 13 }}>
      <span style={{ color: 'var(--text2)' }}>{label}</span>
      <span style={mono ? { fontFamily: 'monospace', fontSize: 11, color: 'var(--text3)' } : {}}>{value}</span>
    </div>
  );
}
