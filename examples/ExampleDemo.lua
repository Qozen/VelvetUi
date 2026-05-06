--!strict
--[[
    VelvetUI v2.1  ·  ExampleDemo.lua  ·  Enterprise Edition
    ────────────────────────────────────────────────────────────────
    Complete walkthrough of every feature, including:

      ✦ ErrorBus humanized error demonstrations
      ✦ All 5 severity levels for notifications
      ✦ SafeCall pattern for protecting your own logic
      ✦ Config persistence + corruption recovery
      ✦ Theme switcher with live preview
      ✦ Every element type in a real use-case context
      ✦ Dialog system (confirm, danger, info)
      ✦ Mobile-aware layout (keybinds auto-hide)

    EXECUTOR SETUP:
        1. Put init.lua (as VelvetUI.lua), THEMES.lua,
           Icon1.lua, Icon2.lua in the same folder.
        2. Run: loadstring(readfile("ExampleDemo.lua"))()

    STUDIO SETUP:
        Require modules normally. See README.md.
    ────────────────────────────────────────────────────────────────
--]]

-- ══════════════════════════════════════════════════════════════════
--  BOOTSTRAP — load in strict dependency order
--  Icons must be ready before Velvet initialises.
-- ══════════════════════════════════════════════════════════════════

-- Step 1: Icon atlas map (data only, no logic)
local Icon2 = loadstring(readfile("Icon2.lua"))()

-- Step 2: Icon renderer — inject the map
local Icons = loadstring(readfile("Icon1.lua"))()
Icons._init(Icon2)

-- Step 3: VelvetUI core — inject Icons
local Velvet = loadstring(readfile("VelvetUI.lua"))()(Icons)

-- Step 4: Extra theme palettes
local Themes = loadstring(readfile("THEMES.lua"))()
Themes.registerAll(Velvet)

-- ══════════════════════════════════════════════════════════════════
--  SERVICE SHORTCUTS
-- ══════════════════════════════════════════════════════════════════
local Players     = game:GetService("Players")
local Lighting    = game:GetService("Lighting")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════════
--  WINDOW
-- ══════════════════════════════════════════════════════════════════

local Window = Velvet:BuildWindow({
    Title = "VelvetUI v2.1",
    Icon  = "zap",
    Theme = "Midnight Velvet",
    Key   = "RightShift",   -- toggle open/close
})

-- Boot notification: confirms load was clean.
-- Severity = "success" → green accent bar.
Velvet:Whisper({
    Title    = "VelvetUI v2.1 Ready",
    Message  = "Enterprise edition loaded. All systems operational.",
    Icon     = "check-circle",
    Severity = "success",
    Duration = 3,
})

-- ══════════════════════════════════════════════════════════════════
--  TAB 1 — PLAYER
--  Real humanoid manipulation, wrapped with SafeCall so a missing
--  Character or Humanoid never crashes the UI or the script.
-- ══════════════════════════════════════════════════════════════════

local tabPlayer = Window:AddTab("Player", "user")

-- ── Movement ─────────────────────────────────────────────────────
local _grpMove = tabPlayer:Group("Movement")

tabPlayer:Slider("Walk Speed", 4, 250, 16, function(v: number)
    -- SafeCall: if the character doesn't exist, ErrorBus handles it
    -- and shows a friendly "Something's Not Loaded Yet" notification.
    Velvet:SafeCall("WalkSpeed", function()
        local char = LocalPlayer.Character
        if not char then error("Character not spawned") end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then error("No Humanoid in character") end
        hum.WalkSpeed = v
    end)
end, "walkspeed")

tabPlayer:Slider("Jump Power", 7, 350, 50, function(v: number)
    Velvet:SafeCall("JumpPower", function()
        local char = LocalPlayer.Character
        if not char then error("Character not spawned") end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then error("No Humanoid in character") end
        hum.JumpPower = v
    end)
end, "jumppower")

tabPlayer:Switch(
    "Infinite Jump",
    false,
    function(on: boolean)
        _G.VelvetDemo_InfJump = on
        -- Bonus: notify on enable so user knows it's active
        if on then
            Velvet:Whisper({
                Title    = "Infinite Jump Active",
                Message  = "You can now jump again mid-air. Forever.",
                Icon     = "arrow-up",
                Severity = "info",
                Duration = 2.5,
            })
        end
    end,
    "infjump",
    "Jump again mid-air, endlessly"
)

tabPlayer:Switch(
    "No Clip",
    false,
    function(on: boolean)
        _G.VelvetDemo_NoClip = on
        if on then
            Velvet:Whisper({
                Title    = "No Clip Active",
                Message  = "Walking through walls. Don't get lost.",
                Icon     = "box",
                Severity = "warn",
                Duration = 3,
            })
        end
    end,
    "noclip",
    "Phase through walls and parts"
)

-- ── Visual ───────────────────────────────────────────────────────
local _grpVis = tabPlayer:Group("Visual")

tabPlayer:Switch("Full Bright", false, function(on: boolean)
    Velvet:SafeCall("FullBright", function()
        Lighting.Brightness = on and 3 or 1
        Lighting.ClockTime  = on and 14 or 9
    end)
end, "fullbright", "Remove darkness from the world")

tabPlayer:Dropdown(
    "Field of View",
    {"60", "70", "75", "90", "100", "110", "120"},
    "70",
    function(val: string)
        Velvet:SafeCall("FOV", function()
            local cam = workspace.CurrentCamera
            if not cam then error("No camera") end
            cam.FieldOfView = tonumber(val) or 70
        end)
    end,
    "fov"
)

-- ── Keybinds ─────────────────────────────────────────────────────
local _grpKeys = tabPlayer:Group("Keybinds")

tabPlayer:Label(
    "Keybinds auto-hide on mobile — as they should.",
    "info",
    Color3.fromRGB(100, 160, 255)
)

tabPlayer:Keybind("Toggle Speed Boost", "E", function(key: string)
    Velvet:Whisper({
        Title    = "Speed Boost Toggled",
        Message  = "'" .. key .. "' fired. Apply your own logic here.",
        Icon     = "zap",
        Severity = "info",
        Duration = 2,
    })
end, "kb_speedboost")

tabPlayer:Keybind("Teleport Home", "H", function(_key: string)
    Velvet:SafeCall("TeleportHome", function()
        local char = LocalPlayer.Character
        if not char then error("No character to teleport") end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then error("HumanoidRootPart missing") end
        -- In a real script: root.CFrame = homeCFrame
        -- Here we just notify so the demo works in any game.
        Velvet:Whisper({
            Title    = "Teleport Ready",
            Message  = "HumanoidRootPart found. Add your destination.",
            Icon     = "map-pin",
            Severity = "success",
            Duration = 2,
        })
    end)
end, "kb_tphome")

-- ══════════════════════════════════════════════════════════════════
--  TAB 2 — VISUALS
-- ══════════════════════════════════════════════════════════════════

local tabVisuals = Window:AddTab("Visuals", "eye")

-- ── ESP ──────────────────────────────────────────────────────────
local _grpESP = tabVisuals:Group("ESP")

local _espEnabled = tabVisuals:Switch("Player ESP", false, function(on: boolean)
    _G.VelvetDemo_ESP = on
end, "esp_enabled", "Highlight players through walls")

tabVisuals:ColorSelect(
    "ESP Color",
    Color3.fromRGB(255, 80, 80),
    function(c: Color3)
        _G.VelvetDemo_ESPColor = c
        Velvet:Whisper({
            Title    = "ESP Color Updated",
            Message  = ("R%.0f  G%.0f  B%.0f"):format(c.R*255, c.G*255, c.B*255),
            Icon     = "palette",
            Severity = "info",
            Duration = 1.5,
        })
    end,
    "esp_color"
)

tabVisuals:Slider("ESP Distance", 50, 1000, 300, function(v: number)
    _G.VelvetDemo_ESPDist = v
end, "esp_dist")

tabVisuals:MultiDropdown(
    "ESP Info",
    {"Name", "Health", "Distance", "Weapon", "Team", "Ping"},
    {"Name", "Health"},
    function(selected: {string})
        _G.VelvetDemo_ESPInfo = selected
    end,
    "esp_info"
)

-- ── Environment ──────────────────────────────────────────────────
local _grpEnv = tabVisuals:Group("Environment")

tabVisuals:Switch("No Fog", false, function(on: boolean)
    Velvet:SafeCall("NoFog", function()
        Lighting.FogEnd   = on and 1e6 or 1000
        Lighting.FogStart = on and 9e5 or 0
    end)
end, "nofog", "Clear all distance fog")

tabVisuals:Dropdown(
    "Ambient Mood",
    {"Default", "Bright Day", "Deep Night", "Golden Hour", "Overcast"},
    "Default",
    function(val: string)
        Velvet:SafeCall("Ambient", function()
            local moods: {[string]: {number}} = {
                ["Default"]     = {0.5, 9},
                ["Bright Day"]  = {2.0, 14},
                ["Deep Night"]  = {0.0, 1},
                ["Golden Hour"] = {1.2, 18},
                ["Overcast"]    = {0.4, 10},
            }
            local m = moods[val]
            if m then
                Lighting.Brightness = m[1]
                Lighting.ClockTime  = m[2]
            end
        end)
    end,
    "ambient_mood"
)

tabVisuals:Slider("Global Brightness", 0, 5, 1, function(v: number)
    Velvet:SafeCall("Brightness", function()
        Lighting.Brightness = v
    end)
end, "brightness")

-- ── Camera ───────────────────────────────────────────────────────
local _grpCam = tabVisuals:Group("Camera")

tabVisuals:Switch("Cinematic Lock", false, function(on: boolean)
    _G.VelvetDemo_CineLock = on
    if on then
        Velvet:Whisper({
            Title    = "Cinematic Mode",
            Message  = "Camera locked for screenshots. Toggle again to release.",
            Icon     = "camera",
            Severity = "info",
            Duration = 3,
        })
    end
end, "cinelock", "Lock camera position for screenshots")

tabVisuals:Slider("Camera Sensitivity", 1, 20, 10, function(v: number)
    _G.VelvetDemo_CamSens = v
end, "cam_sens")

-- ══════════════════════════════════════════════════════════════════
--  TAB 3 — ERRORS  (Enterprise showcase)
--
--  This tab demonstrates the humanized error system.
--  Every button below triggers a REAL error through the correct
--  pipeline — you'll see both the friendly notification AND the
--  detailed console warn from ErrorBus.
--
--  This is intentional. Show your users kindness. Show developers
--  the truth. Both at the same time.
-- ══════════════════════════════════════════════════════════════════

local tabErrors = Window:AddTab("Errors", "alert-triangle")

-- Intro paragraph
tabErrors:Paragraph(
    "Humanized Error System",
    "Every error below is real — not faked. ErrorBus intercepts it, " ..
    "shows you a friendly message, and prints full details to the " ..
    "developer console. Open the Output tab to see both sides."
)

-- ── Error Types ──────────────────────────────────────────────────
local _grpErrTypes = tabErrors:Group("Simulate Error Types")

tabErrors:Label(
    "Each button fires a real error through ErrorBus.",
    "info",
    Color3.fromRGB(100, 160, 255)
)

-- HTTP not enabled — very common for new scripters
tabErrors:Button("Simulate: HTTP Disabled", function()
    Velvet:SafeCall("HTTP Demo", function()
        error("Http requests are not enabled. Enable via game settings.")
    end)
end)

-- Unauthorized API key — common for AI/webhook integrations
tabErrors:Button("Simulate: Invalid API Key", function()
    Velvet:SafeCall("API Auth Demo", function()
        error("Unauthorized: 401 — API key is invalid or has expired.")
    end)
end)

-- Rate limited — happens with rapid API calls
tabErrors:Button("Simulate: Rate Limited", function()
    Velvet:SafeCall("Rate Limit Demo", function()
        error("429 Too Many Requests — slow down your request rate.")
    end)
end)

-- Nil index — common beginner mistake
tabErrors:Button("Simulate: Nil Index", function()
    Velvet:SafeCall("Nil Access Demo", function()
        local t: any = nil
        local _ = t.SomeProperty  -- intentional nil index
    end)
end)

-- JSON decode failure — what happens with corrupt config
tabErrors:Button("Simulate: Corrupt Config", function()
    Velvet:SafeCall("JSON Parse Demo", function()
        local badJson = "{ this is not valid JSON |||"
        local HttpService = game:GetService("HttpService")
        HttpService:JSONDecode(badJson)  -- this will throw
    end)
end)

-- Server 500 — remote server problems
tabErrors:Button("Simulate: Server Error 500", function()
    Velvet:SafeCall("Server Error Demo", function()
        error("500 Internal Server Error — the remote server is having issues.")
    end)
end)

-- Timeout — slow connection or hanging request
tabErrors:Button("Simulate: Request Timeout", function()
    Velvet:SafeCall("Timeout Demo", function()
        error("Request timed out after 30 seconds.")
    end)
end)

-- ── Manual Report ─────────────────────────────────────────────────
local _grpManual = tabErrors:Group("Manual Error Reporting")

tabErrors:Paragraph(
    "ReportError API",
    "Use Velvet:ReportError(context, rawErrorString) to route your own " ..
    "module errors through the same humanized pipeline. Context is shown " ..
    "in the developer console to help locate the source."
)

tabErrors:Button("Manual Report: Webhook Failed", function()
    -- Simulate: your webhook module caught an error and wants to
    -- surface it to the user in a friendly way.
    Velvet:ReportError(
        "Webhook/send",
        "connect ECONNREFUSED — could not reach webhook endpoint."
    )
end)

tabErrors:Button("Manual Report: DataStore Down", function()
    Velvet:ReportError(
        "DataStore/save",
        "DataStore request failed: service is currently unavailable."
    )
end)

-- ── Severity Preview ─────────────────────────────────────────────
local _grpSeverity = tabErrors:Group("Notification Severity Levels")

tabErrors:Label(
    "All 4 severity levels — info, success, warn, danger.",
    "layers"
)

tabErrors:Button("Show: Info", function()
    Velvet:Whisper({
        Title    = "Just So You Know",
        Message  = "Something happened that you might want to know about.",
        Icon     = "info",
        Severity = "info",
        Duration = 4,
    })
end)

tabErrors:Button("Show: Success", function()
    Velvet:Whisper({
        Title    = "All Done",
        Message  = "That went exactly as planned. Enjoy it while it lasts.",
        Icon     = "check-circle",
        Severity = "success",
        Duration = 4,
    })
end)

tabErrors:Button("Show: Warning", function()
    Velvet:Whisper({
        Title    = "Heads Up",
        Message  = "Something's a little off. It won't break, but you should know.",
        Icon     = "alert-triangle",
        Severity = "warn",
        Duration = 4,
    })
end)

tabErrors:Button("Show: Danger", function()
    Velvet:Whisper({
        Title    = "Something Broke",
        Message  = "An operation failed. Check the developer console for details.",
        Icon     = "alert-circle",
        Severity = "danger",
        Duration = 5,
    })
end)

tabErrors:Button("Stack All 4 Severities", function()
    local notifs = {
        {Title="Info",    Message="Slot 1 — informational.",            Icon="info",          Severity="info"},
        {Title="Success", Message="Slot 2 — something worked.",         Icon="check-circle",  Severity="success"},
        {Title="Warning", Message="Slot 3 — something needs attention.",Icon="alert-triangle",Severity="warn"},
        {Title="Danger",  Message="Slot 4 — something actually failed.",Icon="alert-circle",  Severity="danger"},
    }
    for i, n in ipairs(notifs) do
        task.delay((i - 1) * 0.28, function()
            Velvet:Whisper(n)
        end)
    end
end)

-- ── Notification with Action ──────────────────────────────────────
local _grpAction = tabErrors:Group("Notification with Action")

tabErrors:Button("Recoverable Error + Action", function()
    -- The canonical pattern for recoverable errors:
    -- show what went wrong, offer a one-tap fix.
    Velvet:Whisper({
        Title    = "Couldn't Save Settings",
        Message  = "There was a problem writing to disk. Your changes will last this session only.",
        Icon     = "save",
        Severity = "warn",
        Duration = 8,
        Action   = {
            Text = "Retry",
            Callback = function()
                -- Simulate retry succeeding
                task.delay(0.5, function()
                    Velvet:Whisper({
                        Title    = "Save Successful",
                        Message  = "Settings saved to disk on retry.",
                        Icon     = "check",
                        Severity = "success",
                        Duration = 3,
                    })
                end)
            end,
        },
    })
end)

tabErrors:Button("Update Available Banner", function()
    Velvet:Whisper({
        Title    = "Update Available",
        Message  = "v2.2 is out with bug fixes and new themes.",
        Icon     = "download",
        Severity = "info",
        Duration = 10,
        Action   = {
            Text = "Install",
            Callback = function()
                Velvet:Whisper({
                    Title    = "Installing…",
                    Message  = "Reloading script in 3 seconds.",
                    Icon     = "refresh-cw",
                    Severity = "success",
                })
            end,
        },
    })
end)

-- ══════════════════════════════════════════════════════════════════
--  TAB 4 — MISC  (dialogs, theme, UI stress test)
-- ══════════════════════════════════════════════════════════════════

local tabMisc = Window:AddTab("Misc", "sparkles")

-- ── Dialogs ──────────────────────────────────────────────────────
local _grpDial = tabMisc:Group("Dialogs")

tabMisc:Label("Blocking modal dialogs for critical decisions.", "layers")

tabMisc:Button("Confirm Dialog", function()
    Window:Dialog({
        Title = "Apply Changes?",
        Body  = "This will apply your current settings to the session. You can undo by reloading.",
        Buttons = {
            {
                Text     = "Cancel",
                Color    = "muted",
                Callback = function()
                    Velvet:Whisper({Title = "Cancelled", Icon = "x", Severity = "info", Duration = 2})
                end,
            },
            {
                Text     = "Apply",
                Color    = "accent",
                Callback = function()
                    Velvet:Whisper({
                        Title    = "Changes Applied",
                        Message  = "Settings are active for this session.",
                        Icon     = "check",
                        Severity = "success",
                        Duration = 3,
                    })
                end,
            },
        },
    })
end)

tabMisc:Button("Danger Dialog", function()
    Window:Dialog({
        Title = "Wipe All Config?",
        Body  = "This deletes your saved settings permanently. There's no undo.",
        DismissOnOverlay = true,
        Buttons = {
            {Text = "Keep It",  Color = "muted"},
            {
                Text     = "Wipe It",
                Color    = "danger",
                Callback = function()
                    Velvet:Whisper({
                        Title    = "Config Wiped",
                        Message  = "All saved flags removed. Defaults loaded.",
                        Icon     = "trash-2",
                        Severity = "warn",
                        Duration = 4,
                    })
                end,
            },
        },
    })
end)

tabMisc:Button("3-Button Dialog", function()
    Window:Dialog({
        Title = "How do you want to proceed?",
        Body  = "Three options — each takes a different path. DismissOnOverlay is also enabled here.",
        DismissOnOverlay = true,
        Buttons = {
            {
                Text     = "Skip",
                Color    = "muted",
                Callback = function()
                    Velvet:Whisper({Title = "Skipped", Icon = "fast-forward", Severity = "info", Duration = 2})
                end,
            },
            {
                Text     = "Later",
                Color    = "accent",
                Callback = function()
                    Velvet:Whisper({Title = "Deferred", Icon = "clock", Severity = "warn", Duration = 2})
                end,
            },
            {
                Text     = "Now",
                Color    = "accent",
                Callback = function()
                    Velvet:Whisper({Title = "Going Now", Icon = "arrow-right", Severity = "success", Duration = 2})
                end,
            },
        },
    })
end)

-- ── Theme Switcher ────────────────────────────────────────────────
local _grpTheme = tabMisc:Group("Theme")

tabMisc:Paragraph(
    "Live Theme Switching",
    "Pick a theme below. The entire UI re-skins without a reload. " ..
    "All 7 palettes are registered: Midnight Velvet, Neon Abyss, Rose Gold, " ..
    "Ocean Depth, Crimson Night, Jade Forest, and Monochrome."
)

tabMisc:Dropdown(
    "Active Theme",
    Themes.list(),
    "Midnight Velvet",
    function(themeName: string)
        Window:Dress(themeName)
        Velvet:Whisper({
            Title    = "Theme Changed",
            Message  = themeName,
            Icon     = "paintbrush",
            Severity = "success",
            Duration = 2,
        })
    end,
    "active_theme"
)

-- ── Multi-select demo ────────────────────────────────────────────
local _grpMulti = tabMisc:Group("Multi-Select")

tabMisc:MultiDropdown(
    "Show Modules",
    {"Player", "Visuals", "Aimbot", "ESP", "Utility", "Config", "Debug"},
    {"Player", "Visuals"},
    function(selected: {string})
        local txt = #selected == 0 and "None" or table.concat(selected, ", ")
        Velvet:Whisper({
            Title    = "Active Modules",
            Message  = txt,
            Icon     = "layers",
            Severity = "info",
            Duration = 2,
        })
    end,
    "active_modules"
)

tabMisc:MultiDropdown(
    "Log Levels",
    {"Debug", "Info", "Warn", "Error", "Fatal"},
    {"Warn", "Error", "Fatal"},
    function(levels: {string})
        _G.VelvetDemo_LogLevels = levels
    end,
    "log_levels"
)

-- ── Stress Test ───────────────────────────────────────────────────
local _grpStress = tabMisc:Group("Stress Test")

tabMisc:Label("Rapid fire tests — AnimGuard and notif stacking.", "activity")

tabMisc:Button("Rapid Notif Stress (8 notifs)", function()
    -- Only 4 show at once. The rest are silently dropped by the queue cap.
    -- No errors, no ghost frames, no Z-fighting. Clean.
    local msgs = {
        "First notification fires.",
        "Second fires right after.",
        "Third, stacking nicely.",
        "Fourth fills the queue.",
        "Fifth gets dropped gracefully.",
        "Sixth — same.",
        "Seventh. Queue held firm.",
        "Eighth. Nothing crashed.",
    }
    for i, m in ipairs(msgs) do
        task.delay((i - 1) * 0.15, function()
            Velvet:Whisper({
                Title    = "Stress #" .. i,
                Message  = m,
                Icon     = "activity",
                Severity = i > 4 and "warn" or "info",
                Duration = 3,
            })
        end)
    end
end)

tabMisc:Button("Rapid Error Reports (5 types)", function()
    -- Every error goes through ErrorBus individually.
    -- None should block the others. All should surface cleanly.
    local errors = {
        {"Module A", "attempt to index nil value (field 'Config')"},
        {"Module B", "Http requests are not enabled"},
        {"Module C", "429 Too Many Requests"},
        {"Module D", "attempt to perform arithmetic on nil"},
        {"Module E", "DataStore request failed"},
    }
    for i, e in ipairs(errors) do
        task.delay((i - 1) * 0.4, function()
            Velvet:ReportError(e[1], e[2])
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════════
--  TAB 5 — CONFIG
--  Shows how persistence works, and how to make it visible.
-- ══════════════════════════════════════════════════════════════════

local tabConfig = Window:AddTab("Config", "save")

-- ── Persistence ───────────────────────────────────────────────────
local _grpPersist = tabConfig:Group("Persistence")

tabConfig:Paragraph(
    "How Flags Work",
    "Any element built with a `flag` string auto-saves on every change " ..
    "to velvet_config.json (executor) or in-memory (Studio). Call " ..
    "Velvet:LoadConfig() once after building all elements to restore state."
)

-- Persisted text field — changes survive script reload
tabConfig:TextField(
    "Display Name",
    "Enter your name…",
    function(text: string, _enter: boolean)
        _G.VelvetDemo_DisplayName = text
        if text ~= "" then
            Velvet:Whisper({
                Title    = "Name Saved",
                Message  = "'" .. text .. "' will persist across reloads.",
                Icon     = "user",
                Severity = "success",
                Duration = 2,
            })
        end
    end,
    "display_name"
)

-- Persisted switch
tabConfig:Switch(
    "Developer Mode",
    false,
    function(on: boolean)
        _G.VelvetDemo_DevMode = on
        if on then
            Velvet:Whisper({
                Title    = "Developer Mode On",
                Message  = "Extra debug output is now active in the console.",
                Icon     = "terminal",
                Severity = "warn",
                Duration = 3,
            })
        end
    end,
    "dev_mode",
    "Show verbose debug output"
)

tabConfig:Button("Load Config Now", function()
    Velvet:LoadConfig()
    Velvet:Whisper({
        Title    = "Config Loaded",
        Message  = "All registered flags restored from disk.",
        Icon     = "refresh-cw",
        Severity = "success",
        Duration = 3,
    })
end)

-- ── Corruption Recovery demo ──────────────────────────────────────
local _grpCorrupt = tabConfig:Group("Corruption Recovery")

tabConfig:Paragraph(
    "What Happens with Corrupt Config",
    "If velvet_config.json is malformed (incomplete write, manual edit gone wrong), " ..
    "VelvetUI v2.1 detects the bad JSON, resets to defaults, and notifies you — " ..
    "instead of silently loading garbage values or crashing on startup."
)

tabConfig:Button("Simulate Corrupt Config", function()
    -- This forces the error classification path for JSON errors.
    -- In a real scenario this fires automatically on load.
    Velvet:ReportError(
        "Config/hydrate",
        "JSON decode error: unexpected character at position 14 in config file"
    )
end)

-- ── Info ─────────────────────────────────────────────────────────
local _grpInfo = tabConfig:Group("System Info")

tabConfig:Label(
    "Version: VelvetUI v" .. Velvet:GetVersion(),
    "info",
    Color3.fromRGB(100, 160, 255)
)

tabConfig:Label(
    "File I/O: " .. (typeof(writefile) == "function" and "Executor — full persistence" or "Studio — in-memory only"),
    "hard-drive"
)

tabConfig:Label(
    "Device: " .. (UIS.TouchEnabled and not UIS.MouseEnabled and "Mobile" or "Desktop"),
    "monitor"
)

tabConfig:Button("Destroy Window", function()
    Window:Dialog({
        Title = "Remove the UI?",
        Body  = "This destroys the window entirely. Re-run the script to bring it back.",
        Buttons = {
            {Text = "Cancel", Color = "muted"},
            {
                Text     = "Destroy",
                Color    = "danger",
                Callback = function() Window:Destroy() end,
            },
        },
    })
end)

-- ══════════════════════════════════════════════════════════════════
--  LOAD CONFIG
--  Always call AFTER building all elements.
--  This restores persisted values to every element with a flag.
-- ══════════════════════════════════════════════════════════════════
Velvet:LoadConfig()
