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

export interface ItemBlueprint {
  id: string;
  slot: string;
  name: string;
  base_power: number;
  icon_path: string | null;
  is_active: boolean;
  created_at: string;
}

export interface AdminItemsResponse {
  items: ItemBlueprint[];
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

  getItems(search?: string, slot?: string): Observable<AdminItemsResponse> {
    const params = new URLSearchParams();
    if (search) params.set('q', search);
    if (slot) params.set('slot', slot);
    const query = params.toString() ? `?${params}` : '';
    return this.api.get<AdminItemsResponse>(`/api/admin/items${query}`);
  }

  createItem(item: { id: string; slot: string; name: string; base_power: number; icon_path?: string }): Observable<{ item: ItemBlueprint }> {
    return this.api.post<{ item: ItemBlueprint }>('/api/admin/items', item);
  }

  updateItem(id: string, updates: Partial<ItemBlueprint>): Observable<{ item: ItemBlueprint }> {
    return this.api.patch<{ item: ItemBlueprint }>(`/api/admin/items/${id}`, updates);
  }

  deactivateItem(id: string): Observable<{ success: boolean }> {
    return this.api.delete<{ success: boolean }>(`/api/admin/items/${id}`);
  }
}
