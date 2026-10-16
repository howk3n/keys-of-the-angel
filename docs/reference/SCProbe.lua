-- THROWAWAY spike probe for StreetCred. Delete after use.
local PREFIX, CHANNEL = "SCProbe", "SCProbeTest"
local log = {}
local function out(...)
  local s = strjoin(" ", tostringall(...))
  log[#log + 1] = date("%H:%M:%S ") .. s
  print("|cff33ff99SCProbe|r " .. s)
  SCProbeDB = SCProbeDB or {}
  SCProbeDB.log = log
end

local function has(path)
  local t = _G
  for part in path:gmatch("[^%.]+") do
    if type(t) ~= "table" then return false end
    t = t[part]
  end
  return t ~= nil
end

local f = CreateFrame("Frame")

local function checkEvent(ev)
  if C_EventUtils and C_EventUtils.IsEventValid then
    return C_EventUtils.IsEventValid(ev)
  end
  return (pcall(f.RegisterEvent, f, ev))
end

local function runChecks()
  log = {}
  out("build", GetBuildInfo())
  out("WOW_PROJECT_ID", WOW_PROJECT_ID, "CAMELOT", WOW_PROJECT_CAMELOT, "lua", _VERSION)
  for _, fn in ipairs({
    "C_ChatInfo.RegisterAddonMessagePrefix", "C_ChatInfo.SendAddonMessage",
    "C_ChatInfo.SendAddonMessageLogged", "C_ChatInfo.InChatMessagingLockdown",
    "JoinTemporaryChannel", "JoinChannelByName", "GetChannelName", "LeaveChannelByName",
    "C_Secrets", "issecretvalue", "C_FriendList.GetNumFriends", "C_FriendList.GetFriendInfoByIndex",
    "GetNumGuildMembers", "GetGuildRosterInfo", "C_GuildInfo.GuildRoster",
    "GetNumGroupMembers", "IsInInstance", "GetInstanceInfo", "UnitFullName",
    "GetNormalizedRealmName", "UnitLevel", "UnitGUID", "C_PartyInfo.GetLootMethod",
    "GetLootMethod", "C_LootHistory", "C_Timer.After", "C_EventUtils.IsEventValid",
    "C_EncodingUtil", "C_EncodingUtil.CompressString", "C_EncodingUtil.SerializeCBOR",
    "Settings.RegisterCanvasLayoutCategory",
  }) do
    out(has(fn) and "OK  " or "MISSING", fn)
  end
  for _, ev in ipairs({
    "GROUP_ROSTER_UPDATE", "GROUP_LEFT", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "TRADE_SHOW", "TRADE_CLOSED", "TRADE_ACCEPT_UPDATE", "UI_INFO_MESSAGE",
    "CHAT_MSG_ADDON", "CHAT_MSG_ADDON_LOGGED", "CHAT_MSG_LOOT", "START_LOOT_ROLL",
    "LOOT_HISTORY_UPDATE_DROP", "ENCOUNTER_START", "ENCOUNTER_END",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "CHANNEL_UI_UPDATE",
    "CHAT_MSG_CHANNEL_NOTICE", "ADDON_RESTRICTION_STATE_CHANGED",
  }) do
    out(checkEvent(ev) and "EVT " or "NOEVT", ev)
  end
  local ok, res = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
  out("RegisterPrefix", ok, res)
end

local function sendTests()
  local me = UnitName("player")
  local tries = { { "WHISPER", me } }
  if IsInGuild() then tries[#tries + 1] = { "GUILD" } end
  if IsInGroup() then tries[#tries + 1] = { IsInRaid() and "RAID" or "PARTY" } end
  local id = GetChannelName(CHANNEL)
  if id and id > 0 then tries[#tries + 1] = { "CHANNEL", id } end
  for _, t in ipairs(tries) do
    local msg = t[1] .. ":" .. string.rep("x", 200)
    local ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, t[1], t[2])
    out("SEND", t[1], tostring(t[2]), ok, res)
  end
  local ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, string.rep("y", 300), "WHISPER", me)
  out("SEND oversize(300)", ok, res)
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CHAT_MSG_ADDON")
pcall(f.RegisterEvent, f, "CHAT_MSG_CHANNEL_NOTICE")
f:SetScript("OnEvent", function(_, ev, ...)
  if ev == "PLAYER_ENTERING_WORLD" then
    f:UnregisterEvent("PLAYER_ENTERING_WORLD")
    runChecks()
    local ok, a, b = pcall(JoinTemporaryChannel, CHANNEL)
    out("JoinTemporaryChannel", ok, a, b)
    C_Timer.After(5, function()
      out("channel id after join", GetChannelName(CHANNEL))
      sendTests()
    end)
  elseif ev == "CHAT_MSG_ADDON" then
    local prefix, msg, channel, sender = ...
    if prefix == PREFIX then out("RECV", channel, sender, #msg) end
  elseif ev == "CHAT_MSG_CHANNEL_NOTICE" then
    local text, _, _, chan = ...
    out("CHANNEL_NOTICE", text, chan)
  end
end)

SLASH_SCPROBE1 = "/scprobe"
SlashCmdList.SCPROBE = function(arg)
  if arg == "send" then sendTests() return end
  local target = "target"
  if UnitExists(target) then
    local n, r = UnitFullName(target)
    out("target", n, r, "level", UnitLevel(target), "player?", UnitIsPlayer(target),
        "secretName?", issecretvalue and issecretvalue(n) or "n/a",
        "inInstance", IsInInstance(),
        "lockdown", C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown())
  else
    runChecks()
  end
end
