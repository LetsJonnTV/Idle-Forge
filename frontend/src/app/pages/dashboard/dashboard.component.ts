import { Component, OnInit } from '@angular/core';
import {
  FormBuilder,
  FormGroup,
  Validators,
  AbstractControl,
  ValidationErrors
} from '@angular/forms';
import { ApiService } from '../../core/api.service';
import { AuthService } from '../../core/auth.service';

/* ── Interfaces ───────────────────────────────────────── */
export interface PlayerData {
  id: string;
  username: string;
  clan_id:         string | null;
  clan_name:       string | null;
  total_strength:  number;
  prestige_level:  number;
  chapter:         number;
}

export interface FriendUser {
  id:             string;
  username:       string;
  total_strength: number;
  prestige_level: number;
}

export interface FriendEntry {
  id:        string;
  status:    'pending' | 'accepted' | 'blocked';
  requester: FriendUser;
  addressee: FriendUser;
}

/* ── Validator ────────────────────────────────────────── */
function passwordsMatchValidator(group: AbstractControl): ValidationErrors | null {
  const np = group.get('newPassword')?.value as string;
  const cp = group.get('confirmPassword')?.value as string;
  return np && cp && np !== cp ? { mismatch: true } : null;
}

/* ── Component ────────────────────────────────────────── */
@Component({
  selector: 'app-dashboard',
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.scss']
})
export class DashboardComponent implements OnInit {
  activeTab = 'profile';

  /* Profile */
  player: PlayerData | null = null;
  playerLoading = false;
  playerError   = '';

  /* Cloud Save */
  saveData:       unknown  = null;
  saveSyncDate    = '';
  pendingRewards: unknown[] = [];
  saveLoading = false;
  saveError   = '';

  /* Friends */
  friends:        FriendEntry[] = [];
  friendsLoading  = false;
  friendsError    = '';
  friendUsername  = '';
  friendAddMsg    = '';
  friendAddError  = '';

  /* Password */
  passwordForm!:   FormGroup;
  passwordLoading  = false;
  passwordSuccess  = '';
  passwordError    = '';

  private currentUserId = '';

  constructor(
    private api:  ApiService,
    private auth: AuthService,
    private fb:   FormBuilder
  ) {}

  ngOnInit(): void {
    this.currentUserId = this.auth.getUser()?.playerId ?? '';

    this.passwordForm = this.fb.group(
      {
        currentPassword:  ['', Validators.required],
        newPassword:      ['', [Validators.required, Validators.minLength(6)]],
        confirmPassword:  ['', Validators.required]
      },
      { validators: passwordsMatchValidator }
    );

    this.loadProfile();
  }

  /* ── Tabs ──────────────────────────────────────────── */
  setTab(tab: string): void {
    this.activeTab = tab;
    if (tab === 'save'    && !this.saveData && !this.saveLoading)   this.loadSave();
    if (tab === 'friends' && !this.friends.length && !this.friendsLoading) this.loadFriends();
  }

  /* ── Profile ───────────────────────────────────────── */
  loadProfile(): void {
    this.playerLoading = true;
    this.playerError   = '';
    this.api.get<{ player: PlayerData }>('/api/players/me').subscribe({
      next:  res => { this.player = res.player; this.playerLoading = false; },
      error: err => {
        this.playerError   = err?.error?.message ?? 'Fehler beim Laden des Profils.';
        this.playerLoading = false;
      }
    });
  }

  /* ── Cloud Save ────────────────────────────────────── */
  loadSave(): void {
    this.saveLoading = true;
    this.saveError   = '';
    this.api
      .get<{ save: unknown; updatedAt: string; pendingRewards: unknown[] }>('/api/saves')
      .subscribe({
        next: res => {
          this.saveData       = res.save;
          this.saveSyncDate   = res.updatedAt;
          this.pendingRewards = res.pendingRewards ?? [];
          this.saveLoading    = false;
        },
        error: err => {
          this.saveError   = err?.error?.message ?? 'Fehler beim Laden des Speicherstands.';
          this.saveLoading = false;
        }
      });
  }

  getSaveSize(): string {
    if (!this.saveData) return '0 KB';
    const bytes = JSON.stringify(this.saveData).length;
    return (bytes / 1024).toFixed(2) + ' KB';
  }

  getRewardLabel(reward: unknown): string {
    const r = reward as Record<string, unknown>;
    if (r['description']) return String(r['description']);
    if (r['type'] === 'gold')  return `${r['amount']} Gold von Admin`;
    if (r['type'] === 'item')  return `Item: ${r['itemId'] ?? 'Unbekannt'}`;
    return JSON.stringify(r);
  }

  /* ── Friends ───────────────────────────────────────── */
  loadFriends(): void {
    this.friendsLoading = true;
    this.friendsError   = '';
    this.api.get<{ friends: FriendEntry[] }>('/api/friends').subscribe({
      next:  res => { this.friends = res.friends ?? []; this.friendsLoading = false; },
      error: err => {
        this.friendsError   = err?.error?.message ?? 'Fehler beim Laden der Freunde.';
        this.friendsLoading = false;
      }
    });
  }

  get acceptedFriends(): FriendEntry[] {
    return this.friends.filter(f => f.status === 'accepted');
  }

  get pendingReceived(): FriendEntry[] {
    return this.friends.filter(
      f => f.status === 'pending' && f.addressee?.id === this.currentUserId
    );
  }

  get pendingSent(): FriendEntry[] {
    return this.friends.filter(
      f => f.status === 'pending' && f.requester?.id === this.currentUserId
    );
  }

  /** Returns the "other person" in a friendship entry */
  getFriendOf(entry: FriendEntry): FriendUser {
    return entry.requester?.id === this.currentUserId ? entry.addressee : entry.requester;
  }

  addFriend(): void {
    this.friendAddMsg   = '';
    this.friendAddError = '';
    const target = this.friendUsername.trim();
    if (!target) return;

    this.api.post('/api/friends', { targetUsername: target }).subscribe({
      next: () => {
        this.friendAddMsg      = '✓ Freundschaftsanfrage gesendet!';
        this.friendUsername    = '';
        this.loadFriends();
      },
      error: err => {
        this.friendAddError = err?.error?.message ?? 'Fehler beim Senden der Anfrage.';
      }
    });
  }

  respondToFriend(id: string, status: 'accepted' | 'blocked'): void {
    this.api.patch(`/api/friends/${id}`, { status }).subscribe({
      next:  () => this.loadFriends(),
      error: () => {}
    });
  }

  removeFriend(id: string): void {
    this.api.delete(`/api/friends/${id}`).subscribe({
      next:  () => this.loadFriends(),
      error: () => {}
    });
  }

  /* ── Password ──────────────────────────────────────── */
  onPasswordSubmit(): void {
    this.passwordSuccess = '';
    this.passwordError   = '';

    if (this.passwordForm.invalid) {
      this.passwordForm.markAllAsTouched();
      if (this.passwordForm.hasError('mismatch')) {
        this.passwordError = 'Die neuen Passwörter stimmen nicht überein.';
      } else {
        this.passwordError = 'Bitte alle Felder korrekt ausfüllen.';
      }
      return;
    }

    const { currentPassword, newPassword } = this.passwordForm.value as {
      currentPassword: string;
      newPassword:     string;
    };

    this.passwordLoading = true;
    this.api.patch('/api/players/me/password', { currentPassword, newPassword }).subscribe({
      next: () => {
        this.passwordSuccess = '✓ Passwort erfolgreich geändert!';
        this.passwordLoading = false;
        this.passwordForm.reset();
      },
      error: err => {
        this.passwordError   = err?.error?.message ?? 'Fehler beim Ändern des Passworts.';
        this.passwordLoading = false;
      }
    });
  }

  /* Convenience getters for template readability */
  get f() { return this.passwordForm.controls; }
}
