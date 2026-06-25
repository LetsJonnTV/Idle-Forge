import { Component, OnInit, OnDestroy } from '@angular/core';
import { Router, NavigationEnd } from '@angular/router';
import { Subscription, filter } from 'rxjs';
import { AuthService } from '../../core/auth.service';
import { ModalService } from '../../core/modal.service';

@Component({
  selector: 'app-header',
  templateUrl: './header.component.html',
  styleUrls: ['./header.component.scss']
})
export class HeaderComponent implements OnInit, OnDestroy {
  isLoggedIn = false;
  username = '';
  isAdmin = false;
  menuOpen = false;

  private routerSub!: Subscription;

  constructor(
    private auth: AuthService,
    private modal: ModalService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.syncState();
    this.routerSub = this.router.events
      .pipe(filter(e => e instanceof NavigationEnd))
      .subscribe(() => {
        this.syncState();
        this.menuOpen = false;
      });
  }

  ngOnDestroy(): void {
    this.routerSub?.unsubscribe();
  }

  private syncState(): void {
    this.isLoggedIn = this.auth.isLoggedIn();
    const user = this.auth.getUser();
    this.username = user?.username ?? '';
    this.isAdmin  = this.auth.isAdmin();
  }

  openLogin(): void    { this.modal.open('login');    }
  openRegister(): void { this.modal.open('register'); }

  toggleMenu(): void { this.menuOpen = !this.menuOpen; }
  closeMenu(): void  { this.menuOpen = false; }

  logout(): void {
    this.auth.logout();
    this.syncState();
    this.router.navigate(['/']);
  }
}
