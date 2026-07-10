local MCL, MCLcore = ...;

MCLcore.Function = {};
local MCL_functions = MCLcore.Function;
local L   -- Will be initialized lazily when locales are available

MCLcore.mounts = {}
MCLcore.stats= {}
MCLcore.overviewStats = {}
MCLcore.overviewFrames = {}
MCLcore.mountFrames = {}
MCLcore.mountCheck = {}
MCLcore.pinnedMountsChanged = false  -- Flag to track if pinned mounts have been modified

-- Lazy-load locale reference
local function GetL()
    if not L then L = MCLcore.L or {} end
    return L
end

function MCL_functions:getFaction()
    -- * --------------------------------
    -- * Get's player faction
    -- * --------------------------------
	if UnitFactionGroup("player") == "Alliance" then
		return "Horde" -- Inverse
	else
		return "Alliance" -- Inverse
	end
end

-- local function IsMountFactionSpecific(id)
--     if string.sub(id, 1, 1) == "m" then
--         mount_Id = string.sub(id, 2, -1)
--         local mountName, spellID, icon, _, _, _, _, isFactionSpecific, faction, _, isCollected, mountID, _ = C_MountJournal.GetMountInfoByID(mount_Id)
--         return faction, isFactionSpecific
--     else
--         mount_Id = C_MountJournal.GetMountFromItem(id)
--         local mountName, spellID, icon, _, _, _, _, isFactionSpecific, faction, _, isCollected, mountID, _ = C_MountJournal.GetMountInfoByID(mount_Id)
--         return faction, isFactionSpecific
--     end
-- end

local function GetMountInfoByIDChecked(mount_Id)
    local mountName, spellID, icon, _, _, _, _, isFactionSpecific, faction, _, isCollected, mountID, _ = C_MountJournal.GetMountInfoByID(mount_Id)
    return faction, isFactionSpecific
end

local function IsMountFactionSpecific(id)
    local mount_Id, ok, faction, isFactionSpecific

    if string.sub(id, 1, 1) == "m" then
        mount_Id = string.sub(id, 2, -1)
    else
        -- Use session cache to avoid unreliable GetMountFromItem
        if MCLcore.itemToMountCache and MCLcore.itemToMountCache[id] then
            mount_Id = MCLcore.itemToMountCache[id]
        else
            mount_Id = C_MountJournal.GetMountFromItem(id)
            if mount_Id and MCLcore.itemToMountCache then
                MCLcore.itemToMountCache[id] = mount_Id
            end
        end
    end

    -- Use pcall to execute GetMountInfoByIDChecked and capture any error
    local ok, faction, isFactionSpecific = pcall(GetMountInfoByIDChecked, mount_Id)

    -- If an error occurred, print the error message along with the id that caused the error
    if not ok then
        return nil, nil
    else
        return faction, isFactionSpecific
    end
end

MCLcore.Function.IsMountFactionSpecific = IsMountFactionSpecific

function MCL_functions:resetToDefault(setting)
    if setting == nil then
        MCL_SETTINGS = {}        
        MCL_SETTINGS.unobtainable = false
        MCL_SETTINGS.hideCollectedMounts = false
    end
    if setting == "Opacity" or setting == nil then
        MCL_SETTINGS.opacity = 0.95
    end
    if setting == "Texture" or setting == nil then
        MCL_SETTINGS.statusBarTexture = nil
    end
    if setting == "Colors" or setting == nil then
        MCL_SETTINGS.progressColors = {
            low = {
                ["a"] = 1,
                ["r"] = 0.929,
                ["g"] = 0.007,
                ["b"] = 0.019,
            },
            high = {
                ["a"] = 1,
                ["r"] = 0.1,
                ["g"] = 0.9,
                ["b"] = 0.1,
            },
            medium = {
                ["a"] = 1,
                ["r"] = 0.941,
                ["g"] = 0.658,
                ["b"] = 0.019,
            },
            complete = {
                ["a"] = 1,
                ["r"] = 0,
                ["g"] = 0.5,
                ["b"] = 0.9,
            },
        }
    end
    if setting == "HideCollectedMounts" or setting == nil then
        MCL_SETTINGS.hideCollectedMounts = false
    end
    if setting == "MountsPerRow" or setting == nil then
        MCL_SETTINGS.mountsPerRow = 12
    end
    if setting == "MountCardHover" or setting == nil then
        MCL_SETTINGS.enableMountCardHover = true
    end
    if setting == "Toast" or setting == nil then
        MCL_SETTINGS.enableCollectedToast = true
        MCL_SETTINGS.enableCollectedSound = true
        MCL_SETTINGS.enableCategoryCompleteToast = true
        MCL_SETTINGS.enableCategoryCompleteSound = true
        MCL_SETTINGS.enableSectionCompleteToast = true
        MCL_SETTINGS.enableSectionCompleteSound = true
        MCL_SETTINGS.toastPosition = nil
    end
end

if MCL_SETTINGS == nil then
    MCLcore.Function:resetToDefault()
end

-- Ensure mountsPerRow setting exists for existing users
if MCL_SETTINGS.mountsPerRow == nil then
    MCL_SETTINGS.mountsPerRow = 12
end

-- Ensure enableMountCardHover setting exists for existing users
if MCL_SETTINGS.enableMountCardHover == nil then
    MCL_SETTINGS.enableMountCardHover = true
end

-- Ensure toast settings exist for existing users
if MCL_SETTINGS.enableCollectedToast == nil then
    MCL_SETTINGS.enableCollectedToast = true
end
if MCL_SETTINGS.enableCollectedSound == nil then
    MCL_SETTINGS.enableCollectedSound = true
end
if MCL_SETTINGS.enableCategoryCompleteToast == nil then
    MCL_SETTINGS.enableCategoryCompleteToast = true
end
if MCL_SETTINGS.enableCategoryCompleteSound == nil then
    MCL_SETTINGS.enableCategoryCompleteSound = true
end
if MCL_SETTINGS.enableSectionCompleteToast == nil then
    MCL_SETTINGS.enableSectionCompleteToast = true
end
if MCL_SETTINGS.enableSectionCompleteSound == nil then
    MCL_SETTINGS.enableSectionCompleteSound = true
end

-- Tables Mounts into Global List
function MCL_functions:TableMounts(id, frame, section, category)
    local mount = {
        id = id,
        frame = frame,
        section =  section,
        category = category,
    }
    table.insert(MCLcore.mounts, mount)
end

-- Styled copy/link popup - MCL themed, reusable for URLs and text
-- Namespaced under MCLcore.Function; global alias kept for backward compat
function MCL_functions:ShowEditBox(text)
    KethoEditBox_Show(text)  -- delegate to setup function below
end
function KethoEditBox_Show(text)
    if not KethoEditBox then
        local f = CreateFrame("Frame", "KethoEditBox", UIParent)
        f:SetPoint("CENTER")
        f:SetSize(500, 50)
        f:SetFrameStrata("DIALOG")

        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        f:SetBackdropBorderColor(0, 0.44, 0.87, 0.8)

        -- Movable
        f:SetMovable(true)
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        f:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                self:StartMoving()
            end
        end)
        f:SetScript("OnMouseUp", f.StopMovingOrSizing)

        -- Ctrl+C label
        local copyLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        copyLabel:SetPoint("LEFT", f, "LEFT", 10, 0)
        copyLabel:SetText(GetL()["Ctrl+C:"])
        copyLabel:SetTextColor(0.5, 0.5, 0.5, 1)

        -- EditBox
        local eb = CreateFrame("EditBox", "KethoEditBoxEditBox", f)
        eb:SetPoint("LEFT", copyLabel, "RIGHT", 6, 0)
        eb:SetPoint("RIGHT", f, "RIGHT", -30, 0)
        eb:SetHeight(20)
        eb:SetFontObject("ChatFontNormal")
        eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)

        -- Close button
        local closeBtn = CreateFrame("Button", nil, f)
        closeBtn:SetSize(16, 16)
        closeBtn:SetPoint("RIGHT", f, "RIGHT", -6, 0)
        closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        f:Show()
    end

    if text then
        KethoEditBoxEditBox:SetText(text)
        KethoEditBoxEditBox:SetFocus()
        KethoEditBoxEditBox:HighlightText()
    end
    KethoEditBox:Show()
end

function MCL_functions:simplearmoryLink()
    local region = GetCVar("portal")

    local realmName = GetRealmName()

    local playerName = UnitName("player")

    local string = "https://simplearmory.com/#/"..region.."/"..realmName.."/"..playerName

    KethoEditBox_Show(string)

end

function MCL_functions:dfaLink()
    local region = GetCVar("portal")

    local realmName = GetRealmName()

    local playerName = UnitName("player")

    local string = "https://www.dataforazeroth.com/characters/"..region.."/"..realmName.."/"..playerName

    KethoEditBox_Show(string)

end

function MCL_functions:reportLink()
    KethoEditBox_Show("https://discord.gg/YvrpHSyqtj")
end

function MCL_functions:compareLink()
    local region = GetCVar("portal")

    local realmName = GetRealmName()

    local playerName = UnitName("player")
    local targetName, targetRealm
    if UnitIsPlayer("target") then
        targetName, targetRealm = UnitName("target")
        if targetRealm == nil then
            targetRealm = realmName
        end
    else
        KethoEditBox_Show(GetL()["Mount off requires a target"])
        return
    end
    
    local string = "https://wow-mcl.herokuapp.com/?realma="..region.."."..realmName.."&charactera="..playerName.."&realmb="..region.."."..targetRealm.."&characterb="..targetName
    
    KethoEditBox_Show(string)
end

function MCL_functions:initSections()
    -- * --------------------------------
    -- * Create variables and assign strings to each section.
    -- * --------------------------------

    local faction = MCL_functions:getFaction()
    MCLcore.sections = {}

    for i, v in ipairs(MCLcore.sectionNames) do
        -- Skip opposite faction section
        if v.name ~= faction then
            table.insert(MCLcore.sections, v)
        end
    end

    MCLcore.MCL_MF_Nav = MCLcore.Frames:createNavFrame(MCLcore.MCL_MF, GetL()["Sections"])

    -- Create the overview parent frame before SetTabs
    if not MCLcore.overview or not MCLcore.overview:IsObjectType("Frame") then
        -- Use dynamic width from the actual main frame instead of a hardcoded value
        local curWidth = MCLcore.Frames:GetCurrentFrameDimensions()
        MCLcore.overview = CreateFrame("Frame", nil, MCL_mainFrame.ScrollChild)
        MCLcore.overview:SetSize(curWidth - 40, 550)  -- Symmetric padding within scroll viewport
        MCLcore.overview:SetPoint("TOPLEFT", MCL_mainFrame.ScrollChild, "TOPLEFT", 10, 0)  -- Consistent with other content frames
        MCLcore.overview:SetBackdropColor(0, 0, 0, 0)
    end
    -- Build the overview content into the overview frame
    MCLcore.Frames:createOverviewCategory(MCLcore.sections, MCLcore.overview)

    local tabFrames, numTabs = MCLcore.Frames:SetTabs() 

    MCLcore.sectionFrames = {}
    for i=1, numTabs do
        -- The section frames are already created in SetTabs, just reference them
        if tabFrames and tabFrames[i] then
            table.insert(MCLcore.sectionFrames, tabFrames[i])
        end
    end    
end


function MCL_functions:GetCollectedMounts()
    local mounts = {}
    for k,v in pairs(C_MountJournal.GetMountIDs()) do
        local mountName, spellID, icon, _, isUsable, _, _, isFactionSpecific, faction, _, isCollected, mountID = C_MountJournal.GetMountInfoByID(v)
        if isCollected then
            if faction then
                if faction == 1 then
                    faction = "Alliance"
                else
                    faction = "Horde"
                end
            end
            if (isFactionSpecific == false) or (isFactionSpecific == true and faction == UnitFactionGroup("player")) then                     
                table.insert(mounts, mountID)
            end   
        end
    end
end

function MCL_functions:CreateBorder(frame, side)
    frame.borders = frame:CreateLine(nil, "BACKGROUND", nil, 0)
    local l = frame.borders
    l:SetThickness(1)
    l:SetColorTexture(1, 1, 1, 0.4)
	l:SetStartPoint("BOTTOM"..side)
	l:SetEndPoint("TOP"..side)
    return frame
end


function MCL_functions:CreateFullBorder(self)
    if not self.borders then
        self.borders = {}
        for i=1, 4 do
            self.borders[i] = self:CreateLine(nil, "BACKGROUND", nil, 0)
            local l = self.borders[i]
            l:SetThickness(2)
            l:SetColorTexture(0, 0, 0, 0.7)
            if i==1 then
                l:SetStartPoint("TOPLEFT", 0, 1)
                l:SetEndPoint("TOPRIGHT", 0, 1)
            elseif i==2 then
                l:SetStartPoint("TOPRIGHT", 0, 1)
                l:SetEndPoint("BOTTOMRIGHT", 0, 2)
            elseif i==3 then
                l:SetStartPoint("BOTTOMRIGHT", 0, 2)
                l:SetEndPoint("BOTTOMLEFT", 0, 2)
            else
                l:SetStartPoint("BOTTOMLEFT", 0, 2)
                l:SetEndPoint("TOPLEFT", 0, 1)
            end
        end
    end
end

function MCL_functions:getTableLength(set)
    local i = 0
    for _ in pairs(set) do
        i = i + 1
    end
    return i
end

function MCL_functions:SetMouseClickFunctionality(frame, mountID, mountName, itemLink, spellID, isSteadyFlight, isPin)

    local lastLeftClick = 0
    frame:SetScript("OnMouseDown", function(self, button)
        if IsControlKeyDown() then
            if button == 'LeftButton' then
                if DressUpMount then
                    DressUpMount(mountID)
                -- else: silently skip, mount dressing room not available in MoP
                end
            elseif button == 'RightButton' then
                -- Allow pinning of both collected and uncollected mounts
                -- Initialize MCL_PINNED if it doesn't exist
                if not MCL_PINNED then
                    MCL_PINNED = {}
                end
                
                local pin = false
                local pin_count = #MCL_PINNED
                for i=1, pin_count do
                    if MCL_PINNED[i].mountID == "m"..mountID then
                        pin = i
                        if isPin then break end
                    end
                end

                if pin ~= false then
                    if frame.pin then
                        frame.pin:SetAlpha(0)
                    end
                    table.remove(MCL_PINNED, pin)
                    MCLcore.Function:RebuildPinnedLookup()
                    
                    -- Set flag to indicate pinned mounts have been modified
                    MCLcore.pinnedMountsChanged = true
                    
                    -- Update all pin icons for this mount
                    MCLcore.Function:UpdateAllPinIcons(mountID)

                    if isPin then
                        -- Refresh the pinned section by recreating it
                        if MCLcore.pinnedFrame then
                            -- Clear existing mount frames more thoroughly
                            if MCLcore.mountFrames[1] then
                                for _, oldFrame in ipairs(MCLcore.mountFrames[1]) do
                                    if oldFrame and oldFrame:GetParent() then
                                        oldFrame:Hide()
                                        oldFrame:SetParent(nil)
                                    end
                                end
                            end
                            
                            -- Also clear any untracked children of PinnedFrame
                            local children = {MCLcore.pinnedFrame:GetChildren()}
                            for _, child in ipairs(children) do
                                if child and child:IsObjectType("Button") and child.mountID then
                                    child:Hide()
                                    child:SetParent(nil)
                                end
                            end
                            
                            MCLcore.mountFrames[1] = {}
                            
                            -- Clean up invalid pinned mounts before recreating
                            MCLcore.Function:CleanupInvalidPinnedMounts()
                            
                            -- Recreate the pinned section content
                            local overflow, mountFrame = MCLcore.Function:CreateMountsForCategory(MCL_PINNED, MCLcore.pinnedFrame, 30, MCLcore.pinnedTab, true, true)
                            MCLcore.mountFrames[1] = mountFrame
                        end
                    else
                        local index = 0
                        -- Initialize MCLcore.mountFrames[1] if it doesn't exist
                        if not MCLcore.mountFrames[1] then
                            MCLcore.mountFrames[1] = {}
                        end
                        for k,v in pairs(MCLcore.mountFrames[1]) do
                            index = index + 1
                            if tostring(v.mountID) == tostring(mountID) then
                                MCLcore.mountFrames[1][index]:Hide()                                
                                table.remove(MCLcore.mountFrames[1],  index)
                                for kk,vv in ipairs(MCLcore.mountFrames[1]) do
                                    if kk == 1 then
                                        vv:SetParent(MCLcore.pinnedFrame)
                                        vv:Show()
                                    else
                                        vv:SetParent(MCLcore.mountFrames[1][kk-1])
                                        vv:Show()
                                    end
                                end                                
                            end
                        end
                        
                        -- Refresh the pinned tab layout after unpinning
                        if MCL_frames and MCL_frames.RefreshLayout then
                            -- Check if we're currently viewing the Pinned tab
                            local isPinnedTabActive = false
                            if MCLcore.currentlySelectedTab and MCLcore.currentlySelectedTab.section and MCLcore.currentlySelectedTab.section.name == "Pinned" then
                                isPinnedTabActive = true
                            end
                            
                            -- Refresh the layout to update the pinned content
                            MCLcore.Frames:RefreshLayout()
                            
                            -- If we were on the Pinned tab, reselect it
                            if isPinnedTabActive and MCLcore.MCL_MF_Nav and MCLcore.MCL_MF_Nav.tabs then
                                for _, tab in ipairs(MCLcore.MCL_MF_Nav.tabs) do
                                    if tab.section and tab.section.name == "Pinned" then
                                        tab:GetScript("OnClick")(tab)
                                        break
                                    end
                                end
                            end
                        end
                    end
                else	                            
                    if frame.pin then
                        frame.pin:SetAlpha(1)
                    end
                    local t = {
                        mountID = "m"..mountID,
                        category = frame.category,
                        section = frame.section
                    }
                    if pin_count == 0 then
                        MCL_PINNED[1] = t
                    else
                        MCL_PINNED[pin_count+1] = t
                    end
                    MCLcore.Function:RebuildPinnedLookup()
                    
                    -- Set flag to indicate pinned mounts have been modified
                    MCLcore.pinnedMountsChanged = true
                    
                    MCLcore.Function:CreatePinnedMount(mountID, frame.category, frame.section)
                    -- Update all pin icons for this mount
                    MCLcore.Function:UpdateAllPinIcons(mountID)

                    -- Refresh the pinned tab layout after pinning
                    C_Timer.After(0.1, function()
                        if MCL_frames and MCL_frames.SetTabs then
                            -- Check if we're currently viewing the Pinned tab
                            local isPinnedTabActive = false
                            if MCLcore.currentlySelectedTab and MCLcore.currentlySelectedTab.section and MCLcore.currentlySelectedTab.section.name == "Pinned" then
                                isPinnedTabActive = true
                            end
                            
                            -- Refresh the tabs to update the pinned content
                            MCLcore.Frames:SetTabs()
                            
                            -- If we were on the Pinned tab, reselect it
                            if isPinnedTabActive and MCLcore.MCL_MF_Nav and MCLcore.MCL_MF_Nav.tabs then
                                for _, tab in ipairs(MCLcore.MCL_MF_Nav.tabs) do
                                    if tab.section and tab.section.name == "Pinned" then
                                        tab:GetScript("OnClick")(tab)
                                        break
                                    end
                                end
                            end
                        end
                    end)

                end
            end               
        elseif button=='LeftButton' then
            if IsShiftKeyDown() then
                -- Handle shift-click to link mount in chat
                if itemLink and ChatEdit_GetActiveWindow() then
                    ChatEdit_InsertLink(itemLink)
                elseif spellID then
                    local spellLink = GetSpellLink(spellID)
                    if spellLink and ChatEdit_GetActiveWindow() then
                        ChatEdit_InsertLink(spellLink)
                    end
                end
            else
                -- Double-click to summon collected mount
                local now = GetTime()
                if (now - lastLeftClick) < 0.3 then
                    if IsMountCollected(mountID) then
                        C_MountJournal.SummonByID(mountID)
                    end
                    lastLeftClick = 0
                else
                    lastLeftClick = now
                    -- Single-click: toggle dragonriding popup if applicable
                    if isSteadyFlight and not isPin then
                        if frame.pop and frame.pop:IsShown() then 
                            frame.pop:Hide()
                        elseif frame.pop then
                            frame.pop:Show()
                        end
                    end
                end
            end
        elseif button == 'RightButton' and not IsControlKeyDown() then
            -- Right-click to show/hide mount card
            if MCLcore and MCLcore.MountCard then
                local mountData = {
                    mountID = mountID,
                    id = mountID,
                    name = mountName,
                    category = frame.category,
                    section = frame.section
                }
                MCLcore.MountCard.Toggle(mountData, frame)
            end
        end
        if button == 'MiddleButton' then
            -- Middle click to cast mount if it's collected
            if IsMountCollected(mountID) then
                CastSpellByName(mountName);
            end
        end
    end)
end

-- Adds an "Origin: Section > Category" line to GameTooltip for pinned mounts
local function AddOriginTooltipLine(frame, isPinned)
    if isPinned and frame.section and frame.category then
        local origin
        local sec = GetL()[frame.section]
        local cat = GetL()[frame.category]
        if frame.section ~= "Unknown" and frame.category ~= "Unknown" then
            origin = sec .. " > " .. cat
        elseif frame.section ~= "Unknown" then
            origin = sec
        elseif frame.category ~= "Unknown" then
            origin = cat
        end
        if origin then
            GameTooltip:AddLine(GetL()["Origin:"] .. " " .. origin, 0.5, 0.7, 1)
        end
    end
end

function MCL_functions:LinkMountItem(id, frame, pin, dragonriding)
	--Adding a tooltip for mounts
    if string.sub(id, 1, 1) == "m" then
        id = string.sub(id, 2, -1)
        local mountName, spellID, icon, _, _, _, _, isFactionSpecific, faction, _, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(id)

        frame:HookScript("OnEnter", function()
            -- Pre-check if mount data is available before showing tooltip
            local function isSourceDataReady()
                local _, description, source, _, mountTypeID, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(id)
                return source and source ~= ""
            end
            
            -- If source data is ready, show tooltip immediately
            if isSourceDataReady() then
                GameTooltip:SetOwner(frame, "ANCHOR_TOPLEFT")
                if (spellID) then
                    GameTooltip:SetSpellByID(spellID)
                    
                    local _, description, source, _, mountTypeID, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(id)
                    GameTooltip:AddLine(source)
                    AddOriginTooltipLine(frame, pin)
                    GameTooltip:Show()
                    frame:SetHyperlinksEnabled(true)
                end
            else
                -- Force load mount data and delay tooltip
                C_MountJournal.GetMountInfoByID(id) -- Ensure data is loaded
                
                C_Timer.After(0.15, function()
                    -- Only show delayed tooltip if mouse is still over the frame
                    if frame:IsMouseOver() then
                        local _, description, source, _, mountTypeID, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(id)
                        local sourceText = source and source ~= "" and source or nil
                        
                        -- If no Blizzard source, use MCL section/category fallback
                        if not sourceText then
                            if frame.section and frame.category then
                                if frame.section ~= "Unknown" and frame.category ~= "Unknown" then
                                    sourceText = GetL()[frame.section] .. " - " .. GetL()[frame.category]
                                elseif frame.section ~= "Unknown" then
                                    sourceText = GetL()[frame.section]
                                elseif frame.category ~= "Unknown" then
                                    sourceText = GetL()[frame.category]
                                end
                            end
                        end
                        sourceText = sourceText or GetL()["Unknown"]
                        
                        GameTooltip:SetOwner(frame, "ANCHOR_TOPLEFT")
                        if (spellID) then
                            GameTooltip:SetSpellByID(spellID)
                            GameTooltip:AddLine(sourceText)
                            AddOriginTooltipLine(frame, pin)
                            GameTooltip:Show()
                            frame:SetHyperlinksEnabled(true)
                        end
                    end
                end)
            end
            
            -- Show MountCard on hover (only if enabled in settings)
            if MCLcore and MCLcore.MountCard and MCL_SETTINGS.enableMountCardHover then
                local mountData = {
                    mountID = mountID,
                    id = mountID,
                    name = mountName,
                    category = frame.category,
                    section = frame.section
                }
                MCLcore.MountCard.ShowOnHover(mountData, frame, 0.2)  -- Reduced from 0.8 to 0.2
            end
        end)
        frame:HookScript("OnLeave", function()
            GameTooltip:Hide()
            -- Note: MountCard is now persistent, so we don't hide it on hover end
        end)
        MCLcore.Function:SetMouseClickFunctionality(frame, mountID, mountName, itemLink, spellID, isSteadyFlight, pin)  
    else
        local item, itemLink = GetItemInfo(id);
        if dragonriding then
            frame:HookScript("OnEnter", function()
                -- Pre-check if dragonriding mount source data is available
                local function isDragonridingSourceReady()
                    local mountID = MCLcore.itemToMountCache and MCLcore.itemToMountCache[id] or C_MountJournal.GetMountFromItem(id)
                    if mountID then
                        if MCLcore.itemToMountCache then MCLcore.itemToMountCache[id] = mountID end
                        local _, description, source, _, mountTypeID, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(mountID)
                        return source and source ~= "", mountID
                    end
                    return false, nil
                end
                
                local isReady, mountID = isDragonridingSourceReady()
                
                if isReady then
                    -- Source data is ready, show tooltip immediately
                    GameTooltip:SetOwner(frame, "ANCHOR_TOPLEFT")
                    if (id) then
                        GameTooltip:SetItemByID(id)
                        local _, description, source, _, mountTypeID, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(mountID)
                        GameTooltip:AddLine(source)
                        AddOriginTooltipLine(frame, pin)
                        GameTooltip:Show()
                        frame:SetHyperlinksEnabled(true)
                    end
                else
                    -- Force load data and delay tooltip
                    if mountID then
                        C_MountJournal.GetMountInfoByID(mountID) -- Ensure data is loaded
                    end
                    
                    C_Timer.After(0.15, function()
                        -- Only show delayed tooltip if mouse is still over the frame
                        if frame:IsMouseOver() then
                            local retryMountID = MCLcore.itemToMountCache and MCLcore.itemToMountCache[id] or C_MountJournal.GetMountFromItem(id)
                            if retryMountID and MCLcore.itemToMountCache then MCLcore.itemToMountCache[id] = retryMountID end
                            local sourceText = nil
                            
                            if retryMountID then
                                local _, description, source, _, mountTypeID, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(retryMountID)
                                if source and source ~= "" then
                                    sourceText = source
                                end
                            end
                            
                            -- Fallback to MCL's category/section information if still no source
                            if not sourceText then
                                if frame.section and frame.category then
                                    if frame.section ~= "Unknown" and frame.category ~= "Unknown" then
                                        sourceText = GetL()[frame.section] .. " - " .. GetL()[frame.category]
                                    elseif frame.section ~= "Unknown" then
                                        sourceText = GetL()[frame.section]
                                    elseif frame.category ~= "Unknown" then
                                        sourceText = GetL()[frame.category]
                                    end
                                end
                            end
                            
                            -- Final fallback to the passed source parameter
                            if not sourceText and frame.source then
                                sourceText = frame.source
                            end
                            sourceText = sourceText or GetL()["Unknown"]
                            
                            GameTooltip:SetOwner(frame, "ANCHOR_TOPLEFT")
                            if (id) then
                                GameTooltip:SetItemByID(id)
                                GameTooltip:AddLine(sourceText)
                                AddOriginTooltipLine(frame, pin)
                                GameTooltip:Show()
                                frame:SetHyperlinksEnabled(true)
                            end
                        end
                    end)
                end
                
                -- Show MountCard on hover for dragonriding mounts (only if enabled in settings)
                if MCLcore and MCLcore.MountCard and MCL_SETTINGS.enableMountCardHover then
                    local mountData = {
                        mountID = id,
                        id = id,
                        name = item or GetL()["Unknown Mount"],
                        category = frame.category,
                        section = frame.section
                    }
                    MCLcore.MountCard.ShowOnHover(mountData, frame, 0.2)  -- Reduced from 0.8 to 0.2
                end
            end)
            frame:HookScript("OnLeave", function()
                GameTooltip:Hide()
                -- Note: MountCard is now persistent, so we don't hide it on hover end
            end)

        else
            local mountID = (MCLcore.itemToMountCache and MCLcore.itemToMountCache[id]) or C_MountJournal.GetMountFromItem(id)
            if mountID and MCLcore.itemToMountCache then MCLcore.itemToMountCache[id] = mountID end
            local mountName, spellID, icon, _, _, _, _, isFactionSpecific, faction, _, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(mountID)
        
            -- Special handling for fallback cases (negative IDs)
            if not mountID and type(id) == "number" and id < 0 then
                local originalItemId = -id
                local itemName, itemLink = GetItemInfo(originalItemId)
                
                frame:HookScript("OnEnter", function()
                    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
                    if itemLink then
                        GameTooltip:SetHyperlink(itemLink)
                        GameTooltip:AddLine("|cFFFF0000" .. GetL()["[MCL] Mount data not fully loaded"] .. "|r")
                        GameTooltip:AddLine("|cFFFFFF00" .. GetL()["Try reloading UI or restarting game"] .. "|r")
                        GameTooltip:Show()
                        frame:SetHyperlinksEnabled(true)
                    else
                        GameTooltip:SetText(string.format("Item ID: %d", originalItemId))
                        GameTooltip:AddLine("|cFFFF0000" .. GetL()["[MCL] Mount data not available"] .. "|r")
                        GameTooltip:Show()
                    end
                end)
                frame:HookScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                return
            end
            
            frame:HookScript("OnEnter", function()
                -- Pre-check if item-based mount source data is available
                local function isItemMountSourceReady()
                    local _, description, source, _, mountTypeID, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(mountID)
                    return source and source ~= ""
                end
                
                if isItemMountSourceReady() then
                    -- Source data is ready, show tooltip immediately
                    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
                    if (itemLink) then
                        frame:SetHyperlinksEnabled(true)
                        GameTooltip:SetHyperlink(itemLink)
                        local _, description, source, _, mountTypeID, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(mountID)
                        GameTooltip:AddLine(source)
                        AddOriginTooltipLine(frame, pin)
                        GameTooltip:Show()
                    end
                else
                    -- Force load data and delay tooltip
                    C_MountJournal.GetMountInfoByID(mountID) -- Ensure data is loaded
                    
                    C_Timer.After(0.15, function()
                        -- Only show delayed tooltip if mouse is still over the frame
                        if frame:IsMouseOver() then
                            local _, description, source, _, mountTypeID, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(mountID)
                            local sourceText = source and source ~= "" and source or nil
                            
                            -- Fallback to MCL's category/section information if still no source
                            if not sourceText then
                                if frame.section and frame.category then
                                    if frame.section ~= "Unknown" and frame.category ~= "Unknown" then
                                        sourceText = GetL()[frame.section] .. " - " .. GetL()[frame.category]
                                    elseif frame.section ~= "Unknown" then
                                        sourceText = GetL()[frame.section]
                                    elseif frame.category ~= "Unknown" then
                                        sourceText = GetL()[frame.category]
                                    end
                                end
                            end
                            sourceText = sourceText or GetL()["Unknown"]
                            
                            GameTooltip:SetOwner(frame, "ANCHOR_TOP")
                            if (itemLink) then
                                frame:SetHyperlinksEnabled(true)
                                GameTooltip:SetHyperlink(itemLink)
                                GameTooltip:AddLine(sourceText)
                                AddOriginTooltipLine(frame, pin)
                                GameTooltip:Show()
                            end
                        end
                    end)
                end
                
                -- Show MountCard on hover for item-based mounts (only if enabled in settings)
                if MCLcore and MCLcore.MountCard and mountID and MCL_SETTINGS.enableMountCardHover then
                    local mountData = {
                        mountID = mountID,
                        id = mountID,
                        name = mountName,
                        category = frame.category,
                        section = frame.section
                    }
                    MCLcore.MountCard.ShowOnHover(mountData, frame, 0.2)  -- Reduced from 0.8 to 0.2
                end
            end)
            frame:HookScript("OnLeave", function()
                GameTooltip:Hide()
                -- Note: MountCard is now persistent, so we don't hide it on hover end
            end)
            MCLcore.Function:SetMouseClickFunctionality(frame, mountID, mountName, itemLink, _, isSteadyFlight, pin)
        end
    end
      
end


function MCL_functions:CompareMountJournal()
    local mounts = {}
    local i = 1
    for k,v in pairs(C_MountJournal.GetMountIDs()) do
        mounts[i] = v
        for kk,vv in pairs(MCLcore.mounts) do
            if vv.id == mounts[i] then
                mounts[i] = nil
            end
        end
    end
    for x,y in ipairs(mounts) do
        if y ~= nil then
            local mountName, spellID, icon, _, _, _, _, isFactionSpecific, faction, _, isCollected, mountID, _ = C_MountJournal.GetMountInfoByID(y)
        end
    end
end


-- Cached lookup table for O(1) pin checks. Rebuilt whenever MCL_PINNED changes.
local pinnedLookup = nil

function MCL_functions:RebuildPinnedLookup()
    pinnedLookup = {}
    if MCL_PINNED then
        for k, v in pairs(MCL_PINNED) do
            if v and v.mountID then
                pinnedLookup[v.mountID] = k
            end
        end
    end
end

function MCL_functions:CheckIfPinned(mountID)
    if MCL_PINNED == nil then
        MCL_PINNED = {}
    end
    if not pinnedLookup then
        self:RebuildPinnedLookup()
    end
    local idx = pinnedLookup[mountID]
    if idx then
        return true, idx
    end
    return false, nil
end

function MCL_functions:CleanupInvalidPinnedMounts()
    if not MCL_PINNED then
        MCL_PINNED = {}
        return
    end
    
    local validPinnedMounts = {}
    local removedCount = 0
    
    for k, v in pairs(MCL_PINNED) do
        if v and v.mountID then
            local mountId = v.mountID
            local mount_Id = nil
            
            -- Extract numeric ID from string format (e.g., "m517" -> 517)
            if string.sub(tostring(mountId), 1, 1) == "m" then
                mount_Id = tonumber(string.sub(tostring(mountId), 2, -1))
            else
                mount_Id = tonumber(mountId)
            end
            
            -- Check if this mount ID is valid by trying to get mount info
            if mount_Id then
                local mountName, spellID, icon = C_MountJournal.GetMountInfoByID(mount_Id)
                
                if mountName and mountName ~= "" then
                    -- Mount is valid, keep it
                    table.insert(validPinnedMounts, v)
                else
                    -- Mount is invalid, remove it
                    removedCount = removedCount + 1
                end
            else
                -- Invalid format, remove it
                removedCount = removedCount + 1
            end
        end
    end
    
    -- Replace MCL_PINNED with only valid mounts
    MCL_PINNED = validPinnedMounts
    self:RebuildPinnedLookup()
    
    if removedCount > 0 then
        print("|cFF1FB7EBMCL|r: Cleaned up " .. removedCount .. " invalid pinned mounts")
    end
end
