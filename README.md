# ⚒️ Idle Forge

A mobile idle game built with Flutter — forge legendary gear, conquer stages, and grow your hero while you're away.

## 📱 Download

Grab the latest APK from the [Releases page](https://github.com/LetsJonnTV/Idle-Forge/releases/latest).

**Installation (Android):**
1. Download `app-release.apk`
2. Enable "Install from unknown sources" in Android settings
3. Install the APK

> Your save data is preserved when updating to a newer APK version.

## ✨ Features

- ⚔️ Idle combat with auto-attacks and skills
- 🔨 Crafting system — forge weapons, armor, and more
- 🛒 In-game shop with daily offers and upgrades
- 🏆 Achievements & quests
- 💾 Offline rewards — progress even while away
- 🔔 In-app update notifications
- 🌍 German & English language support

## 🛠️ Tech Stack

- [Flutter](https://flutter.dev/) (Dart)
- `shared_preferences` for save data
- `package_info_plus` for version info
- `url_launcher` for external links

## 🚀 Build from Source

**Requirements:** Flutter SDK (stable channel)

```bash
git clone https://github.com/LetsJonnTV/Idle-Forge.git
cd Idle-Forge
flutter pub get
flutter run                        # debug
flutter build apk --release        # release APK
```

## 🐛 Found a Bug?

Please [open an issue](https://github.com/LetsJonnTV/Idle-Forge/issues/new) on GitHub.

## 🌿 Branch Rules

Branch model:
1. `main` only accepts pull requests from `dev`.
2. Direct pushes to `dev` are not allowed.
3. New working branches must follow:
	`task|fix|feat/issue_<number>/<short-description>`

Examples:
1. `feat/issue_128/new-forge-ui`
2. `fix/issue_274/null-check-save`
3. `task/issue_310/update-docs`

Automation in this repository:
1. [`.github/workflows/branch-rules.yml`](.github/workflows/branch-rules.yml) enforces:
	- PRs to `main` must come from `dev`
	- Branch naming format on PR and push

Required GitHub settings (one-time):
1. Branch protection for `main`:
	- Require a pull request before merging
	- Require status checks and select `Branch Rules / Enforce main PR source branch`
2. Branch protection for `dev`:
	- Require a pull request before merging
	- Restrict who can push to matching branches (nobody or only admins/bot)
	- Require status checks and select:
	  - `Branch Rules / Enforce branch naming on PR`
	  - `Branch Rules / Enforce branch naming on push`

## 📄 License

MIT — see [LICENSE](LICENSE)
