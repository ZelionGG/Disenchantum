local AddonName, Engine = ...;

local LibStub = LibStub;
local AceLocale = LibStub:GetLibrary("AceLocale-3.0");
local L = AceLocale:NewLocale(AddonName, "itIT", false, false);
if not L then return end

-- Reference:
-- Some strings below are sourced from BlizzardInterfaceResources.
-- Source: https://github.com/Ketho/BlizzardInterfaceResources/blob/live/Resources/GlobalStrings/itIT.lua
-- @Translation Team: If you find a false positive (a string that should stay identical),
-- add `-- @no-translate` at the end of the line so the locale sync script ignores untranslated detection and stale marking when enUS changes.

