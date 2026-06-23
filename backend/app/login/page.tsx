'use client';
import { useState, useEffect, FormEvent } from 'react';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (localStorage.getItem('idle_forge_jwt')) router.replace('/inventory');
  }, [router]);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      });
      const data = await res.json();
      if (!res.ok) { setError(data.error ?? 'Anmeldung fehlgeschlagen'); return; }
      localStorage.setItem('idle_forge_jwt', data.token);
      localStorage.setItem('idle_forge_username', data.username);
      router.replace('/inventory');
    } catch {
      setError('Netzwerkfehler');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <div className="card" style={{ width: '100%', maxWidth: 380 }}>
        {/* Logo */}
        <div style={{ textAlign: 'center', marginBottom: 28 }}>
          <div style={{ fontSize: 40, marginBottom: 8 }}>⚒️</div>
          <div style={{ fontSize: 22, fontWeight: 'bold', letterSpacing: 4, color: 'var(--gold)' }}>IDLE FORGE</div>
          <div style={{ fontSize: 12, color: 'var(--text2)', marginTop: 4 }}>Inventar-Manager</div>
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <input
            type="text"
            placeholder="Benutzername"
            autoComplete="username"
            value={username}
            onChange={e => setUsername(e.target.value)}
            required
            minLength={3}
          />
          <input
            type="password"
            placeholder="Passwort"
            autoComplete="current-password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            required
            minLength={6}
          />

          {error && (
            <div style={{ color: 'var(--red)', fontSize: 13 }}>{error}</div>
          )}

          <button type="submit" className="btn-gold" disabled={loading} style={{ marginTop: 4, padding: '12px 0' }}>
            {loading ? 'Anmelden...' : 'Anmelden'}
          </button>
        </form>
      </div>
    </div>
  );
}
