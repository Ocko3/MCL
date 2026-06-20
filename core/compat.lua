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

-- * ------------------------------------------------------
-- * core/compat.lua
-- * MoP Classic (5.4.x) API compatibility shims.
-- * Must be the FIRST MCL file loaded after libs (add it
-- * to MCL.toc right after libs\load_libs.xml).
-- * ------------------------------------------------------
local _, MCLcore = ...

-- =========================================================
-- Version detection
-- =========================================================
-- MoP Classic lacks UiMapPoint (BfA+ map system) and has
-- a different C_CurrencyInfo surface. Use both as signals.
MCLcore.IsMoPClassic = (not UiMapPoint) or (not C_CurrencyInfo)

-- =========================================================
-- C_ChatInfo shim
-- BfA (8.0) moved RegisterAddonMessagePrefix and
-- SendAddonMessage into the C_ChatInfo namespace.
-- In MoP they are plain globals.
-- =========================================================
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

-- =========================================================
-- C_Item shim
-- Legion (7.0) added the C_Item namespace.
-- MoP uses plain global functions.
-- =========================================================
if not C_Item then
    C_Item = {
        GetItemInfo     = function(id) return GetItemInfo(id) end,
        GetItemCount    = function(id, includeBank)
                              return GetItemCount(id, includeBank)
                          end,
        GetItemNameByID = function(id) return (GetItemInfo(id)) end,
        -- No equivalent in MoP; items are cached automatically
        -- when GetItemInfo is called. This is a safe no-op.
        RequestLoadItemDataByID = function(id) end,
    }
end

-- =========================================================
-- C_Spell shim
-- C_Spell namespace is Retail only. MoP has global
-- GetSpellLink(spellID).
-- =========================================================
if not C_Spell then
    C_Spell = {
        GetSpellLink = function(id) return GetSpellLink(id) end,
    }
end

-- =========================================================
-- DressUpMount shim
-- Mount dressing room doesn't exist in MoP Classic.
-- Ctrl+Click on a mount will silently do nothing instead
-- of erroring. Replace with summon logic if desired.
-- =========================================================
if not DressUpMount then
    DressUpMount = function(mountID) end  -- no-op
end

-- =========================================================
-- GameTooltip:SetMountBySpellID shim
-- Added in a later Retail patch. In MoP we fall back to
-- SetSpellByID which shows the mount spell tooltip — not
-- as rich, but doesn't error.
-- =========================================================
if GameTooltip and not GameTooltip.SetMountBySpellID then
    GameTooltip.SetMountBySpellID = function(self, spellID)
        if spellID then
            self:SetSpellByID(spellID)
        end
    end
end

-- =========================================================
-- C_MountJournal safety patches
-- Some methods don't exist in MoP 5.4.8.
-- =========================================================
if C_MountJournal then
    -- GetMountFromSpell: added post-MoP
    if not C_MountJournal.GetMountFromSpell then
        C_MountJournal.GetMountFromSpell = function(spellID) return nil end
    end

    -- ClearSearchFilters: added post-MoP
    if not C_MountJournal.ClearSearchFilters then
        C_MountJournal.ClearSearchFilters = function() end
    end
end

-- =========================================================
-- IsMountCollected global
-- In MoP there's no Blizzard global IsMountCollected().
-- MCL defines its own in functions.lua, but compat.lua
-- loads first, so we put a safe stub here that will be
-- overridden once functions.lua loads.
-- =========================================================
if not IsMountCollected then
    IsMountCollected = function(mountID)
        if not mountID or not C_MountJournal then return false end
        local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        return isCollected or false
    end
end