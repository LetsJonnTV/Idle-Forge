import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';

import { AuthService } from '../../core/auth.service';

@Component({
  selector: 'app-login-page',
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.scss']
})
export class LoginComponent implements OnInit {
  username = '';
  password = '';
  loading = false;
  error = '';

  constructor(
    private readonly auth: AuthService,
    private readonly router: Router
  ) {}

  ngOnInit(): void {
    if (this.auth.isLoggedIn()) {
      this.router.navigate(['/inventory']);
    }
  }

  submit(): void {
    this.error = '';
    if (!this.username.trim() || !this.password) {
      this.error = 'Bitte Benutzername und Passwort eingeben.';
      return;
    }

    this.loading = true;

    this.auth.login(this.username.trim(), this.password).subscribe({
      next: res => {
        this.loading = false;
        if (res.isAdmin) {
          this.router.navigate(['/admin']);
          return;
        }
        this.router.navigate(['/inventory']);
      },
      error: err => {
        this.loading = false;
        this.error = err?.error?.error ?? 'Anmeldung fehlgeschlagen.';
      }
    });
  }
}
