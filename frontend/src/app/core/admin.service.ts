import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';

export interface AdminPlayer {
  id: string;
  username: string;
  is_admin: boolean;
  is_blocked: boolean;
  total_strength: number;
  prestige_level: number;
  chapter: number;
  created_at: string;
}

export interface AdminPlayersResponse {
  players: AdminPlayer[];
}

@Injectable({ providedIn: 'root' })
export class AdminService {
  constructor(private api: ApiService) {}

  getPlayers(search?: string): Observable<AdminPlayersResponse> {
    const query = search ? `?q=${encodeURIComponent(search)}` : '';
    return this.api.get<AdminPlayersResponse>(`/api/admin/players${query}`);
  }

  resetPassword(id: string, newPassword: string): Observable<{ success: boolean }> {
    return this.api.post<{ success: boolean }>(`/api/admin/players/${id}`, { newPassword });
  }

  setBlocked(id: string, blocked: boolean): Observable<{ success: boolean }> {
    return this.api.patch<{ success: boolean }>(`/api/admin/players/${id}`, { blocked });
  }

  deletePlayer(id: string): Observable<{ success: boolean }> {
    return this.api.delete<{ success: boolean }>(`/api/admin/players/${id}`);
  }

  giveReward(
    id: string,
    type: 'gold' | 'item',
    amount?: number,
    itemId?: string
  ): Observable<{ success: boolean }> {
    const body: Record<string, unknown> = { type };
    if (type === 'gold' && amount !== undefined) body['amount'] = amount;
    if (type === 'item' && itemId)             body['itemId'] = itemId;
    return this.api.put<{ success: boolean }>(`/api/admin/players/${id}`, body);
  }
}
