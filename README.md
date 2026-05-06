# VelvetUI v2.1 — Enterprise Edition

> Dark, premium, executor-first UI library for Roblox.  
> Built for scripts that ship to real users. Not for demos that live in a drawer.

---

## What's New in v2.1

| Feature | Description |
|---|---|
| **ErrorBus** | Centralized error pipeline. All errors flow through one place — humanized for users, detailed for developers. |
| **Humanized Notifications** | 20+ error patterns mapped to friendly messages. No raw Lua stack traces surface to end users. Ever. |
| **4 Severity Levels** | `info` / `success` / `warn` / `danger` — colour-coded accent bars and icons. |
| **AnimGuard** | Every tween checks `instance.Parent` before firing. No "cannot tween destroyed instance" spam. |
| **SafeCall API** | `Velvet:SafeCall(context, fn)` — wrap any callback, get humanized errors for free. |
| **ReportError API** | `Velvet:ReportError(context, rawErr)` — route your own module errors through the same pipeline. |
| **Config Hardened** | Corrupt JSON → reset to defaults + notify. Disk errors → in-memory fallback + console warn. |
| **Notification Actions** | One-tap action button on any notification (retry, install, dismiss, etc.). |
| **Switch Revert on Error** | If a Switch callback throws, the switch reverts to its previous state automatically. |
| **Dispatcher Guard** | Handler exceptions are caught per-entry — one bad handler can't stop all others from firing. |

---

## File Structure

```
VelvetUI/
  init.lua          ← Core library (load this as VelvetUI.lua)
  THEMES.lua        ← 6 extra colour palettes
  src/
    Icon1.lua       ← Lucide icon renderer
    Icon2.lua       ← Icon atlas map (data only)
  examples/
    BasicDemo.lua   ← Minimal starting point
    ExampleDemo.lua ← Full feature walkthrough + error showcase
```

---

## Quick Start (Executor)

```lua
-- 1. Load icons
local Icon2  = loadstring(readfile("Icon2.lua"))()
local Icons  = loadstring(readfile("Icon1.lua"))()
Icons._init(Icon2)

-- 2. Load VelvetUI
local Velvet = loadstring(readfile("VelvetUI.lua"))()(Icons)

-- 3. (Optional) Register extra themes
local Themes = loadstring(readfile("THEMES.lua"))()
Themes.registerAll(Velvet)

-- 4. Build your window
local Window = Velvet:BuildWindow({
    Title = "My Script",
    Icon  = "zap",
    Theme = "Midnight Velvet",
    Key   = "RightShift",
})

-- 5. Add a tab
local tab = Window:AddTab("Player", "user")
local _grp = tab:Group("Movement")

tab:Slider("Walk Speed", 4, 250, 16, function(v)
    Velvet:SafeCall("WalkSpeed", function()
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = v
    end)
end, "walkspeed")

-- 6. Load config LAST (after all elements)
Velvet:LoadConfig()
```

---

## Error Handling — The Right Way

### Pattern A: SafeCall (recommended)

Wraps any function. On success: returns the result. On failure: shows a humanized notification + logs full error to console.

```lua
-- Simple
Velvet:SafeCall("ModuleName", function()
    -- your risky code here
    someNilValue.Property = 5  -- user sees "Something's Not Loaded Yet"
end)

-- With return value
local result = Velvet:SafeCall("GetData", function()
    return HttpService:GetAsync("https://api.example.com/data")
end)
-- result is nil if the call failed (user was already notified)
if result then
    -- use result safely
end
```

### Pattern B: ReportError (from your own pcall)

When you're already catching errors yourself and just want them humanized:

```lua
local ok, err = pcall(function()
    -- your risky code
end)
if not ok then
    Velvet:ReportError("MyModule/load", tostring(err))
    -- user sees friendly message, console gets full err string
end
```

### Pattern C: Manual Whisper with Severity

For errors you already understand and want to communicate specifically:

```lua
Velvet:Whisper({
    Title    = "Couldn't Connect",
    Message  = "Check your internet connection and try again.",
    Icon     = "wifi-off",
    Severity = "danger",   -- red accent bar
    Duration = 5,
    Action   = {
        Text     = "Retry",
        Callback = function() attemptConnection() end,
    },
})
```

---

## Notification Severity Reference

| Severity | Colour | When to use |
|---|---|---|
| `"info"` | Blue | Background events, FYI messages, state changes |
| `"success"` | Green | Operation completed successfully |
| `"warn"` | Amber | User did something unexpected, gentle correction needed |
| `"danger"` | Red | Something failed, action may be required |

---

## Error Pattern Recognition

ErrorBus recognises these patterns and maps them to human messages:

| Pattern | User sees |
|---|---|
| `Http requests are not enabled` | "Enable HTTP requests in Game Settings to use this feature." |
| `Unauthorized` / `401` | "Your API key may be invalid or expired." |
| `429` | "Too many requests sent. Wait a moment before trying again." |
| `500` | "The remote server had an issue — not your fault." |
| `timeout` | "The request didn't finish in time. Check your connection." |
| `JSON` / `decode` | "Your config file might be malformed. Defaults were loaded." |
| `DataStore` | "Roblox DataStore isn't responding right now." |
| `attempt to index nil` | "A required part of the game wasn't ready. Try again." |
| `writefile` | "There was a problem writing to disk." |
| `No such file` | "No saved settings found — starting fresh with defaults." |
| *(anything else)* | "An unexpected error occurred. Details are in the developer console." |

All patterns also print the full raw error to the developer console via `warn()`.

---

## Full API Reference

### Velvet

```lua
-- Build a new draggable window
local win = Velvet:BuildWindow({
    Title: string?,     -- Window title
    Icon:  string?,     -- Lucide icon name for the topbar
    Theme: string?,     -- Theme name (default: "Midnight Velvet")
    Key:   string?,     -- KeyCode.Name to toggle open/close
})

-- Show a notification
Velvet:Whisper({
    Title:    string?,
    Message:  string?,
    Icon:     string?,            -- Lucide icon name
    Severity: "info"|"success"|"warn"|"danger"?,
    Duration: number?,            -- seconds (default 3.5)
    Action:   { Text: string, Callback: (() -> ())? }?,
})
Velvet:Notify(opts)               -- alias for Whisper

-- Show a modal dialog
Velvet:Dialog({
    Title:            string?,
    Body:             string?,
    DismissOnOverlay: boolean?,
    OnDismiss:        (() -> ())?,
    Buttons: {{
        Text:     string,
        Color:    "accent"|"danger"|"muted"?,
        Callback: (() -> ())?,
    }}?,
})

-- Humanized error handling
Velvet:SafeCall(context: string, fn: () -> any): any
Velvet:ReportError(context: string, rawErr: string)

-- Themes
Velvet:DefineTheme(name: string, palette: table)

-- Config
Velvet:LoadConfig()    -- call AFTER building all elements

-- Utility
Velvet:SetScaleMode("Auto"|"Desktop"|"Mobile")
Velvet:DestroyAll()
Velvet:GetVersion(): string
```

### Window

```lua
local tab = win:AddTab(name: string, icon: string?): Tab
win:Notify(opts)         -- same as Velvet:Whisper
win:Dialog(opts)         -- same as Velvet:Dialog
win:Show()
win:Hide()
win:Rename(title: string)
win:Dress(themeName: string)   -- live theme switch
win:Destroy()
```

### Tab

```lua
local grp = tab:Group(name: string): Group

-- Elements (all return a control object)
tab:Button(text, callback?)
tab:Switch(name, default?, callback?, flag?, description?)
tab:Slider(name, min?, max?, default?, callback?, flag?)
tab:TextField(name, placeholder?, callback?, flag?)
tab:Dropdown(name, options, default?, callback?, flag?)
tab:MultiDropdown(name, options, defaults?, callback?, flag?)
tab:ColorSelect(name, default?, callback?, flag?)
tab:Keybind(name, defaultKey?, callback?, flag?)
tab:Label(text, icon?, color?)
tab:Paragraph(title, body)
tab:Line()
tab:Spacer(height?)
```

### Element Controls

All elements return a control with at minimum:

```lua
ctrl.Show()
ctrl.Hide()
ctrl.Destroy()
```

Type-specific additions:

```lua
-- Switch
ctrl.SetState(bool)
ctrl.GetState(): boolean
ctrl.Flip()

-- Slider
ctrl.SetValue(n)
ctrl.GetValue(): number
ctrl.SetRange(min, max)

-- Button
ctrl.SetText(str)
ctrl.Lock()       -- disables + shakes on click
ctrl.Unlock()
ctrl.Flash(isError?: boolean)

-- TextField
ctrl.SetText(str)
ctrl.GetText(): string
ctrl.Clear()
ctrl.SetError(bool)   -- red stroke + shake animation

-- Dropdown / MultiDropdown
ctrl.Select(option)
ctrl.GetSelected()
ctrl.ReplaceOptions(list)

-- Keybind
ctrl.Bind(keyName)
ctrl.GetKey(): string
ctrl.Clear()

-- Label
ctrl.SetText(str)
ctrl.SetColor(Color3)

-- Paragraph
ctrl.Rewrite(title, body)
```

---

## Themes

```lua
local Themes = loadstring(readfile("THEMES.lua"))()
Themes.registerAll(Velvet)

-- Available names:
-- "Midnight Velvet" (built-in)
-- "Neon Abyss"
-- "Rose Gold"
-- "Ocean Depth"
-- "Crimson Night"
-- "Jade Forest"
-- "Monochrome"

-- Live switch at runtime:
Window:Dress("Neon Abyss")

-- Define a custom partial theme (missing tokens inherit from Midnight Velvet):
Velvet:DefineTheme("My Theme", {
    accent      = Color3.fromRGB(255, 120, 40),
    accentLight = Color3.fromRGB(255, 150, 70),
    accentDark  = Color3.fromRGB(200, 90, 20),
})
```

---

## Config / Persistence

Every element accepts an optional `flag` string as its last argument. When provided:

- Changes auto-save to `velvet_config.json` (executor) or memory (Studio)
- `Velvet:LoadConfig()` restores all flagged values at startup
- Corrupt config is detected, reset to `{}`, and the user is notified

```lua
-- The flag is always the last argument:
tab:Switch("Full Bright", false, myCallback, "fullbright")
tab:Slider("Walk Speed", 4, 250, 16, myCallback, "walkspeed")
tab:TextField("Name", "...", myCallback, "display_name")

-- Restore everything:
Velvet:LoadConfig()   -- call this ONCE, at the bottom of your script
```

---

## License

MIT — use it, modify it, ship it.

---

*VelvetUI Enterprise Edition — built to handle failure gracefully so your users never have to see it fail ugly.*
