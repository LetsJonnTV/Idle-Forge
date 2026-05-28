import { Component, OnInit, OnDestroy, HostListener } from '@angular/core';
import { Router } from '@angular/router';
import { Subscription } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { ModalService, ModalTab } from '../../core/modal.service';

@Component({
  selector: 'app-auth-modal',
  templateUrl: './auth-modal.component.html',
  styleUrls: ['./auth-modal.component.scss']
})
export class AuthModalComponent implements OnInit, OnDestroy {
  isVisible = false;
  activeTab: ModalTab = null;

  /* ── Login form state ─────────────────────────────── */
  loginUsername = '';
  loginPassword = '';
  loginError    = '';
  loginLoading  = false;

  /* ── Register form state ──────────────────────────── */
  regUsername = '';
  regPassword = '';
  regConfirm  = '';
  regError    = '';
  regLoading  = false;

  private sub!: Subscription;

  constructor(
    private auth:   AuthService,
    private modal:  ModalService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.sub = this.modal.modal$.subscribe(tab => {
      this.activeTab = tab;
      this.isVisible = tab !== null;
      if (!this.isVisible) this.resetForms();
    });
  }

  ngOnDestroy(): void {
    this.sub?.unsubscribe();
  }

  /* Close on Escape key */
  @HostListener('document:keydown.escape')
  onEscape(): void {
    if (this.isVisible) this.close();
  }

  switchTab(tab: 'login' | 'register'): void {
    this.activeTab = tab;
  }

  close(): void {
    this.modal.close();
  }

  onBackdropClick(event: MouseEvent): void {
    if ((event.target as HTMLElement).classList.contains('modal-backdrop')) {
      this.close();
    }
  }

  /* ── Login ────────────────────────────────────────── */
  onLogin(): void {
    this.loginError = '';
    if (!this.loginUsername.trim() || !this.loginPassword) {
      this.loginError = 'Bitte alle Felder ausfüllen.';
      return;
    }
    this.loginLoading = true;
    this.auth.login(this.loginUsername.trim(), this.loginPassword).subscribe({
      next: () => {
        this.loginLoading = false;
        this.close();
        this.router.navigate(['/dashboard']);
      },
      error: err => {
        this.loginLoading = false;
        this.loginError =
          err?.error?.message ??
          err?.error?.error  ??
          'Login fehlgeschlagen. Benutzername oder Passwort falsch.';
      }
    });
  }

  /* ── Register ─────────────────────────────────────── */
  onRegister(): void {
    this.regError = '';
    if (!this.regUsername.trim() || !this.regPassword || !this.regConfirm) {
      this.regError = 'Bitte alle Felder ausfüllen.';
      return;
    }
    if (this.regPassword.length < 6) {
      this.regError = 'Passwort muss mindestens 6 Zeichen lang sein.';
      return;
    }
    if (this.regPassword !== this.regConfirm) {
      this.regError = 'Die Passwörter stimmen nicht überein.';
      return;
    }
    this.regLoading = true;
    this.auth.register(this.regUsername.trim(), this.regPassword).subscribe({
      next: () => {
        this.regLoading = false;
        this.close();
        this.router.navigate(['/dashboard']);
      },
      error: err => {
        this.regLoading = false;
        this.regError =
          err?.error?.message ??
          err?.error?.error  ??
          'Registrierung fehlgeschlagen. Bitte versuche es erneut.';
      }
    });
  }

  private resetForms(): void {
    this.loginUsername = '';
    this.loginPassword = '';
    this.loginError    = '';
    this.loginLoading  = false;
    this.regUsername   = '';
    this.regPassword   = '';
    this.regConfirm    = '';
    this.regError      = '';
    this.regLoading    = false;
  }
}
