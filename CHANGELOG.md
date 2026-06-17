# Changelog

## [3.2.6-MoP] - 2026-06-17

### Added
- **MoP Classic Support**: Full adaptation for WoW Mists of Pandaria Classic (5.4.8)
- **API Compatibility**: Fallback support for older WoW API calls
  - `C_Item.RequestLoadItemDataByID()` falls back to `GetItemInfo()`
  - `C_AddOns` falls back to `LoadAddOn()`
  - Safe pcall wrapping for all potentially missing APIs
- **MoP Mount Database**: Complete Pandaria-era mount list including:
  - Order of the Cloud Serpent reputation mounts
  - Golden Lotus reputation mounts
  - Shado-Pan reputation mounts
  - The Tillers reputation mounts
  - Timeless Isle mounts
  - Primal egg mounts
  - World boss drops
  - Quest rewards
  - Raid drops
  - And more!

### Changed
- **Interface Version**: Updated from Retail (11.0+, 12.0+) to MoP Classic (30402)
- **Data File**: Completely replaced mount database with MoP-era content only
- **Version Number**: Changed to 3.2.6-MoP to indicate MoP Classic adaptation
- **Addon Compatibility**: Removed all Retail-only features and mount content

### Removed
- Shadowlands mounts
- Battle for Azeroth mounts
- Legion mounts
- Warlords of Draenor post-5.0 exclusive mounts
- Any Retail-specific UI elements or features

### Technical
- Added graceful API fallbacks for MoP Classic compatibility
- Ensured all C_* API calls have GetItemInfo/LoadAddOn fallbacks
- Wrapped filter functions in pcall for safety
- Maintained original code structure for stability

## [3.2.6] - Original (Retail)

See original repository for Retail changelog: https://github.com/Camyana/MCL

---

## How to Contribute

Found a missing mount or need to add more data? You can:
1. Check `core/data.lua` for the mount database structure
2. Cross-reference with Wowhead's MoP database
3. Add missing mounts to the appropriate category
4. Test in-game to verify correct IDs

## Known Issues

- None currently reported for MoP Classic

## Future Improvements

- Additional mount IDs as they're discovered
- Enhanced UI scaling for different resolutions
- Performance optimizations for large mount lists
