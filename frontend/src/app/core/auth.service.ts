import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap } from 'rxjs';
import { environment } from '../../environments/environment';

export interface LoginResponse {
  token: string;
  playerId: string;
  username: string;
  isAdmin: boolean;
}

export interface RegisterResponse {
  token: string;
  playerId: string;
  username: string;
}

export interface UserPayload {
  playerId: string;
  username: string;
  isAdmin: boolean;
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly TOKEN_KEY = 'idle_forge_token';

  constructor(private http: HttpClient) {}

  login(username: string, password: string): Observable<LoginResponse> {
    return this.http
      .post<LoginResponse>(`${environment.apiUrl}/api/auth/login`, { username, password })
      .pipe(tap(res => this.saveToken(res.token)));
  }

  register(username: string, password: string): Observable<RegisterResponse> {
    return this.http
      .post<RegisterResponse>(`${environment.apiUrl}/api/auth/register`, { username, password })
      .pipe(tap(res => this.saveToken(res.token)));
  }

  logout(): void {
    localStorage.removeItem(this.TOKEN_KEY);
  }

  isLoggedIn(): boolean {
    return !!this.getToken();
  }

  getToken(): string | null {
    return localStorage.getItem(this.TOKEN_KEY);
  }

  /**
   * Decodes the JWT payload (middle segment) without any library.
   * Returns null if token is missing or malformed.
   */
  getUser(): UserPayload | null {
    const token = this.getToken();
    if (!token) return null;
    try {
      const parts = token.split('.');
      if (parts.length !== 3) return null;
      // atob may fail on non-ASCII; pad the base64url string first
      const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
      const json = atob(b64);
      const payload = JSON.parse(json);
      return {
        playerId: payload.playerId ?? payload.player_id ?? payload.id ?? payload.sub ?? '',
        username: payload.username ?? '',
        isAdmin: !!(payload.isAdmin ?? payload.is_admin ?? false)
      };
    } catch {
      return null;
    }
  }

  isAdmin(): boolean {
    return this.getUser()?.isAdmin === true;
  }

  private saveToken(token: string): void {
    localStorage.setItem(this.TOKEN_KEY, token);
  }
}
