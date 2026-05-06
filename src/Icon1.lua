--[[
    Velvet UI — Icon1.lua
    Lucide icon atlas renderer. Executor + Studio compatible.

    EXECUTOR USAGE (primary):
        local icon2 = loadstring(readfile("VelvetUi/src/Icon2.lua"))()
        local Icons = loadstring(readfile("VelvetUi/src/Icon1.lua"))()
        Icons._init(icon2)
        Icons.Apply(myImageLabel, "home", { tint = Color3.new(1,1,1) })

    STUDIO USAGE (secondary):
        local Icons = require(script.Parent.Icon1)
        Icons._init(require(script.Parent.Icon2))

    MIT License
--]]

local Icons = {}

-- ── Atlas asset IDs (4 sheets) ────────────────────────────────────────────────

local AtlasIds = {
    "rbxassetid://103814300206079",
    "rbxassetid://110883881134391",
    "rbxassetid://85588482759059",
    "rbxassetid://106285411531362",
}

-- ── State ─────────────────────────────────────────────────────────────────────

local Map   = nil  -- injected via Icons._init(iconMap)
local Cache = setmetatable({}, { __mode = "k" })  -- weak: auto-GC with instances

-- ── Init ──────────────────────────────────────────────────────────────────────

-- Must be called before any Apply/Get/Exists calls.
-- Executor: pass Icon2 table loaded via loadstring.
-- Studio:   pass require(script.Parent.Icon2).
function Icons._init(iconMap)
    assert(type(iconMap) == "table", "[Velvet Icons] _init expects a table from Icon2.lua")
    Map = iconMap
end

-- ── Internal ──────────────────────────────────────────────────────────────────

local function isValidGui(obj)
    return typeof(obj) == "Instance"
        and (obj:IsA("ImageLabel") or obj:IsA("ImageButton"))
end

local function resolve(iconName)
    if not Map then
        warn("[Velvet Icons] Icons._init(map) not called yet.")
        return nil
    end
    local data = Map[iconName]
    if not data then
        warn("[Velvet Icons] Icon not found:", iconName)
        return nil
    end
    local atlas = AtlasIds[data.atlas + 1]
    if not atlas then
        warn("[Velvet Icons] Atlas sheet out of range:", data.atlas)
        return nil
    end
    return data, atlas
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Apply a Lucide icon to an ImageLabel or ImageButton.
-- @param guiObject  ImageLabel | ImageButton
-- @param iconName   string Lucide name e.g. "home", "x", "settings-2"
-- @param options    optional { tint: Color3, size: bool }
function Icons.Apply(guiObject, iconName, options)
    if not isValidGui(guiObject) then
        warn("[Velvet Icons] Expected ImageLabel or ImageButton")
        return
    end
    local data, atlas = resolve(iconName)
    if not data then return end

    local cached = Cache[guiObject]
    if cached and cached.name == iconName and cached.atlas == atlas then return end

    guiObject.Image             = atlas
    guiObject.ImageRectOffset   = Vector2.new(data.x, data.y)
    guiObject.ImageRectSize     = Vector2.new(data.w, data.h)
    guiObject.ScaleType         = Enum.ScaleType.Fit
    guiObject.BackgroundTransparency = 1

    if options and options.tint then
        guiObject.ImageColor3 = options.tint
    end
    if options and options.size == true then
        guiObject.Size = UDim2.fromOffset(data.w, data.h)
    end

    Cache[guiObject] = { name = iconName, atlas = atlas }
end

function Icons.Get(iconName)
    return Map and Map[iconName] or nil
end

function Icons.Exists(iconName)
    return Map ~= nil and Map[iconName] ~= nil
end

function Icons.Count()
    if not Map then return 0 end
    local n = 0
    for _ in pairs(Map) do n += 1 end
    return n
end

function Icons.SetTint(guiObject, color)
    if isValidGui(guiObject) then guiObject.ImageColor3 = color end
end

function Icons.Clear(guiObject)    Cache[guiObject] = nil end
function Icons.ClearAll()          for k in pairs(Cache) do Cache[k] = nil end end

return Icons
