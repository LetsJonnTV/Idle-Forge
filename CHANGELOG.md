# Changelog

All notable changes to Idle Forge are documented here.

## [1.0.1] - 2026-05-26

### Added
- In-app update checker: on every launch the app compares its version against the latest GitHub Release and shows a download prompt if a newer version is available
- Settings panel (gear icon in the top bar) with current app version display
- Bug report button in settings that opens GitHub Issues directly in the browser
- Internet permission for Android

### Changed
- README rewritten with feature overview, download instructions, and build guide
- `android/local.properties` added to `.gitignore` to keep local paths private

### Fixed
- Release APK now verified to preserve save data (SharedPreferences) across updates

## [1.0.0] - 2026-05-01

### Added
- Initial release
- Idle combat with auto-attacks and skills
- Crafting / forge system
- Shop with daily offers and upgrades
- Achievements & quests
- Offline rewards
- German & English language support
