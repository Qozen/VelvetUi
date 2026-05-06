--!strict
--[[
    VelvetUI v2.1  ·  BasicDemo.lua  ·  Enterprise Edition
    ────────────────────────────────────────────────────────────────
    Minimal script. Copy-paste starting point for your own project.

    Shows the three patterns you'll use 90% of the time:
      1. SafeCall — wrap risky logic, get humanized errors free
      2. Whisper  — show notifications with severity
      3. Flag     — persist any element's value across reloads

    SETUP:
        loadstring(readfile("BasicDemo.lua"))()
    ────────────────────────────────────────────────────────────────
--]]

-- ── Bootstrap ────────────────────────────────────────────────────
local Icon2  = loadstring(readfile("Icon2.lua"))()
local Icons  = loadstring(readfile("Icon1.lua"))()
Icons._init(Icon2)
local Velvet = loadstring(readfile("VelvetUI.lua"))()(Icons)

-- ── Window ───────────────────────────────────────────────────────
local Window = Velvet:BuildWindow({
    Title = "My Script",
    Icon  = "zap",
    Key   = "RightShift",
})

Velvet:Whisper({
    Title    = "Loaded",
    Message  = "My Script is ready.",
    Icon     = "check-circle",
    Severity = "success",
    Duration = 2.5,
})

-- ── Tab ───────────────────────────────────────────────────────────
local tab = Window:AddTab("Main", "home")

local _group = tab:Group("Player")

-- Pattern 1: SafeCall wraps any risky code.
-- If the character isn't loaded, user sees a friendly message.
-- You see the real error in console.
tab:Slider("Walk Speed", 4, 250, 16, function(v: number)
    Velvet:SafeCall("WalkSpeed", function()
        local char = game.Players.LocalPlayer.Character
        if not char then error("Character not loaded") end
        char.Humanoid.WalkSpeed = v
    end)
end, "walkspeed")

-- Pattern 2: Notifications with intent.
-- Severity tells the user how to feel about what just happened.
tab:Switch("Infinite Jump", false, function(on: boolean)
    _G.InfJump = on
    Velvet:Whisper({
        Title    = on and "Infinite Jump On" or "Infinite Jump Off",
        Icon     = "arrow-up",
        Severity = on and "success" or "info",
        Duration = 2,
    })
end, "infjump", "Jump again mid-air")

-- Pattern 3: Flag = auto-save. "display_name" writes to velvet_config.json.
-- Velvet:LoadConfig() at the bottom restores it on next load.
tab:TextField("Username", "Your name…", function(text: string)
    _G.DisplayName = text
end, "display_name")

tab:Button("Test Error Handling", function()
    -- This intentionally errors. Watch the friendly notification appear,
    -- then check the console for the full technical detail.
    Velvet:SafeCall("TestError", function()
        error("attempt to index nil value (global 'MyModule')")
    end)
end)

-- Always call LoadConfig AFTER all elements are built.
Velvet:LoadConfig()
