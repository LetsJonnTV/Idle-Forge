import { Component } from '@angular/core';

interface Feature {
  emoji: string;
  text: string;
}

@Component({
  selector: 'app-landing',
  templateUrl: './landing.component.html',
  styleUrls: ['./landing.component.scss']
})
export class LandingComponent {
  readonly features: Feature[] = [
    { emoji: '⚔️',  text: 'Idle-Kampf mit Auto-Angriffen & Skills' },
    { emoji: '🔨',  text: 'Schmiede-System — Waffen, Rüstungen & mehr' },
    { emoji: '🏰',  text: 'Dungeon-System mit Bossen & Legendary-Rewards' },
    { emoji: '🔮',  text: 'Enchantment-System — Runen-Upgrades für Items' },
    { emoji: '📜',  text: 'Crafting-Rezepte — gezieltes Herstellen' },
    { emoji: '🌳',  text: 'Ascension-Baum — permanenter Skill-Tree' },
    { emoji: '🐾',  text: 'Pet/Companion mit passiven Boni' },
    { emoji: '🎽',  text: 'Set-Boni für komplette Item-Sets' },
    { emoji: '🧭',  text: 'Expeditionen — Timer-Missionen für seltene Items' },
    { emoji: '🗓️', text: 'Tägliche Login-Belohnung mit Streak-System' },
    { emoji: '🏆',  text: 'Achievements & Quests' },
    { emoji: '🌍',  text: 'Deutsch & Englisch' }
  ];
}
