
--LOCALIZED CONSTANTS
EJ_MIN_CHARACTER_SEARCH = 3;


--FILE CONSTANTS
local HEADER_INDENT = 15;
local MAX_CREATURES_PER_ENCOUNTER = 6;

local SECTION_BUTTON_OFFSET = 6;
local SECTION_DESCRIPTION_OFFSET = 27;


local EJ_STYPE_ITEM = 0;
local EJ_STYPE_ENCOUNTER = 1;
local EJ_STYPE_CREATURE = 2;
local EJ_STYPE_SECTION = 3;
local EJ_STYPE_INSTANCE = 4;


local EJ_NUM_INSTANCE_PER_ROW = 4;

local EJ_QUEST_POI_MINDIS_SQR = 2500;

local EJ_LORE_MAX_HEIGHT = 97;
local EJ_MAX_SECTION_MOVE = 320;


local EJ_Tabs = {};
EJ_Tabs[1] = {frame="detailsScroll", button="bossTab"};
EJ_Tabs[2] = {frame="lootScroll", button="lootTab"};


local EJ_section_openTable = {};


local EJ_LINK_INSTANCE 		= 0;
local EJ_LINK_ENCOUNTER		= 1;
local EJ_LINK_SECTION 		= 3;



function EncounterJournal_OnLoad(self)
	EncounterJournalTitleText:SetText(ENCOUNTER_JOURNAL);
	SetPortraitToTexture(EncounterJournalPortrait,"Interface\\EncounterJournal\\UI-EJ-PortraitIcon");
	self:RegisterEvent("EJ_LOOT_DATA_RECIEVED");
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE");
	self:RegisterEvent("EJ_DIFFICULTY_UPDATE");
	
	self.encounter.freeHeaders = {};
	self.encounter.usedHeaders = {};
	
	self.encounter.infoFrame = self.encounter.info.detailsScroll.child;
	self.encounter.info.detailsScroll.ScrollBar.scrollStep = 30;
	
	
	-- UIDropDownMenu_SetWidth(self.instanceSelect.tierDropDown, 170);
	-- UIDropDownMenu_SetText(self.instanceSelect.tierDropDown, "Pick A Dungeon");
	-- UIDropDownMenu_JustifyText(self.instanceSelect.tierDropDown, "LEFT");
	-- UIDropDownMenu_Initialize(self.instanceSelect.tierDropDown, EncounterJournal_TierDropDown_Init);
	
	
	self.encounter.info.bossTab:Click();
	
	self.encounter.info.lootScroll.update = EncounterJournal_LootUpdate;
	self.encounter.info.lootScroll.scrollBar.doNotHide = true;
	HybridScrollFrame_CreateButtons(self.encounter.info.lootScroll, "EncounterItemTemplate", 0, 0);
	
	
	self.searchResults.scrollFrame.update = EncounterJournal_SearchUpdate;
	self.searchResults.scrollFrame.scrollBar.doNotHide = true;
	HybridScrollFrame_CreateButtons(self.searchResults.scrollFrame, "EncounterSearchLGTemplate", 0, 0);
	
	EncounterJournal.isHeroic = false;
	EncounterJournal.is10Man = true;
	EJ_SetDifficulty(EncounterJournal.isHeroic, EncounterJournal.is10Man);
	
	EncounterJournal.searchBox.oldEditLost = EncounterJournal.searchBox:GetScript("OnEditFocusLost");
	EncounterJournal.searchBox:SetScript("OnEditFocusLost", function(self) self:oldEditLost(); EncounterJournal_HideSearchPreview(); end);
	EncounterJournal.searchBox.clearFunc = EncounterJournal_ClearSearch;
	
	
	local homeData = {
		name = HOME,
		OnClick = EncounterJournal_ListInstances,
		listFunc = EJNAV_ListInstance,
	}
	NavBar_Initialize(self.navBar, "NavButtonTemplate", homeData, self.navBar.home, self.navBar.overflow);
	EncounterJournal_ListInstances();
	
	EncounterJournal.instanceSelect.dungeonsTab:Disable();
	EncounterJournal.instanceSelect.dungeonsTab.selectedGlow:Show();
	EncounterJournal.instanceSelect.raidsTab:GetFontString():SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
end


function EncounterJournal_OnShow(self)
	UpdateMicroButtons();
	PlaySound("igCharacterInfoOpen");
	
	--automatically navigate to the current dungeon if you are in one;
	local instanceID = EJ_GetCurrentInstance();
	if instanceID ~= 0 then
		EncounterJournal_ListInstances();
		EncounterJournal_DisplayInstance(instanceID);
	end
end


function EncounterJournal_OnHide(self)
	UpdateMicroButtons();
	PlaySound("igCharacterInfoClose");
end


function EncounterJournal_OnEvent(self, event, ...)
	if  event == "EJ_LOOT_DATA_RECIEVED" then
		local itemID = ...
		if itemID then
			EncounterJournal_LootCallback(itemID);
			EncounterJournal_SearchUpdate();
		else
			EncounterJournal_LootUpdate();
		end
	elseif event == "EJ_DIFFICULTY_UPDATE" then
		--fix the difficulty buttons
		local isHeroic, is10man = ...;
		if is10man then
			EncounterJournal.is10Man = true;
			EncounterJournal.encounter.info.diff10man.selected:Show();
			EncounterJournal.encounter.info.diff25man.selected:Hide();
		else
			EncounterJournal.is10Man = false;
			EncounterJournal.encounter.info.diff10man.selected:Hide();
			EncounterJournal.encounter.info.diff25man.selected:Show();
		end
		
		EncounterJournal.isHeroic = isHeroic;
		if isHeroic then
			EncounterJournal.encounter.info.heroButton.selected:Show();
		else
			EncounterJournal.encounter.info.heroButton.selected:Hide();
		end
	elseif event == "UNIT_PORTRAIT_UPDATE" then
		local unit = ...;
		if not unit then
			EncounterJournal_UpdatePortraits();
		end
	end
end


function EncounterJournal_UpdatePortraits()
	if ( EncounterJournal:IsShown() ) then
		local self = EncounterJournal.encounter;
		for i = 1, MAX_CREATURES_PER_ENCOUNTER do
			local button = self["creatureButton"..i];
			if ( button and button:IsShown() ) then
				SetPortraitTexture(button.creature, button.displayInfo);
			else
				break;
			end
		end
		local usedHeaders = EncounterJournal.encounter.usedHeaders;
		for _, header in pairs(usedHeaders) do
			if ( header.button.portrait.displayInfo ) then
				SetPortraitTexture(header.button.portrait.icon, header.button.portrait.displayInfo);
			end
		end
	end
	if ( WorldMapFrame:IsShown() ) then
		local index = 1;
		local bossButton = _G["EJMapButton"..index];
		while ( bossButton and bossButton:IsShown() ) do
			SetPortraitTexture(bossButton.bgImage, bossButton.displayInfo);
			index = index + 1;
			bossButton = _G["EJMapButton"..index];
		end
	end
end


function EncounterJournal_ListInstances()
	NavBar_Reset(EncounterJournal.navBar);
	EncounterJournal.encounter:Hide();
	EncounterJournal.instanceSelect:Show();
	local showRaid = EncounterJournal.instanceSelect.raidsTab:IsEnabled() == nil;
	

	local self = EncounterJournal.instanceSelect.scroll.child;
	local index = 1;
	local instanceID, name, description, _, buttonImage, _, _, link = EJ_GetInstanceByIndex(index, showRaid);
	local instanceButton;
	while instanceID do
		instanceButton = self["instance"..index];
		if not instanceButton then -- create button
			instanceButton = CreateFrame("BUTTON", self:GetParent():GetName().."instance"..index, self, "EncounterInstanceButtonTemplate");
			if ( EncounterJournal.localizeInstanceButton ) then
				EncounterJournal.localizeInstanceButton(instanceButton);
			end
			self["instance"..index] = instanceButton;
			if mod(index-1, EJ_NUM_INSTANCE_PER_ROW) == 0 then
				instanceButton:SetPoint("TOP", self["instance"..(index-EJ_NUM_INSTANCE_PER_ROW)], "BOTTOM", 0, -15);
			else
				instanceButton:SetPoint("LEFT", self["instance"..(index-1)], "RIGHT", 15, 0);
			end
		end
	
		instanceButton.name:SetText(name);
		instanceButton.bgImage:SetTexture(buttonImage);
		instanceButton.instanceID = instanceID;
		instanceButton.tooltipTitle = name;
		instanceButton.tooltipText = description;
		instanceButton.link = link;
		instanceButton:Show();
		
		index = index + 1;
		instanceID, name, description, _, buttonImage, _, _, link = EJ_GetInstanceByIndex(index, showRaid);
	end

	--Hide old buttons needed.
	instanceButton = self["instance"..index];
	while instanceButton do
		instanceButton:Hide();
		index = index + 1;
		instanceButton = self["instance"..index];
	end
end


function EncounterJournal_DisplayInstance(instanceID, noButton)
	local self = EncounterJournal.encounter;
	EncounterJournal.encounter.model:Hide();
	EncounterJournal.instanceSelect:Hide();
	EncounterJournal.encounter:Show();
	EncounterJournal.ceatureDisplayID = 0;

	EncounterJournal.instanceID = instanceID;
	EncounterJournal.encounterID = nil;
	EJ_SelectInstance(instanceID);
	EncounterJournal_LootUpdate();
	EncounterJournal_ClearDetails()
	
	if EJ_InstanceIsRaid() then
		self.info.diff10man:Show();
		self.info.diff25man:Show();
	else
		self.info.diff10man:Hide();
		self.info.diff25man:Hide();
	end
	
	local iname, description, bgImage, _, loreImage = EJ_GetInstanceInfo();
	self.instance.title:SetText(iname);
	self.instance.loreBG:SetTexture(loreImage);
	self.info.encounterTitle:SetText(iname);
	
	self.instance.loreScroll.child.lore:SetText(description);
	local loreHeight = self.instance.loreScroll.child.lore:GetHeight();
	self.instance.loreScroll.ScrollBar:SetValue(0);
	if loreHeight <= EJ_LORE_MAX_HEIGHT then
		self.instance.loreScroll.ScrollBar:Hide();
	else
		self.instance.loreScroll.ScrollBar:Show();
	end
	
	self.info.dungeonBG:SetTexture(bgImage);
	self.info.dungeonBG:Hide();
	
	local bossIndex = 1;
	local name, description, bossID, _, link = EJ_GetEncounterInfoByIndex(bossIndex);
	local bossButton;
	while bossID do
		bossButton = _G["EncounterJournalBossButton"..bossIndex];
		if not bossButton then -- create a new header;
			bossButton = CreateFrame("BUTTON", "EncounterJournalBossButton"..bossIndex, EncounterJournal.encounter.infoFrame, "EncounterBossButtonTemplate");
			if bossIndex > 1 then
				bossButton:SetPoint("TOPLEFT", _G["EncounterJournalBossButton"..(bossIndex-1)], "BOTTOMLEFT", 0, -15);
			else
				bossButton:SetPoint("TOPLEFT", EncounterJournal.encounter.infoFrame, "TOPLEFT", 0, -10);
			end
		end
		
		bossButton.link = link;
		bossButton:SetText(name);
		bossButton:Show();
		bossButton.encounterID = bossID;
		--Use the boss' first creature as the button icon
		local _, _, _, _, bossImage = EJ_GetCreatureInfo(1, bossID);
		bossImage = bossImage or "Interface\\EncounterJournal\\UI-EJ-BOSS-Default";
		bossButton.creature:SetTexture(bossImage);
		
		bossIndex = bossIndex + 1;
		name, description, bossID, _, link = EJ_GetEncounterInfoByIndex(bossIndex);
	end
	
	--handle typeHeader
	
	self.instance:Show();
	
	if not noButton then
		local buttonData = {
			name = iname,
			OnClick = EJNAV_RefreshInstance,
			listFunc = EJNAV_ListEncounter
		}
		NavBar_AddButton(EncounterJournal.navBar, buttonData);
	end
end


function EncounterJournal_DisplayEncounter(encounterID, noButton)
	local self = EncounterJournal.encounter;
	EncounterJournal.encounter.model:Show();
	
	local ename, description, _, rootSectionID = EJ_GetEncounterInfo(encounterID);
	EncounterJournal.encounterID = encounterID;
	EJ_SelectEncounter(encounterID);
	EncounterJournal_LootUpdate();
	EncounterJournal_ClearDetails();
	
	self.info.encounterTitle:SetText(ename);
		
	self.infoFrame.description:SetText(description);
	self.infoFrame.description:SetWidth(self.infoFrame:GetWidth() -5);
	self.infoFrame.encounterID = encounterID;
	self.infoFrame.rootSectionID = rootSectionID;
	self.infoFrame.expanded = false;
	
	self.info.dungeonBG:Show();
	
	-- Setup Creatures
	local id, displayInfo, iconImage;
	for i=1,MAX_CREATURES_PER_ENCOUNTER do 
		id, name, description, displayInfo, iconImage = EJ_GetCreatureInfo(i);
		
		local button = self["creatureButton"..i];
		if id then
			SetPortraitTexture(button.creature, displayInfo);
			button.name = name;
			button.id = id;
			button.description = description;
			button.displayInfo = displayInfo;
			button:Show();
		end
		
		if i == 1 then
			EncounterJournal_DisplayCreature(button);
		end
	end
	
	EncounterJournal_ToggleHeaders(self.infoFrame)
	self:Show();
	
	if not noButton then
		local buttonData = {
			name = ename,
			OnClick = EJNAV_RefreshEncounter,
		}
		NavBar_AddButton(EncounterJournal.navBar, buttonData);
	end
end


function EncounterJournal_DisplayCreature(self)
	if EncounterJournal.encounter.shownCreatureButton then
		EncounterJournal.encounter.shownCreatureButton:Enable();
	end
	
	if EncounterJournal.ceatureDisplayID == self.displayInfo then
		--Don't refresh the same model
	elseif self.displayInfo then
		EncounterJournal.encounter.model.imageTitle:SetText(self.name);
		EncounterJournal.encounter.model:SetDisplayInfo(self.displayInfo);
		EncounterJournal.ceatureDisplayID = self.displayInfo;
	end
	
	self:Disable();
	EncounterJournal.encounter.shownCreatureButton = self;
end


local toggleTempList = {};
local headerCount = 0;
function EncounterJournal_ToggleHeaders(self, doNotShift)
	local numAdded = 0
	local infoHeader, parentID, _;
	local hWidth = self:GetWidth();
	local nextSectionID;
	local topLevelSection = false;
	if self.myID then  -- this is from a button click
		_, _, _, _, _, _, nextSectionID =  EJ_GetSectionInfo(self.myID)
		parentID = self.myID;
		self.description:SetWidth(self:GetWidth() -20);
		hWidth = hWidth - HEADER_INDENT;
	else
		--This sets the base encounter header
		parentID = self.encounterID;
		nextSectionID = self.rootSectionID;
		topLevelSection = true;
	end
	
	
	local freeHeaders = EncounterJournal.encounter.freeHeaders;
	local usedHeaders = EncounterJournal.encounter.usedHeaders;
	
	self.expanded = not self.expanded;
	local hideHeaders = not self.expanded;
	if hideHeaders then
		-- This can only happen for buttons
		self.button.expandedIcon:SetText("+");
		self.description:Hide();
		self.descriptionBG:Hide();
		self.descriptionBGBottom:Hide();
		
		EncounterJournal_ClearChildHeaders(self);
	else
		if strlen(self.description:GetText() or "") > 0 then
			self.description:Show();
			if self.button then
				self.descriptionBG:Show();
				self.descriptionBGBottom:Show();
				self.button.expandedIcon:SetText("-");
			end
		elseif self.button then
			self.description:Hide();
			self.descriptionBG:Hide();
			self.descriptionBGBottom:Hide();
			self.button.expandedIcon:SetText("-");
		end
	
		-- Get Section Info
		local listEnd  = #usedHeaders;
		while nextSectionID do
			local title, description, headerType, abilityIcon, displayInfo, siblingID, _, fileredByDifficulty, link, startsOpen, flag1, flag2, flag3, flag4 = EJ_GetSectionInfo(nextSectionID);
			if not title then
				break;
			elseif not fileredByDifficulty then --ignore all sections that should not be shown with our current difficulty settings		
				if #freeHeaders == 0 then -- create a new header;
					headerCount = headerCount + 1; -- the is a file local
					infoHeader = CreateFrame("FRAME", "EncounterJournalInfoHeader"..headerCount, EncounterJournal.encounter.infoFrame, "EncounterInfoTemplate");
					infoHeader:Hide();
				else
					infoHeader = freeHeaders[#freeHeaders];
					freeHeaders[#freeHeaders] = nil;
				end
				
				numAdded = numAdded + 1;
				toggleTempList[#toggleTempList+1] = infoHeader;
				
				infoHeader.button.link = link;
				infoHeader.parentID = parentID;
				infoHeader.myID = nextSectionID;
				infoHeader.description:SetText(description);
				infoHeader.button.title:SetText(title);
				if topLevelSection then
					infoHeader.button.title:SetFontObject("GameFontNormalMed3");
				else
					infoHeader.button.title:SetFontObject("GameFontNormal");
				end
				
				--All headers start collapsed
				infoHeader.expanded = false
				infoHeader.description:Hide();
				infoHeader.descriptionBG:Hide();
				infoHeader.descriptionBGBottom:Hide();
				infoHeader.button.expandedIcon:SetText("+");
				
				
				local textLeftAnchor = infoHeader.button.expandedIcon;
				--Show ability Icon
				if abilityIcon ~= "" then
					infoHeader.button.abilityIcon:SetTexture(abilityIcon);
					infoHeader.button.abilityIcon:Show();
					textLeftAnchor = infoHeader.button.abilityIcon;
				else
					infoHeader.button.abilityIcon:Hide();
				end
				
				--Show Creature Portrait
				if displayInfo ~= 0 then
					SetPortraitTexture(infoHeader.button.portrait.icon, displayInfo);
					infoHeader.button.portrait.name = title;
					infoHeader.button.portrait.displayInfo = displayInfo;
					infoHeader.button.portrait:Show();
					textLeftAnchor = infoHeader.button.portrait;
					infoHeader.button.abilityIcon:Hide();
				else
					infoHeader.button.portrait:Hide();
					infoHeader.button.portrait.name = nil;
					infoHeader.button.portrait.displayInfo = nil;
				end
				infoHeader.button.title:SetPoint("LEFT", textLeftAnchor, "RIGHT", 5, 0);
				
				
				--Set flag Icons
				local textRightAnchor = nil;
				infoHeader.button.icon1:Hide();
				infoHeader.button.icon2:Hide();
				infoHeader.button.icon3:Hide();
				infoHeader.button.icon4:Hide();
				if flag1 then
					textRightAnchor = infoHeader.button.icon1;
					infoHeader.button.icon1:Show();
					infoHeader.button.icon1.tooltipTitle = _G["ENCOUNTER_JOURNAL_SECTION_FLAG"..flag1];
					infoHeader.button.icon1.tooltipText = _G["ENCOUNTER_JOURNAL_SECTION_FLAG_DESCRIPTION"..flag1];
					EncounterJournal_SetFlagIcon(infoHeader.button.icon1.icon, flag1);
					if flag2 then
						textRightAnchor = infoHeader.button.icon2;
						infoHeader.button.icon2:Show();
						EncounterJournal_SetFlagIcon(infoHeader.button.icon2.icon, flag2);
						infoHeader.button.icon2.tooltipTitle = _G["ENCOUNTER_JOURNAL_SECTION_FLAG"..flag2];
						infoHeader.button.icon2.tooltipText = _G["ENCOUNTER_JOURNAL_SECTION_FLAG_DESCRIPTION"..flag2];
						if flag3 then
							textRightAnchor = infoHeader.button.icon3;
							infoHeader.button.icon3:Show();
							EncounterJournal_SetFlagIcon(infoHeader.button.icon3.icon, flag3);
							infoHeader.button.icon3.tooltipTitle = _G["ENCOUNTER_JOURNAL_SECTION_FLAG"..flag3];
							infoHeader.button.icon3.tooltipText = _G["ENCOUNTER_JOURNAL_SECTION_FLAG_DESCRIPTION"..flag3];
							if flag4 then
								textRightAnchor = infoHeader.button.icon4;
								infoHeader.button.icon4:Show();
								EncounterJournal_SetFlagIcon(infoHeader.button.icon4.icon, flag4);
								infoHeader.button.icon4.tooltipTitle = _G["ENCOUNTER_JOURNAL_SECTION_FLAG"..flag4];
								infoHeader.button.icon4.tooltipText = _G["ENCOUNTER_JOURNAL_SECTION_FLAG_DESCRIPTION"..flag4];
							end
						end
					end
				end
				if textRightAnchor then
					infoHeader.button.title:SetPoint("RIGHT", textRightAnchor, "LEFT", -5, 0);
				else
					infoHeader.button.title:SetPoint("RIGHT", infoHeader.button, "RIGHT", -5, 0);
				end
				
				infoHeader.index = nil;
				infoHeader:SetWidth(hWidth);
				
				
				-- If this section has not be seen and should start open
				if EJ_section_openTable[infoHeader.myID] == nil and startsOpen then
					EJ_section_openTable[infoHeader.myID] = true;
				end
				
				--toggleNested?
				if EJ_section_openTable[infoHeader.myID]  then
					infoHeader.expanded = false; -- setting false to expand it in EncounterJournal_ToggleHeaders
					numAdded = numAdded + EncounterJournal_ToggleHeaders(infoHeader, true);
				end
				
				infoHeader:Show();
			end -- if not fileredByDifficulty
			nextSectionID = siblingID;
		end
		
		if not doNotShift and numAdded > 0 then
			--fix the usedlist
			local startIndex = self.index or 0;
			for i=listEnd,startIndex+1,-1 do
				usedHeaders[i+numAdded] = usedHeaders[i];
				usedHeaders[i+numAdded].index = i + numAdded;
				usedHeaders[i] = nil
			end
			for i=1,numAdded do
				usedHeaders[startIndex + i] = toggleTempList[i];
				usedHeaders[startIndex + i].index = startIndex + i;
				toggleTempList[i] = nil;
			end
		end
		
		if topLevelSection and usedHeaders[1] then
			usedHeaders[1]:SetPoint("TOPRIGHT", 0 , -8 - self.description:GetHeight() - SECTION_BUTTON_OFFSET);
		end
	end
	
	if self.myID then
		EJ_section_openTable[self.myID] = self.expanded;
	end
	
	if not doNotShift then
		EncounterJournal_ShiftHeaders(self.index or 1);
		
		--check to see if it is offscreen
		if self.index then
			local scrollValue = EncounterJournal.encounter.info.detailsScroll.ScrollBar:GetValue();
			local cutoff = EncounterJournal.encounter.info.detailsScroll:GetHeight() + scrollValue;
			
			local _, _, _, _, anchorY = self:GetPoint();
			anchorY = anchorY - self:GetHeight();
			if self.description:IsShown() then
				anchorY = anchorY - self.description:GetHeight() - SECTION_DESCRIPTION_OFFSET;
			end
			
			if cutoff < abs(anchorY) then
				self.frameCount = 0;
				self:SetScript("OnUpdate", EncounterJournal_MoveSectionUpdate);
			end
		end
	end
	return numAdded;
end


function EncounterJournal_ShiftHeaders(index)
	local usedHeaders = EncounterJournal.encounter.usedHeaders;
	if not usedHeaders[index] then
		return;
	end
	
	local _, _, _, _, anchorY = usedHeaders[index]:GetPoint();
	for i=index,#usedHeaders-1 do
		anchorY = anchorY - usedHeaders[i]:GetHeight();
		if usedHeaders[i].description:IsShown() then
			anchorY = anchorY - usedHeaders[i].description:GetHeight() - SECTION_DESCRIPTION_OFFSET;
		else
			anchorY = anchorY - SECTION_BUTTON_OFFSET;
		end
		
		usedHeaders[i+1]:SetPoint("TOPRIGHT", 0 , anchorY);
	end
end


function EncounterJournal_FocusSection(sectionID)
	local usedHeaders = EncounterJournal.encounter.usedHeaders;
	for _, section in pairs(usedHeaders) do
		if section.myID == sectionID then
			section.cbCount = 0;
			section.flashAnim:Play();
			section:SetScript("OnUpdate", EncounterJournal_FocusSectionCallback);
			return;
		end
	end
end


function EncounterJournal_FocusSectionCallback(self)
	if self.cbCount > 0 then
		local _, _, _, _, anchorY = self:GetPoint();
		anchorY = abs(anchorY);
		anchorY = anchorY - EncounterJournal.encounter.info.detailsScroll:GetHeight()/2;
		EncounterJournal.encounter.info.detailsScroll.ScrollBar:SetValue(anchorY);
		self:SetScript("OnUpdate", nil);
	end
	self.cbCount = self.cbCount + 1;
end


function EncounterJournal_MoveSectionUpdate(self)
	
	if self.frameCount > 0 then
		local _, _, _, _, anchorY = self:GetPoint();
		local height = min(EJ_MAX_SECTION_MOVE, self:GetHeight() + self.description:GetHeight() + SECTION_DESCRIPTION_OFFSET);
		local scrollValue = abs(anchorY) - (EncounterJournal.encounter.info.detailsScroll:GetHeight()-height);
		EncounterJournal.encounter.info.detailsScroll.ScrollBar:SetValue(scrollValue);
		self:SetScript("OnUpdate", nil);
	end
	self.frameCount = self.frameCount + 1;
end


function EncounterJournal_ClearChildHeaders(self, doNotShift)
	local usedHeaders = EncounterJournal.encounter.usedHeaders;
	local freeHeaders = EncounterJournal.encounter.freeHeaders;
	local numCleared = 0
	for key,header in pairs(usedHeaders) do
		if header.parentID == self.myID then
			if header.expanded then
				numCleared = numCleared + EncounterJournal_ClearChildHeaders(header, true)
			end
			header:Hide();
			usedHeaders[key] = nil;
			freeHeaders[#freeHeaders+1] = header;
			numCleared = numCleared + 1;
		end
	end
	
	if numCleared > 0 and not doNotShift then
		local placeIndex = self.index + 1;
		local shiftHeader = usedHeaders[placeIndex + numCleared];
		while shiftHeader do
			usedHeaders[placeIndex] = shiftHeader;
			usedHeaders[placeIndex].index = placeIndex;
			usedHeaders[placeIndex + numCleared] = nil;
			placeIndex = placeIndex + 1;
			shiftHeader = usedHeaders[placeIndex + numCleared];
		end
	end
	return numCleared
end


function EncounterJournal_ClearDetails()
	EncounterJournal.encounter.instance:Hide();
	EncounterJournal.encounter.infoFrame.description:SetText("");
	
	EncounterJournal.encounter.info.lootScroll.scrollBar:SetValue(0);
	EncounterJournal.encounter.info.detailsScroll.ScrollBar:SetValue(0);
	
	local freeHeaders = EncounterJournal.encounter.freeHeaders;
	local usedHeaders = EncounterJournal.encounter.usedHeaders;
	
	for key,used in pairs(usedHeaders) do
		used:Hide();
		usedHeaders[key] = nil;
		freeHeaders[#freeHeaders+1] = used;
	end
	
	for i=1,MAX_CREATURES_PER_ENCOUNTER do 
		EncounterJournal.encounter["creatureButton"..i]:Hide();
	end
	
	local bossIndex = 1
	local bossButton = _G["EncounterJournalBossButton"..bossIndex];
	while bossButton do
		bossButton:Hide();
		bossIndex = bossIndex + 1;
		bossButton = _G["EncounterJournalBossButton"..bossIndex];
	end
	
	EncounterJournal.searchResults:Hide();
	EncounterJournal_HideSearchPreview();
	EncounterJournal.searchBox:ClearFocus();
end


function EncounterJournal_TierDropDown_Select(self, instanceID, name)
	EncounterJournal_DisplayInstance(instanceID);
	UIDropDownMenu_SetText(EncounterJournal.instanceSelect.tierDropDown, name);
end


function EncounterJournal_TabClicked(self, button)
	local tabType = self:GetID();
	local info = EncounterJournal.encounter.info;
	info.tab = tabType;
	for key, data in pairs(EJ_Tabs) do 
		if key == tabType then
			info[data.frame]:Show();
			info[data.button]:Disable();
		else
			info[data.frame]:Hide();
			info[data.button]:Enable();
		end
	end
end


function EncounterJournal_LootCallback(itemID)
	local scrollFrame = EncounterJournal.encounter.info.lootScroll;
	
	for i,item in pairs(scrollFrame.buttons) do
		if item.itemID == itemID then
			local name, icon, slot, armorType, itemID = EJ_GetLootInfoByIndex(item.index);
			item.name:SetText(name);
			item.icon:SetTexture(icon);
			item.slot:SetText(slot);
			item.armorType:SetText(armorType);
		end
	end
end


function EncounterJournal_LootUpdate()
	local scrollFrame = EncounterJournal.encounter.info.lootScroll;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local items = scrollFrame.buttons;
	local item, index;
	
	local numLoot = EJ_GetNumLoot();
	local buttonSize = items[1]:GetHeight();
	
	for i = 1,#items do
		item = items[i];
		index = offset + i;
		if index <= numLoot then
			local name, icon, slot, armorType, itemID, link = EJ_GetLootInfoByIndex(index);
			item.name:SetText(name);
			item.icon:SetTexture(icon);
			item.slot:SetText(slot);
			item.armorType:SetText(armorType);
			item.itemID = itemID;
			item.index = index;
			item.link = link;
			item:Show();
			
			if item.showingTooltip then
				GameTooltip:SetItemByID(itemID);
			end
		else
			item:Hide();
		end
	end
	
	local totalHeight = numLoot * buttonSize;
	HybridScrollFrame_Update(scrollFrame, totalHeight, scrollFrame:GetHeight());
end


function EncounterJournal_Loot_OnUpdate(self)
	if GameTooltip:IsOwned(self) then
		if IsModifiedClick("COMPAREITEMS") or
				 (GetCVarBool("alwaysCompareItems") and not self:IsEquippedItem()) then
			GameTooltip_ShowCompareItem();
		else
			ShoppingTooltip1:Hide();
			ShoppingTooltip2:Hide();
			ShoppingTooltip3:Hide();
		end

		if IsModifiedClick("DRESSUP") then
			ShowInspectCursor();
		else
			ResetCursor();
		end
	end
end


function EncounterJournal_SetFlagIcon(texture, index)
	local iconSize = 32;
	local columns = 256/iconSize;
	local rows = 64/iconSize;

	l = mod(index, columns) / columns;
	r = l + (1/columns);
	t = floor(index/columns) / rows;
	b = t + (1/rows);
	texture:SetTexCoord(l,r,t,b);
end


function EncounterJournal_Refresh(self)
	EJ_SetDifficulty(EncounterJournal.isHeroic, EncounterJournal.is10Man);
	EncounterJournal_LootUpdate();
	
	if EncounterJournal.encounterID then
		EncounterJournal_DisplayEncounter(EncounterJournal.encounterID, true)
	elseif EncounterJournal.instanceID then
		EncounterJournal_DisplayInstance(EncounterJournal.instanceID, true);
	end
end


function EncounterJournal_GetSearchDisplay(index)
	local name, icon, path, typeText, displayInfo, itemID, _;
	local id, stype, _, instanceID, encounterID  = EJ_GetSearchResult(index);
	if stype == EJ_STYPE_INSTANCE then
		name, _, _, icon = EJ_GetInstanceInfo(id);
		typeText = ENCOUNTER_JOURNAL_INSTANCE;
	elseif stype == EJ_STYPE_ENCOUNTER then
		name = EJ_GetEncounterInfo(id);
		typeText = ENCOUNTER_JOURNAL_ENCOUNTER;
		path = EJ_GetInstanceInfo(instanceID);
		_, _, _, displayInfo = EJ_GetCreatureInfo(1, encounterID, instanceID);
	elseif stype == EJ_STYPE_SECTION then
		name, _, _, icon, displayInfo = EJ_GetSectionInfo(id)
		if displayInfo and displayInfo > 0 then
			typeText = ENCOUNTER_JOURNAL_ENCOUNTER_ADD;
		else
			typeText = ENCOUNTER_JOURNAL_ABILITY;
		end
		path = EJ_GetInstanceInfo(instanceID).." | "..EJ_GetEncounterInfo(encounterID);
	elseif stype == EJ_STYPE_ITEM then
		name, icon, _, _, itemID = EJ_GetLootInfo(id)
		typeText = ENCOUNTER_JOURNAL_ITEM;
		path = EJ_GetInstanceInfo(instanceID).." | "..EJ_GetEncounterInfo(encounterID);
	elseif stype == EJ_STYPE_CREATURE then
		for i=1,MAX_CREATURES_PER_ENCOUNTER do
			local cId, cName, _, cDisplayInfo = EJ_GetCreatureInfo(i, encounterID, instanceID);
			if cId == id then
				name = cName
				displayInfo = cDisplayInfo;
				break;
			end
		end
		typeText = ENCOUNTER_JOURNAL_ENCOUNTER
		path = EJ_GetInstanceInfo(instanceID).." | "..EJ_GetEncounterInfo(encounterID);
	end
	return name, icon, path, typeText, displayInfo, itemID, stype;
end


function EncounterJournal_SelectSearch(index)
	local _;
	local id, stype, mask, instanceID, encounterID = EJ_GetSearchResult(index);
	local sectionID, creatureID, itemID;
	if stype == EJ_STYPE_INSTANCE then
		instanceID = id;
	elseif stype == EJ_STYPE_SECTION then
		sectionID = id;
	elseif stype == EJ_STYPE_ITEM then
		itemID = id;
	elseif stype == EJ_STYPE_CREATURE then
		creatureID = id;
	end
	
	EncounterJournal_OpenJournal(mask, instanceID, encounterID, sectionID, creatureID, itemID);
	EncounterJournal.searchResults:Hide();
end


function EncounterJournal_SearchUpdate()
	local scrollFrame = EncounterJournal.searchResults.scrollFrame;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local results = scrollFrame.buttons;
	local result, index;
	
	local numResults = EJ_GetNumSearchResults();
	
	for i = 1,#results do
		result = results[i];
		index = offset + i;
		if index <= numResults then
			local name, icon, path, typeText, displayInfo, itemID, stype = EncounterJournal_GetSearchDisplay(index);
			if stype == EJ_STYPE_INSTANCE then
				result.icon:SetTexCoord(0.16796875, 0.51171875, 0.03125, 0.71875);
			else
				result.icon:SetTexCoord(0, 1, 0, 1);
			end
			
			result.name:SetText(name);
			result.resultType:SetText(typeText);
			result.path:SetText(path);
			result.icon:SetTexture(icon);
			result.itemID = itemID;
			if displayInfo and displayInfo > 0 then
				SetPortraitTexture(result.icon, displayInfo);
			end
			result:SetID(index);
			result:Show();
			
			if result.showingTooltip then
				if itemID then
					GameTooltip:SetOwner(result, "ANCHOR_RIGHT");
					GameTooltip:SetItemByID(itemID);
				else
					GameTooltip:Hide();
				end
			end
		else
			result:Hide();
		end
	end
	
	local totalHeight = numResults * 49;
	HybridScrollFrame_Update(scrollFrame, totalHeight, 370);
end


function EncounterJournal_ShowFullSearch()
	local numResults = EJ_GetNumSearchResults();
	if numResults == 0 then
		EncounterJournal.searchResults:Hide();
		return;
	end

	EncounterJournal.searchResults.TitleText:SetText(string.format(ENCOUNTER_JOURNAL_SEARCH_RESULTS, EncounterJournal.searchBox:GetText(), numResults));
	EncounterJournal.searchResults:Show();
	EncounterJournal_SearchUpdate();
	EncounterJournal.searchResults.scrollFrame.scrollBar:SetValue(0);
	EncounterJournal_HideSearchPreview();
end


function EncounterJournal_HideSearchPreview()
	EncounterJournal.searchBox.showAllResults:Hide();
	local index = 1;
	local unusedButton = EncounterJournal.searchBox["sbutton"..index];
	while unusedButton do
		unusedButton:Hide();
		index = index + 1;
		unusedButton = EncounterJournal.searchBox["sbutton"..index]
	end
end


function EncounterJournal_ClearSearch(editbox)
	EncounterJournal.searchResults:Hide();
	EncounterJournal_HideSearchPreview();
end


function EncounterJournal_OnSearchTextChanged(self)
	local text = self:GetText();
	EncounterJournal_HideSearchPreview();
		
	if strlen(text) < EJ_MIN_CHARACTER_SEARCH or text == SEARCH then
		EJ_ClearSearch();
		EncounterJournal.searchResults:Hide();
		return;
	end
	EJ_SetSearch(text);
	
	if EncounterJournal.searchResults:IsShown() then
		EncounterJournal_ShowFullSearch();
	else
		local numResults = EJ_GetNumSearchResults();
		local index = 1;
		local button;
		while index <= numResults do
			button = EncounterJournal.searchBox["sbutton"..index];
			if button then
				local name, icon, path, typeText, displayInfo, itemID = EncounterJournal_GetSearchDisplay(index);
				button.name:SetText(name);
				button.icon:SetTexture(icon);
				button.itemID = itemID;
				if displayInfo and displayInfo > 0 then
					SetPortraitTexture(button.icon, displayInfo);
				end
				button:SetID(index);
				button:Show();
			else
				button = EncounterJournal.searchBox.showAllResults;
				button.text:SetText(string.format(ENCOUNTER_JOURNAL_SHOW_SEARCH_RESULTS, numResults));
				EncounterJournal.searchBox.showAllResults:Show();
				break;
			end
			index = index + 1;
		end
		
		EncounterJournal.searchBox.sbutton1.boarderAnchor:SetPoint("BOTTOM", button, "BOTTOM", 0, -5);
	end
end


function EncounterJournal_AddMapButtons()
	local left = WorldMapBossButtonFrame:GetLeft();
	local right = WorldMapBossButtonFrame:GetRight();
	local top = WorldMapBossButtonFrame:GetTop();
	local bottom = WorldMapBossButtonFrame:GetBottom();

	if not left or not right or not top or not bottom then
		--This frame is resizing
		WorldMapBossButtonFrame.ready = false;
		WorldMapBossButtonFrame:SetScript("OnUpdate", EncounterJournal_AddMapButtons);
		return;
	else
		WorldMapBossButtonFrame:SetScript("OnUpdate", nil);
	end
	
	local scale = WorldMapDetailFrame:GetScale();
	local width = WorldMapDetailFrame:GetWidth() * scale;
	local height = WorldMapDetailFrame:GetHeight() * scale;

	local bossButton, questPOI, displayInfo, _;
	local index = 1;
	local x, y, instanceID, name, description, encounterID = EJ_GetMapEncounter(index);
	while name do
		bossButton = _G["EJMapButton"..index];
		if not bossButton then -- create button
			bossButton = CreateFrame("Button", "EJMapButton"..index, WorldMapBossButtonFrame, "EncounterMapButtonTemplate");
		end
	
		bossButton.instanceID = instanceID;
		bossButton.encounterID = encounterID;
		bossButton.tooltipTitle = name;
		bossButton.tooltipText = description;
		bossButton:SetPoint("CENTER", WorldMapBossButtonFrame, "BOTTOMLEFT", x*width, y*height);
		_, _, _, displayInfo = EJ_GetCreatureInfo(1, encounterID, instanceID);
		bossButton.displayInfo = displayInfo;
		SetPortraitTexture(bossButton.bgImage, displayInfo);
		bossButton:Show();
		index = index + 1;
		x, y, instanceID, name, description, encounterID = EJ_GetMapEncounter(index);
	end
	
	bossButton = _G["EJMapButton"..index];
	while bossButton do
		bossButton:Hide();
		index = index + 1;
		bossButton = _G["EJMapButton"..index];
	end
	
	WorldMapBossButtonFrame.ready = true;
	EncounterJournal_CheckQuestButtons();
end
	

function EncounterJournal_CheckQuestButtons()
	if not WorldMapBossButtonFrame.ready then
		return;
	end
	
	--Validate that there are no quest button intersection
	local questI, bossI = 1, 1;
	bossButton = _G["EJMapButton"..bossI];
	questPOI = _G["poiWorldMapPOIFrame1_"..questI];
	while bossButton and bossButton:IsShown() do
		while questPOI and questPOI:IsShown() do
			local qx,qy = questPOI:GetCenter();
			local bx,by = bossButton:GetCenter();
			if not qx or not qy or not bx or not by then
				_G["EJMapButton1"]:SetScript("OnUpdate", EncounterJournal_CheckQuestButtons);
				return;
			end
			
			local xdis = abs(bx-qx);
			local ydis = abs(by-qy);
			local disSqr = xdis*xdis + ydis*ydis;
			
			if EJ_QUEST_POI_MINDIS_SQR > disSqr then
				questPOI:SetPoint("CENTER", bossButton, "BOTTOMRIGHT",  -15, 15);
			end
			questI = questI + 1;
			questPOI = _G["poiWorldMapPOIFrame1_"..questI];
		end
		questI = 1;
		bossI = bossI + 1;
		bossButton = _G["EJMapButton"..bossI];
		questPOI = _G["poiWorldMapPOIFrame1_"..questI];
	end
	if _G["EJMapButton1"] then
		_G["EJMapButton1"]:SetScript("OnUpdate", nil);
	end
end


function EncounterJournal_SetClassFilter(classID, className)
	local index = 1;
	local classButton = EncounterJournal.encounter.info.lootScroll.classFilter["class"..index];

	while classButton do
		if classButton:GetID() == classID then
			classButton:SetChecked(true);
		else
			classButton:SetChecked(false);
		end
		index = index + 1;
		classButton = EncounterJournal.encounter.info.lootScroll.classFilter["class"..index];
	end
	
	if classID then
		EncounterJournal.encounter.info.lootScroll.classClearFilter.text:SetText(string.format(EJ_CLASS_FILTER, className));
		EncounterJournal.encounter.info.lootScroll.classClearFilter:Show();
		EJ_SetClassLootFilter(classID);
		EncounterJournal.encounter.info.lootScroll:SetHeight(357);
	else
		EncounterJournal.encounter.info.lootScroll.classClearFilter:Hide();
		EJ_SetClassLootFilter(-1);
		EncounterJournal.encounter.info.lootScroll:SetHeight(380);
	end
	
	EncounterJournal_LootUpdate();
end


function EncounterJournal_OpenJournalLink(tag, jtype, id, mask)
	jtype = tonumber(jtype);
	id = tonumber(id);
	mask = tonumber(mask);
	local instanceID, encounterID, sectionID = EJ_HandleLinkPath(jtype, id);
	EncounterJournal_OpenJournal(mask, instanceID, encounterID, sectionID);
end


function EncounterJournal_OpenJournal(mask, instanceID, encounterID, sectionID, creatureID, itemID)
	ShowUIPanel(EncounterJournal);
	if instanceID then
		NavBar_Reset(EncounterJournal.navBar);
		EncounterJournal_DisplayInstance(instanceID);
		EJ_SetDifficultyByMask(mask);
		if encounterID then
			if sectionID then
				EncounterJournal.encounter.info.bossTab:Click();
				local sectionPath = {EJ_GetSectionPath(sectionID)};
				for _, id in pairs(sectionPath) do
					EJ_section_openTable[id] = true;
				end
			end
			
			
			EncounterJournal_DisplayEncounter(encounterID);
			if sectionID then
				EncounterJournal_FocusSection(sectionID);
			elseif itemID then
				EncounterJournal.encounter.info.lootTab:Click();
			end
			
			
			if creatureID then
				for i=1,MAX_CREATURES_PER_ENCOUNTER do
					local button = EncounterJournal.encounter["creatureButton"..i];
					if button and button:IsShown() and button.id == creatureID then
						EncounterJournal_DisplayCreature(button);
					end
				end
			end
		end
	else
		EncounterJournal_ListInstances()
	end
end


----------------------------------------
--------------Nav Bar Func--------------
----------------------------------------
function EJNAV_RefreshInstance()
	EncounterJournal_DisplayInstance(EncounterJournal.instanceID, true);
end

function EJNAV_SelectInstance(self, index, navBar)
	local showRaid = EncounterJournal.instanceSelect.raidsTab:IsEnabled() == nil;
	local instanceID = EJ_GetInstanceByIndex(index, showRaid);
	EncounterJournal_DisplayInstance(instanceID);
end


function EJNAV_ListInstance(self, index)
	--local navBar = self:GetParent();
	local showRaid = EncounterJournal.instanceSelect.raidsTab:IsEnabled() == nil;
	local _, name = EJ_GetInstanceByIndex(index, showRaid);
	return name, EJNAV_SelectInstance;
end


function EJNAV_RefreshEncounter()
	EncounterJournal_DisplayInstance(EncounterJournal.encounterID);
end


function EJNAV_SelectEncounter(self, index, navBar)
	local _, _, bossID = EJ_GetEncounterInfoByIndex(index);
	EncounterJournal_DisplayEncounter(bossID);
end


function EJNAV_ListEncounter(self, index)
	--local navBar = self:GetParent();
	local name = EJ_GetEncounterInfoByIndex(index);
	return name, EJNAV_SelectEncounter;
end