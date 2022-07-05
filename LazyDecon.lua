local LAM2 = LibAddonMenu2

local LZD = {
    name = "LazyDecon",
    version = "0.1"
}

-----------------------------------------------------------------------------
-- Settings UI Panel
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- What to Deconstruct
-----------------------------------------------------------------------------
local function LZD_ShouldDeconEquipment(link)
    local isSet, setName, _, _, _, setId = GetItemLinkSetInfo(link, false)
    local researchable = CanItemLinkBeTraitResearched(link)
    local quality = GetItemLinkQuality(link)
    local crafted = IsItemLinkCrafted(link)
    local traitInfo = GetItemTraitInformationFromItemLink(link)

    local ornate = traitInfo == ITEM_TRAIT_INFORMATION_ORNATE
    local intricate = traitInfo == ITEM_TRAIT_INFORMATION_INTRICATE

    return not isSet and
           not researchable and
           not crafted and
           quality ~= ITEM_FUNCTIONAL_QUALITY_LEGENDARY
end

local function LZD_ShouldDeconGlyphs(link)
    local quality = GetItemLinkQuality(link)

    return quality == ITEM_FUNCTIONAL_QUALITY_TRASH or
           quality == ITEM_FUNCTIONAL_QUALITY_NORMAL or
           quality == ITEM_FUNCTIONAL_QUALITY_MAGIC or
           quality == ITEM_FUNCTIONAL_QUALITY_ARCANE or
           quality == ITEM_FUNCTIONAL_QUALITY_ARTIFACT
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
    LZD.savedSound = SOUNDS.SMITHING_ITEM_TO_EXTRACT_PLACED
    LZD_RegisterHooks(UNIVERSAL_DECONSTRUCTION.deconstructionPanel.inventory)
    LZD_RegisterHooks(SMITHING.deconstructionPanel.inventory)
    EVENT_MANAGER:RegisterForEvent(LZD.name, EVENT_CRAFTING_STATION_INTERACT, LZD_SwitchDeconScreen)
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
