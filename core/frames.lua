local MCL, MCLcore = ...;

local MCL_Load = MCLcore.Main;

MCLcore.Frames = {};
local MCL_frames = MCLcore.Frames;

MCLcore.TabTable = {}
MCLcore.statusBarFrames  = {}

MCLcore.nav_width = 180
local nav_width = MCLcore.nav_width
local main_frame_width = 800
local main_frame_height = 600

-- Sort modes for mount lists within categories
local SORT_MODES

-- Resolve a mount entry (item ID, "mXXX" string, etc.) into a sortable name and collected flag
local function ResolveMountSortInfo(mountId)
    local mount_Id = MCLcore.Function and MCLcore.Function.GetMountID and MCLcore.Function:GetMountID(mountId)
    if not mount_Id or mount_Id <= 0 then
        return tostring(mountId), false
    end
    local mountName = C_MountJournal.GetMountInfoByID(mount_Id)
    local collected = IsMountCollected(mount_Id)
    return mountName or tostring(mountId), collected or false
end

-- Sort a mount list in-place according to the given sort mode key
local function SortMountList(list, mode)
    if not mode or mode == "default" or not list or #list < 2 then return end
    -- Build a cache of sort info so we only resolve once per mount
    local cache = {}
    for i, id in ipairs(list) do
        local name, collected = ResolveMountSortInfo(id)
        cache[i] = { idx = i, name = name, collected = collected }
    end
    table.sort(cache, function(a, b)
        if mode == "name_asc" then
            return a.name < b.name
        elseif mode == "name_desc" then
            return a.name > b.name
        elseif mode == "collected" then
            if a.collected ~= b.collected then return a.collected end
            return a.name < b.name
        elseif mode == "uncollected" then
            if a.collected ~= b.collected then return not a.collected end
            return a.name < b.name
        end
        return a.idx < b.idx
    end)
    -- Rebuild the list in sorted order
    local sorted = {}
    for _, entry in ipairs(cache) do
        table.insert(sorted, list[entry.idx])
    end
    for i, v in ipairs(sorted) do
        list[i] = v
    end
end

local r,g,b,a

local L = MCLcore.L

SORT_MODES = {
    { key = "default",     label = L["Default"] },
    { key = "name_asc",    label = L["Name A-Z"] },
    { key = "name_desc",   label = L["Name Z-A"] },
    { key = "collected",   label = L["Collected First"] },
    { key = "uncollected", label = L["Uncollected First"] },
}

-- Recursively release all children of a frame.
-- Children are hidden, stripped of scripts, and orphaned so they stop
-- consuming rendering or event-handling resources. WoW frames cannot be
-- truly destroyed, but orphaning them is the next best thing.
local function ReleaseFrameChildren(frame)
    if not frame then return end
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do
        ReleaseFrameChildren(child) -- depth-first
        child:Hide()
        child:ClearAllPoints()
        -- Not all frame types support every script handler (e.g. StatusBar
        -- has no OnClick), so guard each call with pcall.
        for _, script in ipairs({"OnClick","OnEnter","OnLeave","OnMouseDown","OnMouseUp"}) do
            pcall(child.SetScript, child, script, nil)
        end
        child:SetParent(nil)
    end
end

-- Performance Throttling Helper Function
local function ThrottledFrameCreation(categoryData, callback)
    if not categoryData or type(categoryData) ~= "table" then
        return
    end
    
    -- Convert categoryData to array if it's not already
    local dataArray = {}
    for k, v in pairs(categoryData) do
        if type(v) == "table" then
            table.insert(dataArray, {key = k, data = v})
        end
    end
    
    if #dataArray == 0 then
        return
    end
    
    local index = 1
    local batchSize = 5  -- Process 5 categories at a time
    local batchDelay = 0.02  -- 20ms delay between batches
    
    local function processNextBatch()
        local processed = 0
        while index <= #dataArray and processed < batchSize do
            local success, error = pcall(callback, dataArray[index].key, dataArray[index].data)
            if not success then
                print("MCL Error processing category:", error)
            end
            index = index + 1
            processed = processed + 1
        end
        
        if index <= #dataArray then
            C_Timer.After(batchDelay, processNextBatch)
        end
    end
    
    processNextBatch()
end

-- Throttled Mount Creation Helper
local function ThrottledMountCreation(mountList, categoryFrame, config, callback)
    -- Optional debug logging: enable with /run MCL_SETTINGS.debugRender=true then /reload
    local function isDebugCategory()
        if not (MCL_SETTINGS and MCL_SETTINGS.debugRender) then
            return false
        end
        local name = tostring(config and config.categoryName or ""):lower()
        return (name == "quest" or name == "dungeon drop" or name == "dungeondrop" or name == "dungeon")
    end

    local debugCategory = isDebugCategory()
    if debugCategory then
        print(string.format("MCL DEBUG: Rendering category '%s' (%s mounts in data)", tostring(config and config.categoryName or "?"), tostring(mountList and #mountList or 0)))
    end

    if not mountList or #mountList == 0 then
        if callback then callback() end
        return
    end
    
    -- Validate input data
    if not categoryFrame or not config then
        print("MCL Error: Invalid parameters passed to ThrottledMountCreation")
        if callback then callback() end
        return
    end
    
    -- Validate config structure
    local requiredConfigFields = {"maxDisplayMounts", "mountsPerRow", "mountSize", "actualSpacing", "rowSpacing", "mountStartX", "mountStartY"}
    for _, field in ipairs(requiredConfigFields) do
        if not config[field] then
            print("MCL Error: Missing config field: " .. field)
            if callback then callback() end
            return
        end
    end
    
    local index = 1
    local displayedIndex = 0
    local batchSize = 20  -- Process 20 mounts at a time to prevent timeout
    local batchDelay = 0.05  -- 50ms delay between batches
    local processedCount = 0
    local maxMounts = 2000  -- Safety limit to prevent runaway processing
    
    local function processNextBatch()
        local processed = 0
        local startIndex = index
        
        while index <= #mountList and processed < batchSize and processedCount < maxMounts do
            local mountId = mountList[index]
            local shouldProcess = true
            local skipReason = nil
            
            -- Validate mount data
            if not mountId or (type(mountId) ~= "number" and type(mountId) ~= "string") then
                print("MCL Warning: Invalid mount ID at index " .. index .. ": " .. tostring(mountId))
                shouldProcess = false
                skipReason = "invalid mountId type"
            end
            
            local mount_Id = nil
            if shouldProcess then
                mount_Id = MCLcore.Function and MCLcore.Function.GetMountID and MCLcore.Function:GetMountID(mountId)
                
                -- Skip invalid mount IDs
                if not mount_Id or type(mount_Id) ~= "number" or mount_Id <= 0 then
                    shouldProcess = false
                    skipReason = "GetMountID returned nil/invalid"
                end
            end
            
            if shouldProcess then
                -- Faction check: Only display mounts that are not faction-specific or match the player's faction
                local allowed = false
                if MCLcore.Function and MCLcore.Function.IsMountFactionSpecific then
                    local faction, faction_specific = MCLcore.Function.IsMountFactionSpecific(mountId)
                    local playerFaction = UnitFactionGroup("player")
                    if faction_specific == false then
                        allowed = true
                    elseif faction_specific == true then
                        if faction == 0 then faction = "Horde" elseif faction == 1 then faction = "Alliance" end
                        allowed = (faction == playerFaction)
                    end
                else
                    allowed = true  -- Allow if faction check function is not available
                end
                
                if allowed and not (mount_Id and MCL_SETTINGS.hideCollectedMounts and IsMountCollected(mount_Id)) then
                displayedIndex = displayedIndex + 1
                if displayedIndex <= config.maxDisplayMounts then
                    if debugCategory then
                        local collected = (mount_Id and IsMountCollected(mount_Id)) and "collected" or "uncollected"
                        print(string.format(
                            "MCL DEBUG: show mountId=%s -> mountID=%s (%s) [%d/%d]",
                            tostring(mountId),
                            tostring(mount_Id),
                            collected,
                            displayedIndex,
                            config.maxDisplayMounts
                        ))
                    end
                    -- Create mount frame using the existing logic
                    local success, error = pcall(function()
                        local col = ((displayedIndex-1) % config.mountsPerRow)
                        local row = math.floor((displayedIndex-1) / config.mountsPerRow)
                        
                        local iconX = config.mountStartX + col * (config.mountSize + config.actualSpacing)
                        local iconY = config.mountStartY - row * (config.mountSize + config.rowSpacing)
                        
                        -- Create backdrop frame first
                        local backdropSize = config.mountSize + 2
                        local backdropFrame = CreateFrame("Frame", nil, categoryFrame)
                        backdropFrame:SetSize(backdropSize, backdropSize)
                        backdropFrame:SetPoint("TOPLEFT", categoryFrame, "TOPLEFT", iconX - 1, iconY + 1)
                        backdropFrame.mountID = mountId
                        
                        -- Create mount frame
                        local mountFrame = CreateFrame("Button", nil, backdropFrame)
                        mountFrame:SetSize(config.mountSize, config.mountSize)
                        mountFrame:SetPoint("CENTER", backdropFrame, "CENTER", 0, 0)
                        mountFrame.mountID = mountId
                        mountFrame.category = config.categoryName
                        mountFrame.section = config.sectionName
                        
                        -- Set mount icon and styling
                        if mount_Id and type(mount_Id) == "number" and mount_Id > 0 then
                            local mountName, spellID, icon = C_MountJournal.GetMountInfoByID(mount_Id)
                            if icon then
                                mountFrame.tex = mountFrame:CreateTexture(nil, "ARTWORK")
                                mountFrame.tex:SetAllPoints(mountFrame)
                                mountFrame.tex:SetTexture(icon)
                                
                                mountFrame.pin = mountFrame:CreateTexture(nil, "OVERLAY")
                                mountFrame.pin:SetWidth(16)
                                mountFrame.pin:SetHeight(16)
                                mountFrame.pin:SetTexture("Interface\\AddOns\\MCL\\icons\\pin.blp")
                                mountFrame.pin:SetPoint("TOPRIGHT", mountFrame, "TOPRIGHT", 6, 6)
                                
                                local pin_check = MCLcore.Function and MCLcore.Function.CheckIfPinned and MCLcore.Function:CheckIfPinned("m"..mount_Id)
                                mountFrame.pin:SetAlpha(pin_check and 1 or 0)
                                
                                if IsMountCollected(mount_Id) then
                                    mountFrame.tex:SetVertexColor(1, 1, 1, 1)
                                    backdropFrame:SetBackdrop({
                                        bgFile = "Interface\\Buttons\\WHITE8x8",
                                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                                        edgeSize = 1
                                    })
                                    backdropFrame:SetBackdropColor(0.12, 0.18, 0.12, 0.5)
                                    backdropFrame:SetBackdropBorderColor(0.25, 0.65, 0.25, 0.8)
                                else
                                    mountFrame.tex:SetVertexColor(0.45, 0.45, 0.45, 0.75)
                                    backdropFrame:SetBackdrop({
                                        bgFile = "Interface\\Buttons\\WHITE8x8",
                                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                                        edgeSize = 1
                                    })
                                    backdropFrame:SetBackdropColor(0.08, 0.08, 0.1, 0.4)
                                    backdropFrame:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.5)
                                end
                                
                                if MCLcore.Function and MCLcore.Function.LinkMountItem then
                                    MCLcore.Function:LinkMountItem(mountId, mountFrame, false, false)
                                end
                            end
                        end
                    end)
                    
                    if not success then
                        print("MCL Error creating mount frame for ID " .. tostring(mountId) .. ": " .. tostring(error))
                    end
                end
            end
            end -- Close the shouldProcess if block

                if debugCategory and (not shouldProcess) then
                    print(string.format(
                        "MCL DEBUG: skip mountId=%s (reason=%s)",
                        tostring(mountId),
                        tostring(skipReason or "filtered")
                    ))
                end
            
            index = index + 1
            processed = processed + 1
            processedCount = processedCount + 1
        end
        
        -- Safety check for runaway processing
        if processedCount >= maxMounts then
            print("MCL Warning: Reached maximum mount processing limit (" .. maxMounts .. "), stopping to prevent performance issues")
            if callback then callback() end
            return
        end
        
        -- Continue with next batch if there are more mounts to process
        if index <= #mountList then
            C_Timer.After(batchDelay, processNextBatch)
        else
            -- All mounts processed, call completion callback
            if callback then callback() end
        end
    end
    
    processNextBatch()
end

-- Helper function to style navigation buttons for both themes
local function StyleNavButton(button, isExpansionIcon)
    if not button then return end
    
    if isExpansionIcon then
        -- Expansion icon buttons: subtle dark frame with 1px border
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        button:SetBackdropColor(0.1, 0.1, 0.14, 0.9)
        button:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.8)
    else
        -- Full-width nav buttons: matching header button style
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        button:SetBackdropColor(0.1, 0.1, 0.14, 0.9)
        button:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.6)
        
        if button.text then
            button.text:SetTextColor(0.7, 0.78, 0.88, 1)
        end
    end
end


local function ScrollFrame_OnMouseWheel(self, delta)
	local newValue = self:GetVerticalScroll() - (delta * 50);
	
	if (newValue < 0) then
		newValue = 0;
	elseif (newValue > self:GetVerticalScrollRange()) then
		newValue = self:GetVerticalScrollRange();
	end
	
	self:SetVerticalScroll(newValue);
end


function MCL_frames:openSettings()
	-- Ensure the MCL window is visible
	if MCLcore.MCL_MF and not MCLcore.MCL_MF:IsShown() then
		MCLcore.MCL_MF:Show()
	end
	-- Navigate to the in-addon Settings tab
	local navFrame = MCLcore.MCL_MF_Nav
	if navFrame and navFrame.tabs then
		for _, tab in ipairs(navFrame.tabs) do
			if tab.section and tab.section.name == "Settings" then
				-- Deselect all tabs
				for _, t in ipairs(navFrame.tabs) do
					if t.content then t.content:Hide() end
					if t.SetBackdropBorderColor then
						t:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.6)
						t:SetBackdropColor(0.1, 0.1, 0.14, 0.9)
						if t.text then t.text:SetTextColor(0.7, 0.78, 0.88, 1) end
					end
				end
				-- Select the Settings tab
				if tab.SetBackdropBorderColor then
					tab:SetBackdropBorderColor(0.3, 0.6, 0.9, 1)
					tab:SetBackdropColor(0.15, 0.18, 0.25, 1)
					if tab.text then tab.text:SetTextColor(0.5, 0.85, 1, 1) end
				end
				if MCL_mainFrame and MCL_mainFrame.ScrollFrame then
					MCL_mainFrame.ScrollFrame:SetScrollChild(MCL_mainFrame.ScrollChild)
					if tab.content then tab.content:Show() end
					MCL_mainFrame.ScrollFrame:SetVerticalScroll(0)
				end
				break
			end
		end
	end
end

function MCL_frames:CreateMainFrame()
    MCL_mainFrame = CreateFrame("Frame", "MCLFrame", UIParent, "MCLCleanFrameTemplate");
    MCL_mainFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    MCL_mainFrame:SetBackdropColor(0.10, 0.10, 0.18, MCL_SETTINGS.opacity)
    MCL_mainFrame:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.8)
    
    -- =====================================================
    -- TITLE BAR
    -- =====================================================
    local HEADER_HEIGHT = 30
    
    -- Header background bar
    MCL_mainFrame.headerBar = CreateFrame("Frame", nil, MCL_mainFrame)
    MCL_mainFrame.headerBar:SetPoint("TOPLEFT", MCL_mainFrame, "TOPLEFT", 0, 0)
    MCL_mainFrame.headerBar:SetPoint("TOPRIGHT", MCL_mainFrame, "TOPRIGHT", 0, 0)
    MCL_mainFrame.headerBar:SetHeight(HEADER_HEIGHT)
    MCL_mainFrame.headerBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    MCL_mainFrame.headerBar:SetBackdropColor(0.08, 0.08, 0.12, MCL_SETTINGS.opacity)
    MCL_mainFrame.headerBar:SetFrameLevel(MCL_mainFrame:GetFrameLevel() + 3)
    
    -- Accent line at bottom of header
    MCL_mainFrame.headerAccent = MCL_mainFrame.headerBar:CreateTexture(nil, "OVERLAY")
    MCL_mainFrame.headerAccent:SetHeight(1)
    MCL_mainFrame.headerAccent:SetPoint("BOTTOMLEFT", MCL_mainFrame.headerBar, "BOTTOMLEFT", 0, 0)
    MCL_mainFrame.headerAccent:SetPoint("BOTTOMRIGHT", MCL_mainFrame.headerBar, "BOTTOMRIGHT", 0, 0)
    MCL_mainFrame.headerAccent:SetColorTexture(0.2, 0.6, 0.9, 0.6)
    
    -- Make header bar draggable (inherits from parent)
    MCL_mainFrame.headerBar:EnableMouse(true)
    MCL_mainFrame.headerBar:RegisterForDrag("LeftButton")
    MCL_mainFrame.headerBar:SetScript("OnDragStart", function() MCL_mainFrame:StartMoving() end)
    MCL_mainFrame.headerBar:SetScript("OnDragStop", function() MCL_mainFrame:StopMovingOrSizing() end)
    
    -- Title text
    MCL_mainFrame.title = MCL_mainFrame.headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    MCL_mainFrame.title:SetPoint("LEFT", MCL_mainFrame.headerBar, "LEFT", 10, 0)
    MCL_mainFrame.title:SetText(L["Mount Collection Log"])
    MCL_mainFrame.title:SetTextColor(0.4, 0.78, 0.95, 1)
    
    -- Helper: consistent title bar button styling
    local TBAR_BTN_HEIGHT = 18
    local TBAR_BTN_PADDING = 5
    
    local function CreateHeaderButton(parent, width, labelText, tooltipTitle, tooltipBody, onClick)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(width, TBAR_BTN_HEIGHT)
        
        -- Safely set backdrop with error handling for MoP Classic compatibility
        if btn.SetBackdrop then
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            btn:SetBackdropColor(0.12, 0.12, 0.16, 0.9)
            btn:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.8)
        end
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("CENTER", 0, 0)
        btn.text:SetText(labelText)
        btn.text:SetTextColor(0.65, 0.75, 0.85, 1)
        
        btn:SetScript("OnEnter", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(0.18, 0.22, 0.3, 1)
                self:SetBackdropBorderColor(0.3, 0.6, 0.9, 1)
            end
            self.text:SetTextColor(0.5, 0.85, 1, 1)
            if tooltipTitle then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:SetText(tooltipTitle, 1, 1, 1)
                if tooltipBody then
                    GameTooltip:AddLine(tooltipBody, 0.7, 0.7, 0.7, true)
                end
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(0.12, 0.12, 0.16, 0.9)
                self:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.8)
            end
            self.text:SetTextColor(0.65, 0.75, 0.85, 1)
            GameTooltip:Hide()
        end)
        btn:SetScript("OnClick", onClick)
        
        return btn
    end
    
    -- Close button (X) - rightmost
    MCL_mainFrame.customClose = CreateHeaderButton(
        MCL_mainFrame.headerBar, 22, "X",
        nil, nil,
        function() MCL_mainFrame:Hide() end
    )
    MCL_mainFrame.customClose:SetPoint("RIGHT", MCL_mainFrame.headerBar, "RIGHT", -TBAR_BTN_PADDING, 0)
    -- Make close button red on hover
    MCL_mainFrame.customClose:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(0.6, 0.1, 0.1, 1)
            self:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
        end
        self.text:SetTextColor(1, 1, 1, 1)
    end)
    MCL_mainFrame.customClose:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(0.12, 0.12, 0.16, 0.9)
            self:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.8)
        end
        self.text:SetTextColor(0.65, 0.75, 0.85, 1)
    end)
    
    -- Refresh button
    MCL_mainFrame.refresh = CreateHeaderButton(
        MCL_mainFrame.headerBar, 22, "",
        L["Refresh Layout"], L["Refreshes the mount collection display"],
        function()
            if MCL_frames and MCL_frames.RefreshLayout then
                MCL_frames:RefreshLayout()
            end
        end
    )
    MCL_mainFrame.refresh:SetPoint("RIGHT", MCL_mainFrame.customClose, "LEFT", -3, 0)
    -- Use refresh icon instead of text
    MCL_mainFrame.refresh.text:Hide()
    MCL_mainFrame.refresh.icon = MCL_mainFrame.refresh:CreateTexture(nil, "OVERLAY")
    MCL_mainFrame.refresh.icon:SetSize(12, 12)
    MCL_mainFrame.refresh.icon:SetPoint("CENTER", 0, 0)
    MCL_mainFrame.refresh.icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    MCL_mainFrame.refresh.icon:SetVertexColor(0.65, 0.75, 0.85, 1)
    -- Override hover to also tint the icon
    MCL_mainFrame.refresh:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(0.18, 0.22, 0.3, 1)
            self:SetBackdropBorderColor(0.3, 0.6, 0.9, 1)
        end
        self.icon:SetVertexColor(0.5, 0.85, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["Refresh Layout"], 1, 1, 1)
        GameTooltip:AddLine(L["Refreshes the mount collection display"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    MCL_mainFrame.refresh:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(0.12, 0.12, 0.16, 0.9)
            self:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.8)
        end
        self.icon:SetVertexColor(0.65, 0.75, 0.85, 1)
        GameTooltip:Hide()
    end)
    
    -- SA button
    MCL_mainFrame.sa = CreateHeaderButton(
        MCL_mainFrame.headerBar, 30, "SA",
        L["Simple Armory"],
        L["Copy your Simple Armory profile link"],
        function()
            if MCLcore.Function and MCLcore.Function.simplearmoryLink then
                MCLcore.Function:simplearmoryLink()
            end
        end
    )
    MCL_mainFrame.sa:SetPoint("RIGHT", MCL_mainFrame.refresh, "LEFT", -3, 0)
    
    -- DFA button
    MCL_mainFrame.dfa = CreateHeaderButton(
        MCL_mainFrame.headerBar, 30, "DFA",
        L["Data for Azeroth"],
        L["Copy your Data for Azeroth profile link"],
        function()
            if MCLcore.Function and MCLcore.Function.dfaLink then
                MCLcore.Function:dfaLink()
            end
        end
    )
    MCL_mainFrame.dfa:SetPoint("RIGHT", MCL_mainFrame.sa, "LEFT", -3, 0)

    -- Report button (bug icon)
    MCL_mainFrame.report = CreateHeaderButton(
        MCL_mainFrame.headerBar, 22, "",
        L["Report Issue"],
        L["Report a missing or incorrect mount"],
        function()
            if MCLcore.Function and MCLcore.Function.reportLink then
                MCLcore.Function:reportLink()
            end
        end
    )
    MCL_mainFrame.report:SetPoint("RIGHT", MCL_mainFrame.dfa, "LEFT", -3, 0)
    -- Use bug icon instead of text
    MCL_mainFrame.report.text:Hide()
    MCL_mainFrame.report.icon = MCL_mainFrame.report:CreateTexture(nil, "OVERLAY")
    MCL_mainFrame.report.icon:SetSize(12, 12)
    MCL_mainFrame.report.icon:SetPoint("CENTER", 0, 0)
    MCL_mainFrame.report.icon:SetTexture("Interface\\HELPFRAME\\HelpIcon-Bug")
    MCL_mainFrame.report.icon:SetVertexColor(0.9, 0.4, 0.4, 1)
    -- Override hover to also tint the icon
    MCL_mainFrame.report:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(0.18, 0.22, 0.3, 1)
            self:SetBackdropBorderColor(0.9, 0.3, 0.3, 1)
        end
        self.icon:SetVertexColor(1, 0.5, 0.5, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["Report Issue"], 1, 1, 1)
        GameTooltip:AddLine(L["Report a missing or incorrect mount"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    MCL_mainFrame.report:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(0.12, 0.12, 0.16, 0.9)
            self:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.8)
        end
        self.icon:SetVertexColor(0.9, 0.4, 0.4, 1)
        GameTooltip:Hide()
    end)

    -- Compare button (group compare feature)
    MCL_mainFrame.compare = CreateHeaderButton(
        MCL_mainFrame.headerBar, 60, L["Compare"],
        L["Compare Collections"],
        L["Compare your mount collection with a party or raid member"],
        function()
            if MCLcore.Compare and MCLcore.Compare.ShowUserPicker then
                MCLcore.Compare:ShowUserPicker()
            end
        end
    )
    MCL_mainFrame.compare:SetPoint("RIGHT", MCL_mainFrame.report, "LEFT", -3, 0)


	--MCL Frame settings
	MCL_mainFrame:SetSize(main_frame_width, main_frame_height); -- width, height
	MCL_mainFrame:ClearAllPoints()
	MCL_mainFrame:SetPoint("CENTER", UIParent, "CENTER"); -- point, relativeFrame, relativePoint, xOffset, yOffset
	MCL_mainFrame:Show()
	MCL_mainFrame:SetHyperlinksEnabled(true)
	MCL_mainFrame:SetScript("OnHyperlinkClick", ChatFrame_OnHyperlinkShow)
	
	-- Restore saved frame size if available
	MCL_frames:RestoreFrameSize()

	MCL_mainFrame:SetMovable(true)
	MCL_mainFrame:EnableMouse(true)
	MCL_mainFrame:RegisterForDrag("LeftButton")
	MCL_mainFrame:SetScript("OnDragStart", MCL_mainFrame.StartMoving)
	MCL_mainFrame:SetScript("OnDragStop", MCL_mainFrame.StopMovingOrSizing)
	
	-- Make frame resizable
	MCL_mainFrame:SetResizable(true)
	MCL_mainFrame:SetResizeBounds(900, 600, 1600, 1000)  -- min width, min height, max width, max height
	
	-- Create resize grip
	MCL_mainFrame.resizeGrip = CreateFrame("Button", nil, MCL_mainFrame)
	MCL_mainFrame.resizeGrip:SetSize(16, 16)
	MCL_mainFrame.resizeGrip:SetPoint("BOTTOMRIGHT", MCL_mainFrame, "BOTTOMRIGHT", -2, 2)
	MCL_mainFrame.resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	MCL_mainFrame.resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	MCL_mainFrame.resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	MCL_mainFrame.resizeGrip:SetScript("OnMouseDown", function(self)
		MCL_mainFrame:StartSizing("BOTTOMRIGHT")
	end)
	MCL_mainFrame.resizeGrip:SetScript("OnMouseUp", function(self)
		MCL_mainFrame:StopMovingOrSizing()
		-- Save the new size and trigger layout update after resize
		MCL_frames:SaveFrameSize()
		MCL_frames:RefreshLayout()
	end)    
    
    -- Scroll Frame for Main Window
	MCL_mainFrame.ScrollFrame = CreateFrame("ScrollFrame", nil, MCL_mainFrame, "MinimalScrollFrameTemplate");
	-- Anchor scroll frame to the main frame, not Bg
    MCL_mainFrame.ScrollFrame:ClearAllPoints()
    MCL_mainFrame.ScrollFrame:SetPoint("TOPLEFT", MCL_mainFrame, "TOPLEFT", 10, -40)
    MCL_mainFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", MCL_mainFrame, "BOTTOMRIGHT", -10, 10)
	MCL_mainFrame.ScrollFrame:SetClipsChildren(true);
	MCL_mainFrame.ScrollFrame:SetScript("OnMouseWheel", ScrollFrame_OnMouseWheel);
	MCL_mainFrame.ScrollFrame:EnableMouse(true)
    
	-- Slim scrollbar positioned outside the scroll frame viewport
	MCL_mainFrame.ScrollFrame.ScrollBar:ClearAllPoints();
	MCL_mainFrame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", MCL_mainFrame.ScrollFrame, "TOPRIGHT", 2, -2);
	MCL_mainFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", MCL_mainFrame.ScrollFrame, "BOTTOMRIGHT", 6, 2);
	MCL_mainFrame.ScrollFrame.ScrollBar:SetWidth(4)

	-- Style the scrollbar thumb to be a slim house-style bar
	local scrollThumb = MCL_mainFrame.ScrollFrame.ScrollBar:GetThumbTexture()
	if scrollThumb then
		scrollThumb:SetColorTexture(0.25, 0.3, 0.4, 0.7)
		scrollThumb:SetWidth(4)
		scrollThumb:SetHeight(40)
	end
	-- Hide the up/down scroll buttons for a clean look
	local scrollUp = MCL_mainFrame.ScrollFrame.ScrollBar.ScrollUpButton or MCL_mainFrame.ScrollFrame.ScrollBar.Back
	local scrollDown = MCL_mainFrame.ScrollFrame.ScrollBar.ScrollDownButton or MCL_mainFrame.ScrollFrame.ScrollBar.Forward
	if scrollUp then scrollUp:SetAlpha(0); scrollUp:SetSize(1,1) end
	if scrollDown then scrollDown:SetAlpha(0); scrollDown:SetSize(1,1) end

    -- Create and assign a dedicated scroll child frame
    if not MCL_mainFrame.ScrollChild then
        local actualWidth, actualHeight = MCL_frames:GetCurrentFrameDimensions()
        MCL_mainFrame.ScrollChild = CreateFrame("Frame", nil, MCL_mainFrame.ScrollFrame)
        MCL_mainFrame.ScrollChild:SetSize(actualWidth - 20, actualHeight)
        MCL_mainFrame.ScrollFrame:SetScrollChild(MCL_mainFrame.ScrollChild)
    end

	MCL_mainFrame:SetFrameStrata("HIGH")

    tinsert(UISpecialFrames, "MCLFrame")
    
    -- Add OnShow handler to show navigation when main frame is shown
    MCL_mainFrame:SetScript("OnShow", function()
        if MCLcore.MCL_MF_Nav then
            MCLcore.MCL_MF_Nav:Show()
        end
    end)
    
    -- Add OnHide handler to hide navigation when main frame is closed
    MCL_mainFrame:SetScript("OnHide", function()
        if MCLcore.MCL_MF_Nav then
            MCLcore.MCL_MF_Nav:Hide()
        end
        -- Hide search dropdown when main frame closes
        if MCLcore.Search and MCLcore.Search.HideSearchDropdown then
            MCLcore.Search:HideSearchDropdown()
        end
        -- Hide mount card when main frame closes
        if MCL_MountCard and MCL_MountCard:IsShown() then
            MCL_MountCard:Hide()
        end
    end)
    
    return MCL_mainFrame
end


local function Tab_OnClick(self)
	-- Check if we need to refresh layout when switching away from pinned section
	if MCLcore.Function and MCLcore.Function.CheckAndRefreshAfterPinnedChanges then
		local newSectionName = self.section and self.section.name or "Unknown"
		MCLcore.Function:CheckAndRefreshAfterPinnedChanges(newSectionName)
	end
	
	PanelTemplates_SetTab(self:GetParent(), self:GetID());

	local scrollChild = MCL_mainFrame.ScrollFrame:GetScrollChild();
	if(scrollChild) then
		scrollChild:Hide();
	end

	MCL_mainFrame.ScrollFrame:SetScrollChild(self.content);
	self.content:Show();
	MCL_mainFrame.ScrollFrame:SetVerticalScroll(0);
end
