import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';

export type ModalTab = 'login' | 'register' | null;

@Injectable({ providedIn: 'root' })
export class ModalService {
  private readonly _state$ = new BehaviorSubject<ModalTab>(null);
  readonly modal$ = this._state$.asObservable();

  open(tab: 'login' | 'register' = 'login'): void {
    this._state$.next(tab);
  }

  close(): void {
    this._state$.next(null);
  }

  get currentTab(): ModalTab {
    return this._state$.getValue();
  }
}
