local LAM2 = LibAddonMenu2

LZD_ALWAYS    = 1
LZD_NEVER     = 2
LZD_LEVELLING = 3

local LZD = {
    name = "LazyDecon",
    version = "0.1",

    defaults = {
        equip = {
            when = LZD_ALWAYS,
            trashMinQuality = ITEM_FUNCTIONAL_QUALITY_NORMAL,
            trashMaxQuality = ITEM_FUNCTIONAL_QUALITY_ARTIFACT,
            researchable = false,
            sets = false,
            setMinQuality = ITEM_FUNCTIONAL_QUALITY_NORMAL,
            setMaxQuality = ITEM_FUNCTIONAL_QUALITY_ARCANE,
            setTraits = {
                [ITEM_TRAIT_TYPE_ARMOR_STURDY] = false,
                [ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = false,
                [ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = false,
                [ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = false,
                [ITEM_TRAIT_TYPE_ARMOR_TRAINING] = false,
                [ITEM_TRAIT_TYPE_ARMOR_INFUSED] = false,
                [ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = true, -- Invigorating
                [ITEM_TRAIT_TYPE_ARMOR_DIVINES] = false,
                [ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = false,
                [ITEM_TRAIT_TYPE_JEWELRY_ARCANE] = true,
                [ITEM_TRAIT_TYPE_JEWELRY_HEALTHY] = true,
                [ITEM_TRAIT_TYPE_JEWELRY_ROBUST] = true,
                [ITEM_TRAIT_TYPE_JEWELRY_TRIUNE] = false,
                [ITEM_TRAIT_TYPE_JEWELRY_INFUSED] = false,
                [ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE] = false,
                [ITEM_TRAIT_TYPE_JEWELRY_SWIFT] = false,
                [ITEM_TRAIT_TYPE_JEWELRY_HARMONY] = false,
                [ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY] = false,
                [ITEM_TRAIT_TYPE_WEAPON_POWERED] = false,
                [ITEM_TRAIT_TYPE_WEAPON_CHARGED] = false,
                [ITEM_TRAIT_TYPE_WEAPON_PRECISE] = false,
                [ITEM_TRAIT_TYPE_WEAPON_INFUSED] = false,
                [ITEM_TRAIT_TYPE_WEAPON_DEFENDING] = false,
                [ITEM_TRAIT_TYPE_WEAPON_TRAINING] = true,
                [ITEM_TRAIT_TYPE_WEAPON_SHARPENED] = true,
                [ITEM_TRAIT_TYPE_WEAPON_DECISIVE] = true,
                [ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = false,
            }
        },
        intricates = {
            [CRAFTING_TYPE_BLACKSMITHING] = LZD_ALWAYS,
            [CRAFTING_TYPE_CLOTHIER] = LZD_ALWAYS,
            [CRAFTING_TYPE_WOODWORKING] = LZD_ALWAYS,
            [CRAFTING_TYPE_JEWELRYCRAFTING] = LZD_ALWAYS,
        },
        ornates = {
            [CRAFTING_TYPE_BLACKSMITHING] = LZD_NEVER,
            [CRAFTING_TYPE_CLOTHIER] = LZD_NEVER,
            [CRAFTING_TYPE_WOODWORKING] = LZD_NEVER,
            [CRAFTING_TYPE_JEWELRYCRAFTING] = LZD_NEVER,
        },
        glyphs = {
            when = LZD_ALWAYS,
            minQuality = ITEM_FUNCTIONAL_QUALITY_NORMAL,
            maxQuality = ITEM_FUNCTIONAL_QUALITY_ARTIFACT,
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

    local whenToDeconOptions = {}
    whenToDeconOptions[LZD_ALWAYS] = GetString(SI_YES)
    whenToDeconOptions[LZD_NEVER] = GetString(SI_NO)
    whenToDeconOptions[LZD_LEVELLING] = "Only if Levelling"

    local function whenToDeconMenu(name, category, option)
        return {
            type = "dropdown",
            name = name,
            choices = whenToDeconOptions,
            default = LZD.defaults[category][option],
            getFunc = function() return whenToDeconOptions[LZD.vars[category][option]] end,
            setFunc = function(value) for i, s in ipairs(whenToDeconOptions) do if value == s then LZD.vars[category][option] = i break end end end,
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

    local function traitOption(trait)
        local category = GetItemTraitTypeCategory(trait)
        local name = GetString("SI_ITEMTRAITTYPE", trait)
        local catnames = {
            [ITEM_TRAIT_TYPE_CATEGORY_ARMOR] = " Armor",
            [ITEM_TRAIT_TYPE_CATEGORY_JEWELRY] = " Jewelry",
            [ITEM_TRAIT_TYPE_CATEGORY_WEAPON] = " Weapons",
        }
        return {
            type = "checkbox",
            name = name .. catnames[category],
            default = LZD.defaults.equip.setTraits[trait],
            getFunc = function() return LZD.vars.equip.setTraits[trait] end,
            setFunc = function(value) LZD.vars.equip.setTraits[trait] = value end,
        }
    end

    local options = {
        {
            type = "header",
            name = "Glyphs",
        },
        whenToDeconMenu("Include Glyphs", "glyphs", "when"),
        qualityMenu("Minimum Quality", "glyphs", "minQuality"),
        qualityMenu("Maximum Quality", "glyphs", "maxQuality"),

        {
            type = "header",
            name = "Equipment",
        },
        whenToDeconMenu("Include Equipment", "equip", "when"),
        qualityMenu("Basic Items: Minimum Quality", "equip", "trashMinQuality"),
        qualityMenu("Basic Items: Maximum Quality", "equip", "trashMaxQuality"),
        {
            type = "checkbox",
            name = "Include Researchable Items",
            default = LZD.defaults.equip.researchable,
            getFunc = function() return LZD.vars.equip.researchable end,
            setFunc = function(value) LZD.vars.equip.researchable = value end,
        },
        {
            type = "checkbox",
            name = "Include Easily Reconstructed Sets",
            tooltip = "Set items with a reconstruction cost of 50 transmutation crystals or less will be marked for deconstruction.",
            default = LZD.defaults.equip.sets,
            getFunc = function() return LZD.vars.equip.sets end,
            setFunc = function(value) LZD.vars.equip.sets = value end,
        },
        qualityMenu("Set Items: Minimum Quality", "equip", "setMinQuality"),
        qualityMenu("Set Items: Maximum Quality", "equip", "setMaxQuality"),
        {
            type = "submenu",

            name = "Set Traits",
            controls =
            {
                {
                    type = "description",
                    text = "Only include set items with these traits:",
                },
                traitOption(ITEM_TRAIT_TYPE_ARMOR_STURDY),
                traitOption(ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE),
                traitOption(ITEM_TRAIT_TYPE_ARMOR_REINFORCED),
                traitOption(ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED),
                traitOption(ITEM_TRAIT_TYPE_ARMOR_TRAINING),
                traitOption(ITEM_TRAIT_TYPE_ARMOR_INFUSED),
                traitOption(ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS),
                traitOption(ITEM_TRAIT_TYPE_ARMOR_DIVINES),
                traitOption(ITEM_TRAIT_TYPE_ARMOR_NIRNHONED),
                traitOption(ITEM_TRAIT_TYPE_JEWELRY_ARCANE),
                traitOption(ITEM_TRAIT_TYPE_JEWELRY_HEALTHY),
                traitOption(ITEM_TRAIT_TYPE_JEWELRY_ROBUST),
                traitOption(ITEM_TRAIT_TYPE_JEWELRY_TRIUNE),
                traitOption(ITEM_TRAIT_TYPE_JEWELRY_INFUSED),
                traitOption(ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE),
                traitOption(ITEM_TRAIT_TYPE_JEWELRY_SWIFT),
                traitOption(ITEM_TRAIT_TYPE_JEWELRY_HARMONY),
                traitOption(ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY),
                traitOption(ITEM_TRAIT_TYPE_WEAPON_POWERED),
                traitOption(ITEM_TRAIT_TYPE_WEAPON_CHARGED),
                traitOption(ITEM_TRAIT_TYPE_WEAPON_PRECISE),
                traitOption(ITEM_TRAIT_TYPE_WEAPON_INFUSED),
                traitOption(ITEM_TRAIT_TYPE_WEAPON_DEFENDING),
                traitOption(ITEM_TRAIT_TYPE_WEAPON_TRAINING),
                traitOption(ITEM_TRAIT_TYPE_WEAPON_SHARPENED),
                traitOption(ITEM_TRAIT_TYPE_WEAPON_DECISIVE),
                traitOption(ITEM_TRAIT_TYPE_WEAPON_NIRNHONED),
            }
        },

        {
            type = "submenu",
            name = "Intricates",
            controls = craftSubMenu("intricates"),
        },
        {
            type = "submenu",
            name = "Ornates",
            controls = craftSubMenu("ornates"),
        },
    }

    LAM2:RegisterOptionControls(LZD.name, options)
end

-----------------------------------------------------------------------------
-- What to Deconstruct
-----------------------------------------------------------------------------
local function LZD_ShouldDecon(tristate, tradeskill)
    return tristate == LZD_ALWAYS or
           (tristate == LZD_LEVELLING and
            not LZD_IsTradeSkillFullyLevelled(tradeskill))
end

local function LZD_ShouldDeconEquipment(link)
    local isSet, setName, _, _, _, setId = GetItemLinkSetInfo(link, false)
    local researchable = CanItemLinkBeTraitResearched(link)
    local quality = GetItemLinkQuality(link)
    local craft = GetItemLinkCraftingSkillType(link)
    local traitInfo = GetItemTraitInformationFromItemLink(link)
    local traitType = GetItemLinkTraitType(link)

    if not LZD_ShouldDecon(LZD.vars.equip.when, craft) then
        return false
    end

    if traitInfo == ITEM_TRAIT_INFORMATION_INTRICATE then
       return LZD_ShouldDecon(LZD.vars.intricates[craft], craft)
    end

    if traitInfo == ITEM_TRAIT_INFORMATION_ORNATE then
       return LZD_ShouldDecon(LZD.vars.ornates[craft], craft)
    end

    if researchable and not LZD.vars.equip.researchable then
        return false
    end

    if not isSet then
        return quality >= LZD.vars.equip.trashMinQuality and
               quality <= LZD.vars.equip.trashMaxQuality
    end

    return LZD.vars.equip.sets and
           LZD.vars.equip.setTraits[traitType] and
           quality >= LZD.vars.equip.setMinQuality and
           quality <= LZD.vars.equip.setMaxQuality and
           GetItemReconstructionCurrencyOptionCost(setId, CURT_CHAOTIC_CREATIA) <= 50
end

local function LZD_ShouldDeconGlyphs(link)
    local quality = GetItemLinkQuality(link)

    return quality >= LZD.vars.glyphs.minQuality and
           quality <= LZD.vars.glyphs.maxQuality and
           LZD_ShouldDecon(LZD.vars.glyphs.when, CRAFTING_TYPE_ENCHANTING)
end

local function LZD_ShouldDecon(link)
    if IsItemLinkCrafted(link) then
        return false
    end

    if GetItemLinkEquipType(link) ~= EQUIP_TYPE_INVALID then
        return LZD_ShouldDeconEquipment(link)
    else
        return LZD_ShouldDeconGlyphs(link)
    end
end

-----------------------------------------------------------------------------
-- Deconstruction Panel Hooks
-----------------------------------------------------------------------------
local function LZD_SelectItem(self, bagId, slotIndex, ...)
    name = GetItemName(bagId, slotIndex)
    link = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
    if LZD_ShouldDecon(link) then
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
    LZD.vars = ZO_SavedVars:NewAccountWide("LazyDeconVars", 1, GetWorldName(), LZD.defaults)

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
