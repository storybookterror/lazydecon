local LAM2 = LibAddonMenu2

LZD_ALWAYS    = 1
LZD_NEVER     = 2
LZD_LEVELLING = 3

local LZD = {
    name = "LazyDecon",
    version = "0.1",

    defaults = {
        glyphs = {
            when = LZD_ALWAYS,
            extraction = 0,
            minQuality = ITEM_FUNCTIONAL_QUALITY_NORMAL,
            maxQuality = ITEM_FUNCTIONAL_QUALITY_ARTIFACT,
        },
        equip = {
            when = LZD_ALWAYS,
            extraction = 0,
            trashMinQuality = ITEM_FUNCTIONAL_QUALITY_NORMAL,
            trashMaxQuality = ITEM_FUNCTIONAL_QUALITY_ARTIFACT,
            researchable = false,
            intricates = LZD_LEVELLING,
            ornates = false,
            sets = false,
            setMinQuality = ITEM_FUNCTIONAL_QUALITY_NORMAL,
            setMaxQuality = ITEM_FUNCTIONAL_QUALITY_ARTIFACT,
            setTraits = {
                [ITEM_TRAIT_TYPE_ARMOR_STURDY] = false,
                [ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = true,
                [ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = true,
                [ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = true,
                [ITEM_TRAIT_TYPE_ARMOR_TRAINING] = true,
                [ITEM_TRAIT_TYPE_ARMOR_INFUSED] = false,
                [ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = true, -- Invigorating
                [ITEM_TRAIT_TYPE_ARMOR_DIVINES] = false,
                [ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = false,
                [ITEM_TRAIT_TYPE_WEAPON_POWERED] = false,
                [ITEM_TRAIT_TYPE_WEAPON_CHARGED] = false,
                [ITEM_TRAIT_TYPE_WEAPON_PRECISE] = false,
                [ITEM_TRAIT_TYPE_WEAPON_INFUSED] = false,
                [ITEM_TRAIT_TYPE_WEAPON_DEFENDING] = true,
                [ITEM_TRAIT_TYPE_WEAPON_TRAINING] = true,
                [ITEM_TRAIT_TYPE_WEAPON_SHARPENED] = true,
                [ITEM_TRAIT_TYPE_WEAPON_DECISIVE] = true,
                [ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = false,
            }
        },
        jewelry = {
            when = LZD_ALWAYS,
            extraction = 3,
            trashMinQuality = ITEM_FUNCTIONAL_QUALITY_NORMAL,
            trashMaxQuality = ITEM_FUNCTIONAL_QUALITY_ARTIFACT,
            researchable = false,
            intricates = LZD_LEVELLING,
            ornates = false,
            sets = false,
            setMinQuality = ITEM_FUNCTIONAL_QUALITY_NORMAL,
            setMaxQuality = ITEM_FUNCTIONAL_QUALITY_ARCANE,
            setTraits = {
                [ITEM_TRAIT_TYPE_JEWELRY_ARCANE] = true,
                [ITEM_TRAIT_TYPE_JEWELRY_HEALTHY] = true,
                [ITEM_TRAIT_TYPE_JEWELRY_ROBUST] = true,
                [ITEM_TRAIT_TYPE_JEWELRY_TRIUNE] = false,
                [ITEM_TRAIT_TYPE_JEWELRY_INFUSED] = false,
                [ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE] = false,
                [ITEM_TRAIT_TYPE_JEWELRY_SWIFT] = false,
                [ITEM_TRAIT_TYPE_JEWELRY_HARMONY] = false,
                [ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY] = false,
            }
        },
    },
}

-----------------------------------------------------------------------------
-- Utilities
-----------------------------------------------------------------------------

local function LZD_IsTradeSkillFullyLevelled(tradeskill)
    local skillData = SKILLS_DATA_MANAGER:GetCraftingSkillLineData(tradeskill)
    local _, skillLineIndex = skillData:GetIndices()
    local lastRankXP, nextRankXP, curXP = GetSkillLineXPInfo(SKILL_TYPE_TRADESKILL, skillLineIndex)
    return nextRankXP == curXP
end

local function LZD_ExtractionPassiveRank(tradeskill)
    local passiveIndex = {
        [CRAFTING_TYPE_BLACKSMITHING] = 4, -- Metal Extraction
        [CRAFTING_TYPE_CLOTHIER] = 4, -- Unraveling
        [CRAFTING_TYPE_WOODWORKING] = 4, -- Wood Extraction
        [CRAFTING_TYPE_ENCHANTING] = 5, -- Runestone Extraction
        [CRAFTING_TYPE_JEWELRYCRAFTING] = 3, -- Jewelry Extraction
    }
    local skillLine = SKILLS_DATA_MANAGER:GetCraftingSkillLineData(tradeskill)
    local skillData = skillLine:GetSkillDataByIndex(passiveIndex[tradeskill])
    -- Can print skillData:GetRankData(1).name to verify indices
    assert(skillData:IsPassive())
    assert(skillData.numRanks == 3)
    return skillData:GetNumPointsAllocated()
end

-----------------------------------------------------------------------------
-- Settings UI Panel
-----------------------------------------------------------------------------

local function LZD_CreateSettingsPanel()
    local panelData = {
        type = "panel",
        name = "Lazy Deconstructor",
        displayName = "Lazy Deconstructor",
        author = "StorybookTerror",
        version = LZD.version,
        registerForDefaults = true,
        website = "http://github.com/storybookterror/lazydecon"
    }
    LAM2:RegisterAddonPanel(LZD.name, panelData)

    local qualityNames = {}
    local qualityEnums = {}
    for i = 0, ITEM_FUNCTIONAL_QUALITY_LEGENDARY do
        local color = GetItemQualityColor(i)
        local name = color:Colorize(GetString("SI_ITEMQUALITY", i))
        qualityNames[i] = name
        qualityEnums[name] = i
    end

    local function qualityMenu(name, category, option)
        return {
            type = "dropdown",
            name = name,
            choices = qualityNames,
            default = qualityNames[LZD.defaults[category][option]],
            getFunc = function() return qualityNames[LZD.vars[category][option]] end,
            setFunc = function(value) LZD.vars[category][option] = qualityEnums[value] end,
        }
    end

    local function dropdown(name, choices, category, option, bias, tooltip)
        bias = bias or 0
        return {
            type = "dropdown",
            name = name,
            tooltip = tooltip,
            choices = choices,
            default = LZD.defaults[category][option],
            getFunc = function() return choices[LZD.vars[category][option] + bias] end,
            setFunc = function(value) for i, s in ipairs(choices) do if value == s then LZD.vars[category][option] = i - bias break end end end,
        }
    end

    local function whenToDeconMenu(name, category, option)
        local choices = {
            [LZD_ALWAYS]    = GetString(SI_YES),
            [LZD_NEVER]     = GetString(SI_NO),
            [LZD_LEVELLING] = "Only if Levelling",
        }
        return dropdown(name, choices, category, option)
    end

    local function rankMenu(category, option)
        local choices = { "Any", "At least rank 1", "At least rank 2", "Max" }
        return dropdown("Only with Extraction Passive Rank", choices,
                        category, option, 1,
                        "Intricates used when levelling ignore this setting.")
    end

    local function checkbox(name, category, option, tooltip)
        return {
            type = "checkbox",
            name = name,
            tooltip = tooltip,
            default = LZD.defaults[category][option],
            getFunc = function() return LZD.vars[category][option] end,
            setFunc = function(value) LZD.vars[category][option] = value end,
        }
    end

    local function craftSubMenu(category)
        return {
            whenToDeconMenu(GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_BLACKSMITHING), category, CRAFTING_TYPE_BLACKSMITHING),
            whenToDeconMenu(GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_CLOTHIER), category, CRAFTING_TYPE_CLOTHIER),
            whenToDeconMenu(GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_WOODWORKING), category, CRAFTING_TYPE_WOODWORKING),
            whenToDeconMenu(GetString("SI_TRADESKILLTYPE", CRAFTING_TYPE_JEWELRYCRAFTING), category, CRAFTING_TYPE_JEWELRYCRAFTING),
        }
    end

    local function traitOption(category, trait)
        local name = GetString("SI_ITEMTRAITTYPE", trait)
        return {
            type = "checkbox",
            name = name,
            default = LZD.defaults[category].setTraits[trait],
            getFunc = function() return LZD.vars[category].setTraits[trait] end,
            setFunc = function(value) LZD.vars[category].setTraits[trait] = value end,
        }
    end

    local options = {
        {
            type = "header",
            name = "Glyphs",
        },
        whenToDeconMenu("Include Glyphs", "glyphs", "when"),
        rankMenu("glyphs", "extraction"),
        qualityMenu("Minimum Quality", "glyphs", "minQuality"),
        qualityMenu("Maximum Quality", "glyphs", "maxQuality"),

        {
            type = "header",
            name = "Weapons & Armor",
        },
        whenToDeconMenu("Include Weapons and Armor", "equip", "when"),
        rankMenu("equip", "extraction"),
        qualityMenu("Basic Items: Minimum Quality", "equip", "trashMinQuality"),
        qualityMenu("Basic Items: Maximum Quality", "equip", "trashMaxQuality"),
        checkbox("Include Researchable Items", "equip", "researchable", nil),
        whenToDeconMenu("Include Intricates", "equip", "intricates"),
        checkbox("Include Ornates", "equip", "ornates", nil),
        checkbox("Include Easily Reconstructed Sets", "equip", "sets",
                 "Set items with a reconstruction cost of 50 transmutation crystals or less will be marked for deconstruction."),
        qualityMenu("Set Items: Minimum Quality", "equip", "setMinQuality"),
        qualityMenu("Set Items: Maximum Quality", "equip", "setMaxQuality"),
        {
            type = "submenu",

            name = "Set Traits",
            controls =
            {
                {
                    type = "description",
                    text = "Only include set armor with these traits:",
                },
                traitOption("equip", ITEM_TRAIT_TYPE_ARMOR_STURDY),
                traitOption("equip", ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE),
                traitOption("equip", ITEM_TRAIT_TYPE_ARMOR_REINFORCED),
                traitOption("equip", ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED),
                traitOption("equip", ITEM_TRAIT_TYPE_ARMOR_TRAINING),
                traitOption("equip", ITEM_TRAIT_TYPE_ARMOR_INFUSED),
                traitOption("equip", ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS),
                traitOption("equip", ITEM_TRAIT_TYPE_ARMOR_DIVINES),
                traitOption("equip", ITEM_TRAIT_TYPE_ARMOR_NIRNHONED),
                {
                    type = "description",
                    text = "Only include set weapons with these traits:",
                },
                traitOption("equip", ITEM_TRAIT_TYPE_WEAPON_POWERED),
                traitOption("equip", ITEM_TRAIT_TYPE_WEAPON_CHARGED),
                traitOption("equip", ITEM_TRAIT_TYPE_WEAPON_PRECISE),
                traitOption("equip", ITEM_TRAIT_TYPE_WEAPON_INFUSED),
                traitOption("equip", ITEM_TRAIT_TYPE_WEAPON_DEFENDING),
                traitOption("equip", ITEM_TRAIT_TYPE_WEAPON_TRAINING),
                traitOption("equip", ITEM_TRAIT_TYPE_WEAPON_SHARPENED),
                traitOption("equip", ITEM_TRAIT_TYPE_WEAPON_DECISIVE),
                traitOption("equip", ITEM_TRAIT_TYPE_WEAPON_NIRNHONED),
            }
        },
        {
            type = "header",
            name = "Jewelry",
        },
        whenToDeconMenu("Include Jewelry", "jewelry", "when"),
        rankMenu("jewelry", "extraction"),
        qualityMenu("Basic Jewelry: Minimum Quality", "jewelry", "trashMinQuality"),
        qualityMenu("Basic Jewelry: Maximum Quality", "jewelry", "trashMaxQuality"),
        checkbox("Include Researchable Items", "jewelry", "researchable", nil),
        whenToDeconMenu("Include Intricates", "jewelry", "intricates"),
        checkbox("Include Ornates", "jewelry", "ornates", nil),
        checkbox("Include Easily Reconstructed Sets", "jewelry", "sets",
                 "Set items with a reconstruction cost of 50 transmutation crystals or less will be marked for deconstruction."),
        qualityMenu("Set Jewelry: Minimum Quality", "jewelry", "setMinQuality"),
        qualityMenu("Set Jewelry: Maximum Quality", "jewelry", "setMaxQuality"),
        {
            type = "submenu",

            name = "Set Traits",
            controls =
            {
                {
                    type = "description",
                    text = "Only include set jewelry with these traits:",
                },
                traitOption("jewelry", ITEM_TRAIT_TYPE_JEWELRY_ARCANE),
                traitOption("jewelry", ITEM_TRAIT_TYPE_JEWELRY_HEALTHY),
                traitOption("jewelry", ITEM_TRAIT_TYPE_JEWELRY_ROBUST),
                traitOption("jewelry", ITEM_TRAIT_TYPE_JEWELRY_TRIUNE),
                traitOption("jewelry", ITEM_TRAIT_TYPE_JEWELRY_INFUSED),
                traitOption("jewelry", ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE),
                traitOption("jewelry", ITEM_TRAIT_TYPE_JEWELRY_SWIFT),
                traitOption("jewelry", ITEM_TRAIT_TYPE_JEWELRY_HARMONY),
                traitOption("jewelry", ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY),
            }
        },
    }

    LAM2:RegisterOptionControls(LZD.name, options)
end

-----------------------------------------------------------------------------
-- What to Deconstruct
-----------------------------------------------------------------------------
local function LZD_ShouldDeconCraft(tristate, tradeskill)
    return tristate == LZD_ALWAYS or
           (tristate == LZD_LEVELLING and
            not LZD_IsTradeSkillFullyLevelled(tradeskill))
end

local function LZD_ShouldDeconEquipment(link, category)
    local isSet, setName, _, _, _, setId = GetItemLinkSetInfo(link, false)
    local researchable = CanItemLinkBeTraitResearched(link)
    local quality = GetItemLinkQuality(link)
    local craft = GetItemLinkCraftingSkillType(link)
    local traitInfo = GetItemTraitInformationFromItemLink(link)
    local traitType = GetItemLinkTraitType(link)

    if not LZD_ShouldDeconCraft(LZD.vars[category].when, craft) then
        return false
    end

    if LZD_ExtractionPassiveRank(craft) < LZD.vars[category].extraction and
       not (traitInfo == ITEM_TRAIT_INFORMATION_INTRICATE and
            LZD.vars[category].intricates == LZD_LEVELLING) then
        -- We skip the extraction skill check when levelling with intricates
        return false
    end

    if traitInfo == ITEM_TRAIT_INFORMATION_INTRICATE then
       return LZD_ShouldDeconCraft(LZD.vars[category].intricates, craft)
    end

    if traitInfo == ITEM_TRAIT_INFORMATION_ORNATE and not
       LZD.vars[category].ornates then
       return false
    end

    if researchable and not LZD.vars[category].researchable then
        return false
    end

    if not isSet then
        return quality >= LZD.vars[category].trashMinQuality and
               quality <= LZD.vars[category].trashMaxQuality
    end

    return LZD.vars[category].sets and
           LZD.vars[category].setTraits[traitType] and
           quality >= LZD.vars[category].setMinQuality and
           quality <= LZD.vars[category].setMaxQuality and
           GetItemReconstructionCurrencyOptionCost(setId, CURT_CHAOTIC_CREATIA) <= 50
end

local function LZD_ShouldDeconGlyphs(link)
    local quality = GetItemLinkQuality(link)

    return quality >= LZD.vars.glyphs.minQuality and
           quality <= LZD.vars.glyphs.maxQuality and
           LZD_ShouldDeconCraft(LZD.vars.glyphs.when, CRAFTING_TYPE_ENCHANTING)
end

local function LZD_ShouldDecon(bagId, slotIndex)
    if IsItemBoPAndTradeable(bagId, slotIndex) and GetGroupSize() > 0 then
        return false
    end

    if IsItemInArmory(bagId, slotIndex) then
        return false
    end

    local link = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)

    if IsItemLinkCrafted(link) then
        return false
    end

    -- Exclude unique items like "Grievous Leeching Ward"
    if IsItemLinkUnique(link) then
        return false
    end

    local equipType = GetItemLinkEquipType(link)

    if equipType == EQUIP_TYPE_RING or equipType == EQUIP_TYPE_NECK then
        return LZD_ShouldDeconEquipment(link, "jewelry")
    elseif equipType ~= EQUIP_TYPE_INVALID then
        return LZD_ShouldDeconEquipment(link, "equip")
    else
        return LZD_ShouldDeconGlyphs(link)
    end
end

-----------------------------------------------------------------------------
-- Deconstruction Panel Hooks
-----------------------------------------------------------------------------
local function LZD_SelectItem(self, bagId, slotIndex, ...)
    local name = GetItemName(bagId, slotIndex)
    local link = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
    if LZD_ShouldDecon(bagId, slotIndex) then
        LZD.station:AddItemToCraft(bagId, slotIndex)
        d("LazyDecon added " .. link)

        -- Adding multiple items would trigger the "select an item" sound
        -- multiple times.  Disable the sound temporarily (after the first
        -- one) and re-enable it after we finish enumerating items.
        SOUNDS.SMITHING_ITEM_TO_EXTRACT_PLACED = SOUNDS.NONE
    end
end

local function LZD_FixSound(...)
    -- Restore the original sound effect once now that we're done iterating
    SOUNDS.SMITHING_ITEM_TO_EXTRACT_PLACED = LZD.savedSound
end

-----------------------------------------------------------------------------
-- Event Handlers
-----------------------------------------------------------------------------
local function LZD_SwitchDeconScreen(eventCode, craftingType, sameStation, craftingMode)
    if ZO_Smithing_IsUniversalDeconstructionCraftingMode(craftingMode) then
        LZD.station = UNIVERSAL_DECONSTRUCTION
    else
        LZD.station = SMITHING
    end
end

-----------------------------------------------------------------------------
-- Add-on initialization
-----------------------------------------------------------------------------
local function LZD_RegisterHooks(inventory)
    SecurePostHook(inventory, "AddItemData", LZD_SelectItem)
    --SecurePostHook(inventory, "EnumerateInventorySlotsAndAddToScrollData", LZD_FixSound)
    SecurePostHook(inventory, "GetIndividualInventorySlotsAndAddToScrollData", LZD_FixSound)
end

local function LZD_Initialize()
    LZD.vars = ZO_SavedVars:NewAccountWide("LazyDeconVars", 2, GetWorldName(), LZD.defaults)

    LZD.savedSound = SOUNDS.SMITHING_ITEM_TO_EXTRACT_PLACED
    LZD_RegisterHooks(UNIVERSAL_DECONSTRUCTION.deconstructionPanel.inventory)
    LZD_RegisterHooks(SMITHING.deconstructionPanel.inventory)
    EVENT_MANAGER:RegisterForEvent(LZD.name, EVENT_CRAFTING_STATION_INTERACT, LZD_SwitchDeconScreen)
    LZD_CreateSettingsPanel()
end

-----------------------------------------------------------------------------
-- Add-on loading callback
-----------------------------------------------------------------------------
local function OnAddonLoaded(_, AddonName)
    if AddonName ~= LZD.name then return end

    EVENT_MANAGER:UnregisterForEvent(LZD.name, EVENT_ADD_ON_LOADED)
    LZD_Initialize()
end

EVENT_MANAGER:RegisterForEvent(LZD.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
