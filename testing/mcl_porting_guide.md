# MCL → MoP Classic Porting Guide
> Based on audit of `Ocko3/MCL` — version 3.2.6-MoP

---

## Quick Status

The addon currently has **Interface: 30402** (WotLK Classic). That alone will prevent it loading in MoP. The guide system (Guide/, GuideMapPins, etc.) is already gated behind `MCLcore.GuideSystemAvailable = false` on MoP, so those files load but most of their code won't run — that's fine for now.

The **core functionality** (mount grid, pinning, party/compare chat, search, minimap icon) needs the fixes below to work.

---

## Fix 1: TOC Interface Version

**File:** `MCL.toc`

```
## Interface: 30402     ← WRONG (WotLK Classic)
```

Change to:

```
## Interface: 50400
```

MoP Classic uses **50400** (patch 5.4.0). If you want to be precise about 5.4.8 you can use `50408`, but `50400` is the standard target for MoP Classic addons.

---

## Fix 2: `BackdropTemplate` — 94 uses, every single one will error

**The problem:** `BackdropTemplate` as a frame template was added in **Shadowlands (9.0)**. In MoP (5.4), frames that want backdrops call `frame:SetBackdrop({...})` directly without inheriting a template. The call `CreateFrame("Frame", nil, parent, "BackdropTemplate")` will silently fail or error in MoP because that template doesn't exist.

**The fix:** Replace every `"BackdropTemplate"` with `""` (empty string or just omit the 4th arg), and then call `frame:SetBackdrop({...})` directly — which you're already doing. The `SetBackdrop` method exists natively on all frames in MoP without needing the template.

**Global find & replace:**

```
Find:    "BackdropTemplate"
Replace: nil
```

Or more safely, find every pattern and just remove the template name:

```lua
-- BEFORE (breaks in MoP):
local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
f:SetBackdrop({...})

-- AFTER (works in MoP):
local f = CreateFrame("Frame", nil, parent)
f:SetBackdrop({...})
```

> **Note:** `SetBackdropBorderColor` and `SetBackdropColor` also work natively in MoP without BackdropTemplate.

**Files to touch:** `core/frames.lua`, `core/functions.lua`, `core/Core.lua`, `core/MountCard.lua`, `core/MCLToast.lua`, `core/Widgets.lua`, `guide/GuideMapPanel.lua`, `guide/GuideZonePanel.lua`

---

## Fix 3: `C_ChatInfo` → Global functions

**The problem:** `C_ChatInfo.SendAddonMessage()` and `C_ChatInfo.RegisterAddonMessagePrefix()` are **Battle for Azeroth (8.0)** additions. In MoP these are plain global functions.

**Files:** `core/PartyCheck.lua`, `core/CompareCheck.lua`

**The fix:**

```lua
-- BEFORE:
C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
C_ChatInfo.SendAddonMessage(PREFIX, msg, channel)

-- AFTER (MoP compatible):
RegisterAddonMessagePrefix(PREFIX)
SendAddonMessage(PREFIX, msg, channel)
```

At the top of both files, add a compat shim so you don't have to touch every call site:

```lua
-- MoP compat: C_ChatInfo doesn't exist, these are globals
if not C_ChatInfo then
    C_ChatInfo = {
        RegisterAddonMessagePrefix = function(prefix)
            return RegisterAddonMessagePrefix(prefix)
        end,
        SendAddonMessage = function(prefix, msg, channel, target)
            return SendAddonMessage(prefix, msg, channel, target)
        end,
    }
end
```

Put this shim **before** the first use of `C_ChatInfo` in each file (or in a shared compat file loaded first).

---

## Fix 4: `C_Spell.GetSpellLink` → `GetSpellLink`

**File:** `core/functions.lua:569`

```lua
-- BEFORE:
local spellLink = C_Spell.GetSpellLink(spellID)

-- AFTER:
local spellLink = GetSpellLink(spellID)
```

`C_Spell` namespace doesn't exist in MoP. `GetSpellLink(spellID)` is the global function available since Vanilla.

---

## Fix 5: `C_Item.*` → Global item functions

**The problem:** The `C_Item` namespace is post-Legion. MoP has the old global functions.

**Files:** `core/functions.lua`, `core/main.lua`, `core/MountCard.lua`

**Mapping:**

| Retail (`C_Item.*`) | MoP equivalent |
|---|---|
| `C_Item.GetItemInfo(id)` | `GetItemInfo(id)` |
| `C_Item.GetItemCount(id, includeBank)` | `GetItemCount(id, includeBank)` |
| `C_Item.GetItemNameByID(id)` | `GetItemInfo(id)` (first return) |
| `C_Item.RequestLoadItemDataByID(id)` | **No equivalent** — just omit (see below) |

**Add this compat shim** in a file that loads early (e.g., at the top of `core/Constants.lua` or a new `core/compat.lua`):

```lua
-- MoP compat: C_Item namespace shim
if not C_Item then
    C_Item = {
        GetItemInfo = function(id) return GetItemInfo(id) end,
        GetItemCount = function(id, bank) return GetItemCount(id, bank) end,
        GetItemNameByID = function(id) return (GetItemInfo(id)) end,
        -- RequestLoadItemDataByID doesn't exist in MoP; items load automatically
        RequestLoadItemDataByID = function(id) end,  -- no-op
    }
end
```

For `core/frames.lua:2217` and `2353` the code already has fallback guards like `C_Item and C_Item.GetItemCount and ... or GetItemCount(...)` — those will work once `C_Item` is shimmed.

---

## Fix 6: `C_MountJournal.GetMountFromSpell` — doesn't exist in MoP

**Files:** `core/functions.lua`, `core/MountCache.lua`, `guide/GuideMapPins.lua`, `guide/MCL_Guide.lua`

`C_MountJournal.GetMountFromSpell` was added in a **post-MoP patch** (exact version unclear, but it's not in 5.4.8).

The code already has guards in most places:
```lua
if (not mount_Id or mount_Id == 0) and C_MountJournal.GetMountFromSpell then
    mount_Id = C_MountJournal.GetMountFromSpell(id)
end
```
That guard will safely no-op in MoP. **Double check** `core/frames.lua:2228` — that one calls it without a guard:

```lua
-- core/frames.lua ~2228 — NEEDS a guard:
local mountID = C_MountJournal.GetMountFromSpell(spellId)
```

Fix:
```lua
local mountID = C_MountJournal.GetMountFromSpell and C_MountJournal.GetMountFromSpell(spellId)
```

---

## Fix 7: `C_MountJournal.ClearSearchFilters` — doesn't exist in MoP

**File:** `core/functions.lua:1526`

```lua
-- BEFORE:
C_MountJournal.ClearSearchFilters()

-- AFTER:
if C_MountJournal.ClearSearchFilters then
    C_MountJournal.ClearSearchFilters()
end
```

---

## Fix 8: `isSteadyFlight` — 13th return value doesn't exist in MoP

**File:** `core/functions.lua` (multiple lines)

`C_MountJournal.GetMountInfoByID` in MoP returns **12 values**, not 13. The 13th return (`isSteadyFlight` / dragonriding) was added in Dragonflight. In MoP it will just be `nil`.

The variable is used to conditionally show a "dragonriding" popup on single-click. In MoP this is always `nil` so the popup code path is simply dead — no crash, but the variable assignment is harmless. You can leave the 13-value destructuring as-is since Lua silently ignores extra assignments.

The one thing to audit: anywhere `isSteadyFlight` is truthy and controls UI flow — it'll always be `nil` in MoP, so those branches are just dead code. That's fine.

---

## Fix 9: `DressUpMount` — doesn't exist in MoP

**Files:** `core/functions.lua:408`, `guide/GuideZonePanel.lua:102`, `guide/GuideMapPanel.lua:490, 905`

`DressUpMount(mountID)` was added in later Retail. MoP doesn't have a mount dressing room.

**Fix:** Guard or stub it:

```lua
-- BEFORE:
DressUpMount(mountID)

-- AFTER:
if DressUpMount then
    DressUpMount(mountID)
-- else: silently skip, mount dressing room not available in MoP
end
```

Or you can replace the Ctrl+Left-Click functionality with something useful in MoP (e.g., summoning the mount, or do nothing).

---

## Fix 10: `GameTooltip:SetMountBySpellID` — doesn't exist in MoP

**Files:** `core/Core.lua:295` (search dropdown hover), `guide/GuideZonePanel.lua:447`

```lua
-- BEFORE:
GameTooltip:SetMountBySpellID(result.spellID)

-- AFTER (MoP):
if result.spellID then
    GameTooltip:SetSpellByID(result.spellID)
end
```

`SetSpellByID` exists in MoP and will show the mount spell tooltip. It's not as pretty as the dedicated mount tooltip but it works.

---

## Fix 11: `IsMountCollected` — global function doesn't exist in MoP

This is a **critical one**. The code defines its own global `IsMountCollected()` wrapper in `core/functions.lua` (line ~1700), but several places also assume there's a **Blizzard global** `IsMountCollected()`. In MoP this global **does not exist** — the concept of "is mount collected" must be derived from `C_MountJournal.GetMountInfoByID(id)` return value 11 (`isCollected`).

Good news: the addon already wraps this:
```lua
function IsMountCollected(id)
    return MCLcore.Function:IsMountCollected(id)
end
```

This global alias is defined in `core/functions.lua` and should be available everywhere. Just make sure `core/functions.lua` loads **before** any file that calls `IsMountCollected()` — check the load order in `MCL.toc`. Currently it does load before `core/frames.lua` and `core/main.lua`, so this should be fine.

**However**, in `core/Core.lua` the search system calls `IsMountCollected(mount_Id)` directly. Since `Core.lua` loads **after** `functions.lua` in the TOC, this is fine. Just verify no file calls `IsMountCollected` before functions.lua is loaded.

---

## Fix 12: `GetCVar("portal")` — works in MoP, but value differs

`core/functions.lua` uses `GetCVar('portal')` to build SimpleArmory/DataForAzeroth links. In MoP Classic this returns something like `"wow_classic"` or a region code, not the retail region string. The links to those sites won't work for MoP characters anyway, but it won't crash — just be aware the links will be wrong.

---

## Fix 13: Map/Waypoint System (Guide subsystem — already gated)

The entire `guide/GuideMapPins.lua` uses:
- `C_Map.SetUserWaypoint` / `C_Map.ClearUserWaypoint` / `C_Map.GetMapInfo` / `C_Map.GetWorldPosFromMapPos`
- `UiMapPoint.CreateFromCoordinates`
- `C_CurrencyInfo.GetCurrencyInfo`

**None of these exist in MoP.** The `C_Map` system replaced the old `GetCurrentMapAreaID` / `SetMapToCurrentZone` API in Battle for Azeroth.

Since the guide system is already gated (`MCLcore.GuideSystemAvailable = false`), the map pins code won't be called. But the files still **load** and their module-level code runs. The critical risk is any top-level code outside of functions. Check:

```lua
-- guide/GuideMapPins.lua line 4-ish (module-level):
-- Uses HereBeDragons-Pins or the native C_Map.SetUserWaypoint
```

Comments are fine. But if any `C_Map.*` call is made at module scope (outside a function), it will error. A quick audit of `guide/MCL_Guide.lua` shows `C_Map.GetMapChildrenInfo` and `C_Map.GetBestMapForUnit` are inside functions, so they're safe as long as those functions aren't called.

**Action:** Verify no `C_Map.*` calls exist at module/file scope (outside functions) in any guide file.

---

## Summary Checklist

| # | Issue | Severity | Files |
|---|---|---|---|
| 1 | TOC Interface: 30402 → 50400 | 🔴 Critical | `MCL.toc` |
| 2 | `BackdropTemplate` — 94 uses | 🔴 Critical | all `core/`, some `guide/` |
| 3 | `C_ChatInfo.*` → globals | 🔴 Critical | `PartyCheck.lua`, `CompareCheck.lua` |
| 4 | `C_Spell.GetSpellLink` → `GetSpellLink` | 🟠 High | `functions.lua:569` |
| 5 | `C_Item.*` namespace | 🟠 High | `functions.lua`, `main.lua`, `MountCard.lua` |
| 6 | `GetMountFromSpell` unguarded call | 🟠 High | `frames.lua:2228` |
| 7 | `ClearSearchFilters` unguarded | 🟡 Medium | `functions.lua:1526` |
| 8 | `isSteadyFlight` (13th return) | 🟢 Low | `functions.lua` (just nil) |
| 9 | `DressUpMount` doesn't exist | 🟡 Medium | `functions.lua`, guide files |
| 10 | `SetMountBySpellID` doesn't exist | 🟡 Medium | `Core.lua`, `GuideZonePanel.lua` |
| 11 | `IsMountCollected` global timing | 🟢 Low | load order already correct |
| 12 | `GetCVar("portal")` value | 🟢 Info | `functions.lua` |
| 13 | Guide/Map system (already gated) | 🟢 Low | `guide/` folder |

---

## Recommended Fix Order

1. **TOC** (fix 1) — addon won't even load otherwise
2. **BackdropTemplate** (fix 2) — mass find & replace, highest blast radius
3. **C_ChatInfo shim** (fix 3) — party/compare features need this
4. **C_Item shim** (fix 5) — put in a new `core/compat.lua` loaded first
5. **C_Spell.GetSpellLink** (fix 4) — one line
6. **GetMountFromSpell guard** (fix 6) — one line
7. **ClearSearchFilters guard** (fix 7) — one line
8. **DressUpMount guards** (fix 9) — a few lines
9. **SetMountBySpellID** (fix 10) — two call sites

---

## Suggested `core/compat.lua` (new file)

Create this and add it as the **first non-lib entry** in `MCL.toc`:

```lua
-- core/compat.lua
-- MoP Classic (5.4.x) API compatibility shims
-- Load this before all other MCL files.

local _, MCLcore = ...

-- Detect MoP Classic by absence of modern APIs
MCLcore.IsMoPClassic = not C_CurrencyInfo or not UiMapPoint

-- C_ChatInfo shim (BfA+ only; MoP uses globals)
if not C_ChatInfo then
    C_ChatInfo = {
        RegisterAddonMessagePrefix = RegisterAddonMessagePrefix,
        SendAddonMessage = SendAddonMessage,
    }
end

-- C_Item shim (Legion+ only; MoP uses globals)
if not C_Item then
    C_Item = {
        GetItemInfo        = function(id) return GetItemInfo(id) end,
        GetItemCount       = function(id, b) return GetItemCount(id, b) end,
        GetItemNameByID    = function(id) return (GetItemInfo(id)) end,
        RequestLoadItemDataByID = function() end,  -- no-op in MoP
    }
end

-- C_Spell shim (Retail; MoP uses globals)
if not C_Spell then
    C_Spell = {
        GetSpellLink = function(id) return GetSpellLink(id) end,
    }
end

-- DressUpMount shim (not available in MoP)
if not DressUpMount then
    DressUpMount = function() end  -- no-op
end

-- GameTooltip:SetMountBySpellID shim
-- In MoP, fall back to SetSpellByID which shows the mount spell tooltip
if GameTooltip and not GameTooltip.SetMountBySpellID then
    GameTooltip.SetMountBySpellID = function(self, spellID)
        if spellID then
            self:SetSpellByID(spellID)
        end
    end
end
```

Then in `MCL.toc`, add `core\compat.lua` right after `libs\load_libs.xml`:

```
libs\load_libs.xml
core\compat.lua          ← ADD THIS
locales\Locales.xml
...
```

This approach means you fix everything in one place and the rest of the code stays clean.

---

## What's Already Working in MoP

- `C_MountJournal.GetMountInfoByID` ✅ (exists since MoP 5.0)
- `C_MountJournal.GetMountIDs` ✅
- `C_MountJournal.GetMountFromItem` ✅
- `C_MountJournal.GetMountInfoExtraByID` ✅
- `C_MountJournal.SummonByID` ✅
- `C_Timer.After` / `C_Timer.NewTicker` ✅ (added in 5.4)
- `LibStub`, `AceAddon`, `AceDB`, all bundled libs ✅
- `LibDataBroker` / `LibDBIcon` ✅
- `GetItemInfo`, `GetItemCount`, `GetRealmName`, `UnitName` ✅
- `RegisterAddonMessagePrefix` / `SendAddonMessage` ✅ (as globals)
- `SetBackdrop` / `SetBackdropColor` / `SetBackdropBorderColor` ✅ (native in MoP, no template needed)
- `GameTooltip:SetSpellByID` ✅
- `GameTooltip:SetItemByID` ✅

---

## After These Fixes

The core mount grid, collection tracking, pinning, minimap icon, party check, and compare features should all function. The Guide/Map system (waypoints, zone panel, map pins) will remain disabled since MoP doesn't have the C_Map API — that's a much larger project and would require a complete rewrite using MoP's older `GetCurrentMapAreaID` / `SetMapToCurrentZone` world map API.