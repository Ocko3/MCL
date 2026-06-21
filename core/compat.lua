-- * ------------------------------------------------------
-- * core/compat.lua
-- * MoP Classic (5.4.x) API compatibility shims.
-- * Loaded FIRST after libs (see MCL.toc).
-- * ------------------------------------------------------
local _, MCLcore = ...

-- =========================================================
-- Version detection
-- MoP Classic runs on the modern WoW client engine, so we
-- detect by the absence of the BfA+ map API (UiMapPoint).
-- =========================================================
MCLcore.IsMoPClassic = (not UiMapPoint)

-- =========================================================
-- SetBackdrop / BackdropTemplate shim
--
-- MoP Classic uses the modern WoW client engine (post-9.0).
-- On this engine, Frame objects do NOT have SetBackdrop,
-- SetBackdropColor, or SetBackdropBorderColor unless they
-- inherit "BackdropTemplate" in XML or Lua.
--
-- Rather than adding BackdropTemplate to every CreateFrame
-- call, we inject the mixin onto the Frame metatable so
-- ALL frames get these methods automatically.
-- =========================================================
if BackdropTemplateMixin then
    -- Modern engine approach: mixin exists, apply to Frame metatable
    local frameMeta = getmetatable(CreateFrame("Frame")).__index
    if frameMeta and not frameMeta.SetBackdrop then
        for k, v in pairs(BackdropTemplateMixin) do
            frameMeta[k] = v
        end
    end
else
    -- Fallback: implement minimal SetBackdrop ourselves
    -- (shouldn't be needed on MoP Classic modern engine, but just in case)
    local frameMeta = getmetatable(CreateFrame("Frame"))
    if frameMeta then
        local index = frameMeta.__index
        if type(index) == "table" and not index.SetBackdrop then
            index.SetBackdrop = function(self, backdropInfo)
                -- No-op fallback — backdrop not supported
            end
            index.SetBackdropColor = function(self, r, g, b, a) end
            index.SetBackdropBorderColor = function(self, r, g, b, a) end
            index.GetBackdrop = function(self) return nil end
        end
    end
end

-- =========================================================
-- C_ChatInfo shim
-- BfA (8.0) moved RegisterAddonMessagePrefix and
-- SendAddonMessage into C_ChatInfo. MoP has globals.
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
        -- No equivalent in MoP; items are cached automatically.
        RequestLoadItemDataByID = function(id) end,
    }
end

-- =========================================================
-- C_Spell shim
-- C_Spell namespace is Retail/modern only.
-- MoP has global GetSpellLink(spellID).
-- =========================================================
if not C_Spell then
    C_Spell = {
        GetSpellLink = function(id) return GetSpellLink(id) end,
    }
end

-- =========================================================
-- DressUpMount shim
-- Mount dressing room doesn't exist in MoP Classic.
-- =========================================================
if not DressUpMount then
    DressUpMount = function(mountID) end  -- no-op
end

-- =========================================================
-- GameTooltip:SetMountBySpellID shim
-- Fall back to SetSpellByID which shows the mount spell
-- tooltip in MoP — not as rich, but works without errors.
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
-- Some methods were added post-MoP.
-- =========================================================
if C_MountJournal then
    if not C_MountJournal.GetMountFromSpell then
        C_MountJournal.GetMountFromSpell = function(spellID) return nil end
    end
    if not C_MountJournal.ClearSearchFilters then
        C_MountJournal.ClearSearchFilters = function() end
    end
end

-- =========================================================
-- IsMountCollected stub
-- Overridden by functions.lua once it loads. This stub
-- exists so any code that somehow runs before functions.lua
-- doesn't error.
-- =========================================================
if not IsMountCollected then
    IsMountCollected = function(mountID)
        if not mountID or not C_MountJournal then return false end
        local _, _, _, _, _, _, _, _, _, _, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)
        return isCollected or false
    end
end