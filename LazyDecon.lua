local LAM2 = LibAddonMenu2

LZD_ALWAYS    = 1
LZD_NEVER     = 2
LZD_LEVELLING = 3

local LZD = {
    name = "LazyDecon",
    version = "0.1",

    defaults = {
        equip = {
            minQuality = ITEM_FUNCTIONAL_QUALITY_NORMAL,
            maxQuality = ITEM_FUNCTIONAL_QUALITY_ARTIFACT,
            researchable = false,
            ornates = false,
            intricates = LZD_ALWAYS,
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
            width = "full",
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
            width = "full",
            choices = whenToDeconOptions,
            default = LZD.defaults[category][option],
            getFunc = function() return whenToDeconOptions[LZD.vars[category][option]] end,
            setFunc = function(value) for i, s in ipairs(whenToDeconOptions) do if value == s then LZD.vars[category][option] = i break end end end,
        }
    end

    local options = {
        {
            type = "header",
            name = "Glyphs",
        },
        whenToDeconMenu("Deconstruct?", "glyphs", "when"),
        qualityMenu("Minimum Quality", "glyphs", "minQuality"),
        qualityMenu("Maximum Quality", "glyphs", "maxQuality"),

        {
            type = "header",
            name = "Equipment",
        },
        qualityMenu("Minimum Quality", "equip", "minQuality"),
        qualityMenu("Maximum Quality", "equip", "maxQuality"),
        {
            type = "checkbox",
            name = "Researchable",
            width = "full",
            default = LZD.defaults.equip.researchable,
            getFunc = function() return LZD.vars.equip.researchable end,
            setFunc = function(value) LZD.vars.equip.researchable = value end,
        },
        {
            type = "checkbox",
            name = "Ornates",
            width = "full",
            default = LZD.defaults.equip.ornates,
            getFunc = function() return LZD.vars.equip.ornates end,
            setFunc = function(value) LZD.vars.equip.ornates = value end,
        },
        whenToDeconMenu("Intricates", "equip", "intricates"),
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
    local crafted = IsItemLinkCrafted(link)
    local traitInfo = GetItemTraitInformationFromItemLink(link)
    local craft = GetItemLinkCraftingSkillType(link)

    local ornate = traitInfo == ITEM_TRAIT_INFORMATION_ORNATE
    local intricate = traitInfo == ITEM_TRAIT_INFORMATION_INTRICATE

    return not isSet and
           not crafted and
           (not researchable or LZD.vars.equip.researchable) and
           (not ornate or LZD.vars.equip.ornates) and
           (not intricate or LZD_ShouldDecon(LZD.vars.equip.intricates, craft)) and
           quality >= LZD.vars.equip.minQuality and
           quality <= LZD.vars.equip.maxQuality
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
