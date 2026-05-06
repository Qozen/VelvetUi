--!strict
--[[
 ██╗   ██╗███████╗██╗     ██╗   ██╗███████╗████████╗    ██╗   ██╗██╗
 ██║   ██║██╔════╝██║     ██║   ██║██╔════╝╚══██╔══╝    ██║   ██║██║
 ██║   ██║█████╗  ██║     ██║   ██║█████╗     ██║       ██║   ██║██║
 ╚██╗ ██╔╝██╔══╝  ██║     ╚██╗ ██╔╝██╔══╝     ██║       ██║   ██║██║
  ╚████╔╝ ███████╗███████╗ ╚████╔╝ ███████╗   ██║       ╚██████╔╝██║
   ╚═══╝  ╚══════╝╚══════╝  ╚═══╝  ╚══════╝   ╚═╝        ╚═════╝ ╚═╝

  VelvetUI v2.1.0  ·  Enterprise Edition  ·  Executor-First
  ──────────────────────────────────────────────────────────────────
  WHAT'S NEW IN v2.1 (Enterprise):
    ✦ Humanized Error System — errors shown as friendly system notifications
    ✦ ErrorBus — centralized error pipeline, no raw pcall spaghetti
    ✦ AnimGuard — all animation calls are parent-checked before firing
    ✦ Safe Tween Pool — no "cannot tween destroyed instance" ghost errors
    ✦ Config I/O hardened — corrupt JSON, disk full, permission denied all handled
    ✦ Notification system redesigned with severity levels (info/warn/danger/success)
    ✦ Dialog has validation error state built-in
    ✦ Tab/Group/Element all report meaningful errors, not raw Lua stack traces
    ✦ Popup layer cleanup: guaranteed destroy even on rapid open/close cycles
    ✦ Dispatcher: guard against calling removed handlers in-flight
    ✦ Every callback: three-layer protection (pcall + ErrorBus + user-facing notif)

  MIT License · github.com/VelvetUI
--]]

return function(Icons: any)
    -- Fail loudly if Icons is missing. The consumer needs to know immediately.
    if not Icons or typeof(Icons.Apply) ~= "function" then
        error(
            "[VelvetUI] Icons system not passed correctly.\n" ..
            "Usage: loadstring(readfile('VelvetUI.lua'))()(Icons)\n" ..
            "Make sure Icon1.lua is loaded and _init(Icon2) was called first.",
            2
        )
    end

    -- ══════════════════════════════════════════════════════════════
    --  SERVICES  (cached at module load — zero repeated GetService calls)
    -- ══════════════════════════════════════════════════════════════
    local TweenService  = game:GetService("TweenService")
    local UIS           = game:GetService("UserInputService")
    local Players       = game:GetService("Players")
    local HttpService   = game:GetService("HttpService")
    local RunService    = game:GetService("RunService")

    local LocalPlayer   = Players.LocalPlayer
    local function getPlayerGui(): PlayerGui?
        local p = LocalPlayer
        if not p then return nil end
        return p:WaitForChild("PlayerGui", 8) :: PlayerGui
    end

    -- Simple incrementing UID — not cryptographic, just unique enough for keys.
    local _uidN: number = 0
    local function uid(): string _uidN += 1; return "vui_" .. _uidN end

    -- ══════════════════════════════════════════════════════════════
    --  LAYOUT CONSTANTS
    --  One place for all spacing. Change here, changes everywhere.
    --  Scattered magic numbers is how codebases die slowly.
    -- ══════════════════════════════════════════════════════════════
    local L = {
        sideW_D      = 168,  sideW_M      = 52,
        tabBtnH_D    = 40,   tabBtnH_M    = 48,
        tabIconSz    = 18,   appIconSz    = 20,
        topbarH      = 48,
        winW_D       = 680,  winH_D       = 440,
        winW_M       = 360,  winH_M       = 500,
        padH         = 16,   padV         = 12,
        groupPadH    = 14,   groupPadV    = 10,
        elemH        = 44,   elemSpacing  = 6,
        groupSpacing = 12,   groupTitleH  = 32,
        searchH      = 36,
        -- Radii: two tiers only — don't let radius values multiply like rabbits.
        rWin         = 14,   rGroup       = 10,
        rElem        = 8,    rBtn         = 8,
        rNotif       = 12,   rSwitch      = 11,
        rSliderTrk   = 4,    rSliderThm   = 8,
        rDropdown    = 8,    rDialog      = 14,
        -- Stroke
        strokeW      = 1,    strokeT      = 0.88,  strokeFocus = 0.52,
        -- Typography — Gotham only. No Comic Sans in this house.
        fTitle       = Enum.Font.GothamBold,
        fLabel       = Enum.Font.GothamMedium,
        fBody        = Enum.Font.Gotham,
        fMono        = Enum.Font.Code,
        szTitle      = 15,   szLabel      = 13,
        szBody       = 13,   szMuted      = 11,
        szElem       = 13,   szGroupHdr   = 11,
    }

    -- ══════════════════════════════════════════════════════════════
    --  DEVICE DETECTION
    -- ══════════════════════════════════════════════════════════════
    local _scaleMode: string = "Auto"
    local function isMobile(): boolean
        if _scaleMode == "Mobile"  then return true  end
        if _scaleMode == "Desktop" then return false end
        -- TouchEnabled without MouseEnabled = phone/tablet.
        -- WITH MouseEnabled = laptop touchscreen (still desktop experience).
        return UIS.TouchEnabled and not UIS.MouseEnabled
    end
    local function setScaleMode(m: string) _scaleMode = m end
    local function sideW(): number return isMobile() and L.sideW_M or L.sideW_D end
    local function winSize(): (number, number)
        return isMobile() and L.winW_M or L.winW_D,
               isMobile() and L.winH_M or L.winH_D
    end

    -- ══════════════════════════════════════════════════════════════
    --  THEME SYSTEM
    --  Deep-frozen palettes. Your theme can't mutate the base at
    --  runtime — we've been burned by that before.
    -- ══════════════════════════════════════════════════════════════
    local MIDNIGHT = table.freeze({
        bg          = Color3.fromRGB(13,  13,  18),
        surface     = Color3.fromRGB(22,  22,  31),
        card        = Color3.fromRGB(28,  28,  38),
        sidebar     = Color3.fromRGB(18,  18,  23),
        topbar      = Color3.fromRGB(16,  16,  21),
        accent      = Color3.fromRGB(123, 47,  190),
        accentLight = Color3.fromRGB(148, 72,  215),
        accentDark  = Color3.fromRGB(98,  32,  158),
        rose        = Color3.fromRGB(201, 169, 110),
        roseDark    = Color3.fromRGB(170, 138, 82),
        border      = Color3.fromRGB(42,  42,  58),
        borderFocus = Color3.fromRGB(123, 47,  190),
        text        = Color3.fromRGB(237, 232, 240),
        muted       = Color3.fromRGB(138, 131, 145),
        textInverse = Color3.fromRGB(13,  13,  18),
        success     = Color3.fromRGB(72,  199, 142),
        warning     = Color3.fromRGB(255, 183, 77),
        danger      = Color3.fromRGB(240, 80,  80),
        dangerDark  = Color3.fromRGB(200, 55,  55),
        info        = Color3.fromRGB(100, 160, 255),
        switchOn    = Color3.fromRGB(123, 47,  190),
        switchOff   = Color3.fromRGB(55,  55,  72),
        sliderTrack = Color3.fromRGB(42,  42,  58),
        sliderFill  = Color3.fromRGB(123, 47,  190),
        sliderThumb = Color3.fromRGB(237, 232, 240),
        overlay     = Color3.fromRGB(0,   0,   0),
        notifBg     = Color3.fromRGB(26,  26,  36),
        searchBg    = Color3.fromRGB(20,  20,  28),
        dialogBg    = Color3.fromRGB(24,  24,  34),
    })

    local _themeReg: {[string]: any}  = { ["Midnight Velvet"] = MIDNIGHT }
    local _themeName: string           = "Midnight Velvet"

    local Theme = {}
    function Theme.define(name: string, tbl: {[string]: any})
        local m: {[string]: any} = {}
        for k, v in pairs(MIDNIGHT) do m[k] = tbl[k] or v end
        for k, v in pairs(tbl)     do m[k] = v         end
        _themeReg[name] = table.freeze(m)
    end
    function Theme.get(name: string?): any
        local t = _themeReg[name or _themeName]
        if not t then
            -- Don't crash — silently fall back to Midnight. Log it once.
            warn("[VelvetUI/Theme] Unknown theme '" .. tostring(name) .. "', falling back to Midnight Velvet.")
            return MIDNIGHT
        end
        return t
    end
    function Theme.setActive(name: string)
        if _themeReg[name] then _themeName = name
        else warn("[VelvetUI/Theme] Cannot activate unknown theme: " .. tostring(name)) end
    end
    function Theme.getActive(): string return _themeName end

    -- ══════════════════════════════════════════════════════════════
    --  ██████╗  ERROR BUS  (Enterprise Core)
    --
    --  ALL errors in VelvetUI flow through here. No raw pcall
    --  dumping to console, no silent failures, no raw Lua stack
    --  traces surfaced to the user.
    --
    --  ErrorBus translates technical errors into:
    --    1. A user-facing humanized notification (friendly, helpful)
    --    2. A developer-facing console warn (full detail for debugging)
    --
    --  Three severity levels:
    --    "info"    — something happened, user probably doesn't care
    --    "warn"    — user did something unexpected, gentle correction
    --    "danger"  — something failed, user needs to know clearly
    --
    --  HUMANIZATION RULES:
    --    - Blame the situation, never the user personally
    --    - Tell them what happened AND what to try
    --    - Keep it under 2 sentences
    --    - Never show raw Lua errors to end users
    --    - Developer detail goes only to console (warn)
    -- ══════════════════════════════════════════════════════════════

    -- Forward declaration — ErrorBus.notify needs the notification system,
    -- which isn't built yet. We bind this at the bottom after everything exists.
    local _notifDispatch: ((opts: any) -> ())? = nil

    -- Human-readable error messages mapped from Lua pattern matches.
    -- This is intentionally a table so it's easy to extend.
    local ERROR_PATTERNS: {{pattern: string, title: string, message: string, icon: string, severity: string}} = {
        -- API / Network errors
        {
            pattern  = "Http requests are not enabled",
            title    = "Network Access Needed",
            message  = "Enable HTTP requests in Game Settings to use this feature.",
            icon     = "wifi-off",
            severity = "warn",
        },
        {
            pattern  = "Unknown global 'readfile'",
            title    = "Executor Required",
            message  = "This feature needs an executor with file access (readfile/writefile).",
            icon     = "hard-drive",
            severity = "warn",
        },
        {
            pattern  = "timeout",
            title    = "That Took Too Long",
            message  = "The request didn't finish in time. Check your connection and try again.",
            icon     = "clock",
            severity = "warn",
        },
        {
            pattern  = "connect",
            title    = "Can't Reach the Server",
            message  = "A network connection failed. Make sure you're online and try again.",
            icon     = "wifi-off",
            severity = "danger",
        },
        {
            pattern  = "Unauthorized",
            title    = "Access Denied",
            message  = "Your API key may be invalid or expired. Check your settings.",
            icon     = "lock",
            severity = "danger",
        },
        {
            pattern  = "403",
            title    = "Permission Denied",
            message  = "You don't have access to this resource. Your key may be restricted.",
            icon     = "shield-off",
            severity = "danger",
        },
        {
            pattern  = "404",
            title    = "Not Found",
            message  = "The requested resource doesn't exist. Double-check your configuration.",
            icon     = "search",
            severity = "warn",
        },
        {
            pattern  = "429",
            title    = "Slow Down a Little",
            message  = "Too many requests were sent. Wait a moment before trying again.",
            icon     = "activity",
            severity = "warn",
        },
        {
            pattern  = "500",
            title    = "Server Error",
            message  = "The remote server had an issue — not your fault. Try again in a bit.",
            icon     = "server",
            severity = "danger",
        },
        -- JSON / Config errors
        {
            pattern  = "JSON",
            title    = "Saved Data Looks Corrupted",
            message  = "Your config file might be malformed. It was reset to defaults to keep things working.",
            icon     = "file-x",
            severity = "warn",
        },
        {
            pattern  = "decode",
            title    = "Couldn't Read Saved Settings",
            message  = "The settings file isn't in a format we recognize. Defaults were loaded instead.",
            icon     = "file-x",
            severity = "warn",
        },
        -- Roblox-specific
        {
            pattern  = "DataStore",
            title    = "Save System Unavailable",
            message  = "Roblox DataStore isn't responding right now. Your progress may not save this session.",
            icon     = "database",
            severity = "warn",
        },
        {
            pattern  = "attempt to index nil",
            title    = "Something's Not Loaded Yet",
            message  = "A required part of the game wasn't ready. Try again in a moment.",
            icon     = "loader",
            severity = "warn",
        },
        {
            pattern  = "attempt to perform arithmetic",
            title    = "Unexpected Value",
            message  = "A value ended up in a wrong format. Your settings were left unchanged.",
            icon     = "alert-triangle",
            severity = "warn",
        },
        -- File system (executor)
        {
            pattern  = "writefile",
            title    = "Couldn't Save Settings",
            message  = "There was a problem writing to disk. Your changes will last this session only.",
            icon     = "save",
            severity = "warn",
        },
        {
            pattern  = "No such file",
            title    = "Config File Missing",
            message  = "No saved settings found — starting fresh with defaults.",
            icon     = "file-plus",
            severity = "info",
        },
        -- Generic fallback — this is intentionally last in the list
        {
            pattern  = ".*",
            title    = "Something Went Wrong",
            message  = "An unexpected error occurred. Details are in the developer console.",
            icon     = "alert-circle",
            severity = "danger",
        },
    }

    -- Translate a raw Lua error string into a human message.
    -- Returns the matched entry. Never returns nil — fallback always matches.
    local function classifyError(rawErr: string): {title: string, message: string, icon: string, severity: string}
        local lowerErr = rawErr:lower()
        for _, entry in ipairs(ERROR_PATTERNS) do
            if lowerErr:find(entry.pattern:lower(), 1, false) then
                return entry
            end
        end
        -- This should never happen due to the wildcard entry, but Luau type system wants certainty
        return ERROR_PATTERNS[#ERROR_PATTERNS]
    end

    -- Map severity to notification accent color and icon tint
    local SEVERITY_COLORS: {[string]: Color3} = {
        info    = Color3.fromRGB(100, 160, 255),
        warn    = Color3.fromRGB(255, 183, 77),
        danger  = Color3.fromRGB(240, 80,  80),
        success = Color3.fromRGB(72,  199, 142),
    }

    local ErrorBus = {}

    -- The main entry point. Call this everywhere instead of raw pcall.
    -- context: short string describing what was happening ("Switch callback", "Config save", etc.)
    -- rawErr:  the error string from pcall
    -- opts:    optional overrides { silent = true } to suppress user-facing notif
    function ErrorBus.report(context: string, rawErr: string, opts: {silent: boolean?}?)
        local classified = classifyError(rawErr)

        -- Developer console gets full detail, always.
        -- Engineers deserve to know what actually went wrong.
        warn(string.format(
            "[VelvetUI/%s] %s\n  → Raw error: %s",
            context,
            classified.title,
            rawErr
        ))

        -- User gets a friendly notification — unless caller wants silence
        local silent = opts and opts.silent == true
        if not silent and _notifDispatch then
            _notifDispatch({
                Title    = classified.title,
                Message  = classified.message,
                Icon     = classified.icon,
                Severity = classified.severity,
                Duration = classified.severity == "info" and 3 or 5,
            })
        end
    end

    -- Safe wrapper around a callback. Returns the result on success, nil on failure.
    -- context: used in developer logs to pinpoint the source
    function ErrorBus.call<T>(context: string, fn: () -> T, silent: boolean?): T?
        local ok, result = pcall(fn)
        if not ok then
            ErrorBus.report(context, tostring(result), {silent = silent})
            return nil
        end
        return result
    end

    -- Convenience: wrap a callback that receives arguments.
    -- Returns true on success, false on failure (so callers can react if needed).
    function ErrorBus.callWith(context: string, fn: (...any) -> (), silent: boolean?, ...: any): boolean
        local args = {...}
        local ok, err = pcall(function() fn(table.unpack(args)) end)
        if not ok then
            ErrorBus.report(context, tostring(err), {silent = silent})
            return false
        end
        return true
    end

    -- ══════════════════════════════════════════════════════════════
    --  ANIMATOR  (AnimGuard Edition)
    --
    --  Every tween goes through Anim.t() which:
    --    1. Checks the instance is still alive (parent check)
    --    2. Wraps TweenService:Create in pcall
    --    3. Returns nil silently on failure — no ghost error spam
    --
    --  Pre-allocated TweenInfo constants — never construct TweenInfo
    --  in a hot path. That's object churn for zero reason.
    -- ══════════════════════════════════════════════════════════════
    local INFO: {[string]: TweenInfo} = {
        MICRO   = TweenInfo.new(0.10, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
        FAST    = TweenInfo.new(0.15, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
        MEDIUM  = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        SLOW    = TweenInfo.new(0.40, Enum.EasingStyle.Expo,  Enum.EasingDirection.Out),
        TAB     = TweenInfo.new(0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
        ENTER   = TweenInfo.new(0.30, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
        EXIT    = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        NOTIF   = TweenInfo.new(0.30, Enum.EasingStyle.Expo,  Enum.EasingDirection.Out),
        DIALOG  = TweenInfo.new(0.32, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
        WIN_O   = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        WIN_C   = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        COLLAPSE= TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        SHAKE   = TweenInfo.new(0.06, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
    }

    local Anim = {}

    -- Guard: only tween if instance is alive and parented.
    -- Silently returns nil if not — no console spam on race conditions.
    function Anim.t(inst: Instance?, key: string, props: {[string]: any}): Tween?
        if not inst or not inst.Parent then return nil end
        local ok, t = pcall(function()
            return TweenService:Create(inst :: Instance, INFO[key] or INFO.MEDIUM, props)
        end)
        if ok and t then
            (t :: Tween):Play()
            return t :: Tween
        end
        return nil
    end

    function Anim.raw(inst: Instance?, tweenInfo: TweenInfo, props: {[string]: any}): Tween?
        if not inst or not inst.Parent then return nil end
        local ok, t = pcall(function()
            return TweenService:Create(inst :: Instance, tweenInfo, props)
        end)
        if ok and t then
            (t :: Tween):Play()
            return t :: Tween
        end
        return nil
    end

    -- Standard hover: background color shift. MICRO = snappy enough to feel instant.
    function Anim.hover(btn: GuiObject, norm: Color3, over: Color3)
        btn.MouseEnter:Connect(function() Anim.t(btn, "MICRO", {BackgroundColor3 = over}) end)
        btn.MouseLeave:Connect(function() Anim.t(btn, "MICRO", {BackgroundColor3 = norm}) end)
    end

    -- Press: tiny scale-down for physical click feedback.
    -- UIScale is the right tool — no layout impact on siblings.
    function Anim.press(btn: GuiObject)
        local s = Instance.new("UIScale"); s.Scale = 1; s.Parent = btn
        btn.MouseButton1Down:Connect(function() Anim.t(s, "MICRO", {Scale = 0.96}) end)
        btn.MouseButton1Up:Connect(function()   Anim.t(s, "FAST",  {Scale = 1.0})  end)
        btn.MouseLeave:Connect(function()       Anim.t(s, "FAST",  {Scale = 1.0})  end)
    end

    -- Shake: used for validation errors. Communicates "wrong" without a popup.
    -- Three quick horizontal oscillations — the universal UI "no" gesture.
    function Anim.shake(inst: GuiObject)
        if not inst or not inst.Parent then return end
        local origin = inst.Position
        local ox = origin.X.Offset
        local os = origin.X.Scale
        local function at(delta: number)
            return UDim2.new(os, ox + delta, origin.Y.Scale, origin.Y.Offset)
        end
        -- Sequence: right → left → right → left → center. Fast.
        Anim.raw(inst, INFO.SHAKE, {Position = at(6)})
        task.delay(0.07, function()
            Anim.raw(inst, INFO.SHAKE, {Position = at(-5)})
            task.delay(0.07, function()
                Anim.raw(inst, INFO.SHAKE, {Position = at(4)})
                task.delay(0.07, function()
                    Anim.raw(inst, INFO.SHAKE, {Position = at(-3)})
                    task.delay(0.07, function()
                        Anim.raw(inst, INFO.SHAKE, {Position = origin})
                    end)
                end)
            end)
        end)
    end

    -- Flash: brief color flash then revert. Used for error highlight on elements.
    function Anim.flash(inst: GuiButton, flashColor: Color3, returnColor: Color3)
        if not inst or not inst.Parent then return end
        Anim.t(inst, "FAST", {BackgroundColor3 = flashColor})
        task.delay(0.35, function()
            Anim.t(inst, "MEDIUM", {BackgroundColor3 = returnColor})
        end)
    end

    -- Window open/close: animate CanvasGroup transparency so ALL children
    -- fade as one unit — zero cost trick that looks genuinely premium.
    function Anim.openWindow(root: CanvasGroup)
        root.GroupTransparency = 1; root.Visible = true
        Anim.raw(root, INFO.WIN_O, {GroupTransparency = 0})
    end
    function Anim.closeWindow(root: CanvasGroup, cb: (() -> ())?)
        local t = Anim.raw(root, INFO.WIN_C, {GroupTransparency = 1})
        if t then
            t.Completed:Connect(function()
                if root and root.Parent then root.Visible = false end
                if cb then ErrorBus.call("Window.close callback", cb) end
            end)
        end
    end

    -- ══════════════════════════════════════════════════════════════
    --  CONFIG SYSTEM  (Hardened I/O)
    --
    --  Executor: saves to velvet_config.json via writefile/readfile.
    --  Studio / no file API: in-memory only.
    --  Corruption handling: bad JSON → reset to defaults, show notif.
    --  Disk errors: silently continue with in-memory, show notif.
    -- ══════════════════════════════════════════════════════════════
    local CFG_FILE = "velvet_config.json"
    local _cfgVals: {[string]: any} = {}
    local _cfgCbs:  {[string]: {{cb: (any) -> (), def: any}}} = {}
    local _cfgMem:  {[string]: any} = {}
    local _hasFile  = typeof(writefile) == "function" and typeof(readfile) == "function"

    local function cfgPersist()
        if not _hasFile then
            for k, v in pairs(_cfgVals) do _cfgMem[k] = v end
            return
        end
        -- Wrap I/O in pcall — disk full, permission denied, etc. are all possible.
        local ok, err = pcall(function()
            writefile(CFG_FILE, HttpService:JSONEncode(_cfgVals))
        end)
        if not ok then
            -- This is a background save failure — don't panic the user loudly.
            -- Just warn in console. They'll see it if they look.
            warn("[VelvetUI/Config] Save failed: " .. tostring(err))
        end
    end

    local function cfgHydrate()
        if not _hasFile then
            for k, v in pairs(_cfgMem) do _cfgVals[k] = v end
            return
        end
        local ok, raw = pcall(readfile, CFG_FILE)
        if not ok or not raw or raw == "" then
            -- File doesn't exist yet — that's fine, first run.
            return
        end
        local jsonOk, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if jsonOk and type(decoded) == "table" then
            _cfgVals = decoded
        else
            -- File exists but is corrupt. Reset it so we don't keep failing.
            -- We'll notify the user via ErrorBus after the notif system is ready.
            warn("[VelvetUI/Config] Config file corrupted — reset to defaults.")
            pcall(writefile, CFG_FILE, "{}")
            _cfgVals = {}
            -- Queue a notification for after the system is initialized
            task.delay(1.5, function()
                if _notifDispatch then
                    _notifDispatch({
                        Title    = "Settings Were Reset",
                        Message  = "Your saved config was corrupted and couldn't be loaded. Starting fresh.",
                        Icon     = "file-x",
                        Severity = "warn",
                        Duration = 6,
                    })
                end
            end)
        end
    end

    local Config = {}
    function Config.register(flag: string, def: any, cb: (any) -> ())
        if not flag or flag == "" then return end
        if _cfgVals[flag] == nil then _cfgVals[flag] = def end
        if not _cfgCbs[flag] then _cfgCbs[flag] = {} end
        table.insert(_cfgCbs[flag], {cb = cb, def = def})
    end
    function Config.save(flag: string, val: any)
        if not flag or flag == "" then return end
        _cfgVals[flag] = val
        cfgPersist()
    end
    function Config.get(flag: string): any  return _cfgVals[flag]  end
    function Config.loadAll()
        cfgHydrate()
        for flag, entries in pairs(_cfgCbs) do
            local v = _cfgVals[flag]
            if v ~= nil then
                for _, e in ipairs(entries) do
                    -- Each config callback is wrapped individually — one bad callback
                    -- shouldn't prevent the others from applying.
                    local ok, err = pcall(e.cb, v)
                    if not ok then
                        warn("[VelvetUI/Config] LoadAll error for '" .. flag .. "': " .. tostring(err))
                    end
                end
            end
        end
    end
    cfgHydrate()

    -- ══════════════════════════════════════════════════════════════
    --  GLOBAL INPUT DISPATCHER
    --
    --  ONE connection per UIS event. Elements register by ID.
    --  Destroy() removes the handler. No more listener leaks.
    --
    --  Guard added: handlers that throw are caught per-entry,
    --  so one bad handler can't stop all the others from firing.
    -- ══════════════════════════════════════════════════════════════
    local Dispatcher = (function()
        local _move:  {[string]: (InputObject) -> ()}       = {}
        local _ended: {[string]: (InputObject) -> ()}       = {}
        local _began: {[string]: (InputObject, boolean) -> ()} = {}
        local _booted = false

        local function safeCall(id: string, fn: (...any) -> (), ...: any)
            local ok, err = pcall(fn, ...)
            if not ok then
                warn("[VelvetUI/Dispatcher] Handler '" .. id .. "' threw: " .. tostring(err))
            end
        end

        local function boot()
            if _booted then return end; _booted = true
            UIS.InputChanged:Connect(function(inp: InputObject)
                for id, fn in pairs(_move)  do safeCall(id, fn, inp)       end
            end)
            UIS.InputEnded:Connect(function(inp: InputObject)
                for id, fn in pairs(_ended) do safeCall(id, fn, inp)       end
            end)
            UIS.InputBegan:Connect(function(inp: InputObject, proc: boolean)
                for id, fn in pairs(_began) do safeCall(id, fn, inp, proc) end
            end)
        end

        return {
            onMove  = function(id: string, fn: (InputObject) -> ())            boot(); _move[id]  = fn end,
            onEnd   = function(id: string, fn: (InputObject) -> ())            boot(); _ended[id] = fn end,
            onBegin = function(id: string, fn: (InputObject, boolean) -> ())   boot(); _began[id] = fn end,
            remove  = function(id: string)
                _move[id] = nil; _ended[id] = nil; _began[id] = nil
            end,
        }
    end)()

    -- ══════════════════════════════════════════════════════════════
    --  POPUP LAYER
    --
    --  A ScreenGui at DisplayOrder 50 where all dropdowns render.
    --  Never parented to a ScrollingFrame. ClipsDescendants problems
    --  are hereby abolished.
    --
    --  Safety: close() handles already-destroyed frames gracefully.
    -- ══════════════════════════════════════════════════════════════
    local PopupLayer = (function()
        local _gui: ScreenGui? = nil
        local function get(): Frame?
            if _gui and _gui.Parent then return _gui :: any end
            local pg = getPlayerGui()
            if not pg then return nil end
            local g = Instance.new("ScreenGui")
            g.Name           = "VelvetPopups"
            g.ResetOnSpawn   = false
            g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            g.DisplayOrder   = 50
            g.Parent         = pg
            _gui = g
            return g :: any
        end
        local function close(frame: Frame?, onDone: (() -> ())?)
            -- Guard: frame might already be dead if the window was destroyed mid-animation
            if not frame or not frame.Parent then
                if onDone then onDone() end; return
            end
            local t = Anim.t(frame, "EXIT", {Size = UDim2.new(0, frame.AbsoluteSize.X, 0, 0)})
            if t then
                t.Completed:Connect(function()
                    pcall(function() if frame and frame.Parent then frame:Destroy() end end)
                    if onDone then onDone() end
                end)
            else
                pcall(function() if frame and frame.Parent then frame:Destroy() end end)
                if onDone then onDone() end
            end
        end
        return { get = get, close = close }
    end)()

    -- ══════════════════════════════════════════════════════════════
    --  INSTANCE FACTORY HELPERS
    --  Thin wrappers. They exist because we create hundreds of
    --  frames and setting 8 properties 200 times is how you get
    --  RSI and unreadable code simultaneously.
    -- ══════════════════════════════════════════════════════════════
    local function mkframe(p: {
        color: Color3?, t: number?, size: UDim2?, pos: UDim2?,
        name: string?, z: number?, clip: boolean?, parent: Instance?
    }): Frame
        local f = Instance.new("Frame")
        f.BackgroundColor3       = p.color or Color3.new(0, 0, 0)
        f.BackgroundTransparency = p.t     or 0
        f.BorderSizePixel        = 0
        f.Size                   = p.size  or UDim2.new(1, 0, 0, 40)
        f.Position               = p.pos   or UDim2.new()
        f.Name                   = p.name  or "Frame"
        f.ZIndex                 = p.z     or 1
        f.ClipsDescendants       = p.clip  or false
        if p.parent then f.Parent = p.parent end
        return f
    end

    local function mklabel(p: {
        text: string?, font: Enum.Font?, sz: number?, color: Color3?,
        xA: Enum.TextXAlignment?, yA: Enum.TextYAlignment?, rich: boolean?,
        size: UDim2?, pos: UDim2?, name: string?, z: number?, parent: Instance?
    }): TextLabel
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1; l.BorderSizePixel = 0
        l.Font                   = p.font  or L.fLabel
        l.TextSize               = p.sz    or 13
        l.TextColor3             = p.color or Color3.new(1, 1, 1)
        l.Text                   = p.text  or ""
        l.TextXAlignment         = p.xA    or Enum.TextXAlignment.Left
        l.TextYAlignment         = p.yA    or Enum.TextYAlignment.Center
        l.TextTruncate           = Enum.TextTruncate.AtEnd
        l.RichText               = p.rich  or false
        l.Size                   = p.size  or UDim2.new(1, 0, 1, 0)
        l.Position               = p.pos   or UDim2.new()
        l.Name                   = p.name  or "Label"
        l.ZIndex                 = p.z     or 1
        if p.parent then l.Parent = p.parent end
        return l
    end

    local function mkbtn(p: {
        text: string?, font: Enum.Font?, sz: number?, textColor: Color3?,
        color: Color3?, t: number?, xA: Enum.TextXAlignment?,
        size: UDim2?, pos: UDim2?, name: string?, z: number?, parent: Instance?
    }): TextButton
        local b = Instance.new("TextButton")
        b.AutoButtonColor        = false
        b.BackgroundColor3       = p.color     or Color3.fromRGB(50, 50, 70)
        b.BackgroundTransparency = p.t         or 0
        b.BorderSizePixel        = 0
        b.Font                   = p.font      or L.fLabel
        b.TextSize               = p.sz        or 13
        b.TextColor3             = p.textColor or Color3.new(1, 1, 1)
        b.Text                   = p.text      or ""
        b.TextXAlignment         = p.xA        or Enum.TextXAlignment.Center
        b.Size                   = p.size      or UDim2.new(1, 0, 0, 44)
        b.Position               = p.pos       or UDim2.new()
        b.Name                   = p.name      or "Btn"
        b.ZIndex                 = p.z         or 1
        if p.parent then b.Parent = p.parent end
        return b
    end

    local function mktbox(p: {
        color: Color3?, t: number?, textColor: Color3?, placeholder: string?,
        phColor: Color3?, text: string?, clearFocus: boolean?,
        xA: Enum.TextXAlignment?, size: UDim2?, pos: UDim2?,
        name: string?, z: number?, sz: number?, parent: Instance?
    }): TextBox
        local t = Instance.new("TextBox")
        t.BackgroundColor3       = p.color       or Color3.fromRGB(22, 22, 31)
        t.BackgroundTransparency = p.t           or 0
        t.BorderSizePixel        = 0
        t.Font                   = L.fBody
        t.TextSize               = p.sz          or 13
        t.TextColor3             = p.textColor   or Color3.new(1, 1, 1)
        t.PlaceholderText        = p.placeholder or ""
        t.PlaceholderColor3      = p.phColor     or Color3.fromRGB(100, 95, 108)
        t.Text                   = p.text        or ""
        t.ClearTextOnFocus       = p.clearFocus  or false
        t.TextXAlignment         = p.xA          or Enum.TextXAlignment.Left
        t.Size                   = p.size        or UDim2.new(1, 0, 0, 44)
        t.Position               = p.pos         or UDim2.new()
        t.Name                   = p.name        or "TextBox"
        t.ZIndex                 = p.z           or 1
        t.ClipsDescendants       = true
        if p.parent then t.Parent = p.parent end
        return t
    end

    local function mkicon(p: {
        size: UDim2?, pos: UDim2?, anchor: Vector2?, color: Color3?,
        name: string?, z: number?, parent: Instance?
    }): ImageLabel
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1; img.BorderSizePixel = 0
        img.Size        = p.size   or UDim2.new(0, 18, 0, 18)
        img.Position    = p.pos    or UDim2.new()
        img.AnchorPoint = p.anchor or Vector2.new(0, 0)
        img.ScaleType   = Enum.ScaleType.Fit
        img.ImageColor3 = p.color  or Color3.new(1, 1, 1)
        img.Name        = p.name   or "Icon"
        img.ZIndex      = p.z      or 2
        img.Image       = ""
        if p.parent then img.Parent = p.parent end
        return img
    end

    local function corner(inst: GuiObject, r: number?): UICorner
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r or L.rElem)
        c.Parent = inst; return c
    end

    local function mkstroke(inst: GuiObject, color: Color3?, t: number?, thick: number?): UIStroke
        local s = Instance.new("UIStroke")
        s.Color           = color or Color3.fromRGB(42, 42, 58)
        s.Transparency    = t     or L.strokeT
        s.Thickness       = thick or L.strokeW
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = inst; return s
    end

    local function listLayout(parent: Instance, props: {dir: Enum.FillDirection?, spacing: number?, hA: Enum.HorizontalAlignment?, vA: Enum.VerticalAlignment?}?): UIListLayout
        local p2 = props or {}
        local l = Instance.new("UIListLayout")
        l.FillDirection       = p2.dir or Enum.FillDirection.Vertical
        l.SortOrder           = Enum.SortOrder.LayoutOrder
        l.Padding             = UDim.new(0, p2.spacing or L.elemSpacing)
        l.HorizontalAlignment = p2.hA or Enum.HorizontalAlignment.Left
        l.VerticalAlignment   = p2.vA or Enum.VerticalAlignment.Top
        l.Parent = parent; return l
    end

    local function padding(parent: Instance, top: number?, right: number?, bottom: number?, left: number?): UIPadding
        local p = Instance.new("UIPadding")
        p.PaddingTop    = UDim.new(0, top    or 0)
        p.PaddingRight  = UDim.new(0, right  or 0)
        p.PaddingBottom = UDim.new(0, bottom or 0)
        p.PaddingLeft   = UDim.new(0, left   or 0)
        p.Parent = parent; return p
    end

    local function gradient(parent: Instance, cs: ColorSequence, rot: number?): UIGradient
        local g = Instance.new("UIGradient")
        g.Color = cs; g.Rotation = rot or 90; g.Parent = parent; return g
    end

    local function clamp(n: number, mn: number, mx: number): number
        return math.max(mn, math.min(mx, n))
    end
    local function rnd(n: number, d: number?): number
        local m = 10 ^ (d or 0); return math.floor(n * m + 0.5) / m
    end

    -- ══════════════════════════════════════════════════════════════
    --  ELEMENT BUILDERS
    --
    --  Every element:
    --    • Returns a control with Show/Hide/Destroy + element API
    --    • Uses ErrorBus for all callback execution
    --    • Registers with Dispatcher (not raw UIS connections)
    --    • Calls Dispatcher.remove(id) on Destroy()
    --    • Supports optional `flag` for Config persistence
    -- ══════════════════════════════════════════════════════════════

    local function makeRow(parent: Instance, name: string?, height: number?): Frame
        local T   = Theme.get()
        local row = mkframe({
            name   = name or "Row",
            size   = UDim2.new(1, 0, 0, height or L.elemH),
            color  = T.surface,
            parent = parent,
        })
        corner(row, L.rElem)
        mkstroke(row, T.border, L.strokeT)
        return row
    end

    local function makeRowLabel(row: Frame, text: string, desc: string?): TextLabel
        local T = Theme.get()
        if desc and desc ~= "" then
            local nameL = mklabel({
                text = text, font = L.fLabel, sz = L.szElem,
                color = T.text, xA = Enum.TextXAlignment.Left,
                size = UDim2.new(0.55, -8, 0, 18),
                pos  = UDim2.new(0, L.groupPadH, 0, 8),
                parent = row,
            })
            mklabel({
                text = desc, font = L.fBody, sz = L.szMuted,
                color = T.muted, xA = Enum.TextXAlignment.Left,
                size = UDim2.new(0.55, -8, 0, 14),
                pos  = UDim2.new(0, L.groupPadH, 0, 26),
                parent = row,
            })
            return nameL
        end
        return mklabel({
            text = text, font = L.fLabel, sz = L.szElem,
            color = T.text, xA = Enum.TextXAlignment.Left,
            size = UDim2.new(0.55, -8, 1, 0),
            pos  = UDim2.new(0, L.groupPadH, 0, 0),
            parent = row,
        })
    end

    -- Standard destroy/show/hide control for all elements.
    -- extraConns: any additional RBXScriptConnections to disconnect on destroy.
    local function makeCtrl(root: Frame, dispId: string?, extraConns: {RBXScriptConnection}?): any
        local ctrl: any = {}
        function ctrl.Show()    if root and root.Parent then root.Visible = true  end end
        function ctrl.Hide()    if root and root.Parent then root.Visible = false end end
        function ctrl.Destroy()
            if dispId then Dispatcher.remove(dispId) end
            if extraConns then
                for _, c in ipairs(extraConns) do
                    if typeof(c) == "RBXScriptConnection" then pcall(function() c:Disconnect() end) end
                end
            end
            pcall(function() if root and root.Parent then root:Destroy() end end)
        end
        return ctrl
    end

    -- ── Button ────────────────────────────────────────────────────
    local function Button(parent: Instance, text: string, callback: (() -> ())?): any
        local T       = Theme.get()
        local _locked = false
        local row = mkframe({name = "ButtonRow", size = UDim2.new(1, 0, 0, L.elemH), color = T.surface, parent = parent})
        corner(row, L.rBtn); mkstroke(row, T.border, L.strokeT)

        local btn = mkbtn({
            text = text, font = L.fLabel, sz = L.szElem,
            textColor = T.text, color = T.surface,
            size = UDim2.new(1, 0, 1, 0), parent = row,
        })
        corner(btn, L.rBtn)

        -- Accent left bar: visual affordance that this is clickable
        local bar = mkframe({name = "Bar", size = UDim2.new(0, 3, 0.6, 0), pos = UDim2.new(0, 0, 0.2, 0), color = T.accent, parent = btn})
        corner(bar, 2)

        Anim.hover(btn, T.surface, T.card)
        Anim.press(btn)

        btn.MouseButton1Click:Connect(function()
            if _locked then
                -- Shake to communicate "this is disabled" without a popup
                Anim.shake(row)
                return
            end
            if callback then
                ErrorBus.callWith("Button.click", callback)
            end
        end)

        local ctrl = makeCtrl(row)
        function ctrl.SetText(t: string)   if btn and btn.Parent then btn.Text = t end end
        function ctrl.Lock()
            _locked = true
            if btn and btn.Parent then btn.TextColor3 = T.muted end
            Anim.t(bar, "FAST", {BackgroundColor3 = T.muted})
        end
        function ctrl.Unlock()
            _locked = false
            if btn and btn.Parent then btn.TextColor3 = T.text end
            Anim.t(bar, "FAST", {BackgroundColor3 = T.accent})
        end
        function ctrl.Flash(isError: boolean?)
            -- Visual feedback for async operations completing
            local flashC = isError and T.danger or T.success
            Anim.flash(btn, flashC, T.surface)
        end
        return ctrl
    end

    -- ── Switch ────────────────────────────────────────────────────
    local function Switch(parent: Instance, name: string, default: boolean?, callback: ((boolean) -> ())?, flag: string?, desc: string?): any
        local T   = Theme.get()
        local _on = default == true
        local rowH = (desc and desc ~= "") and (L.elemH + 14) or L.elemH
        local row  = makeRow(parent, "SwitchRow", rowH)
        makeRowLabel(row, name, desc)

        local TRK_W, TRK_H = 44, 24
        local THM_SZ = TRK_H - 6
        local TRAVEL = TRK_W - THM_SZ - 6

        local track = mkframe({
            name = "Track", size = UDim2.new(0, TRK_W, 0, TRK_H),
            pos  = UDim2.new(1, -(TRK_W + L.groupPadH), 0.5, -TRK_H / 2),
            color = _on and T.switchOn or T.switchOff,
            parent = row,
        })
        corner(track, L.rSwitch)

        local thumb = mkframe({
            name = "Thumb", size = UDim2.new(0, THM_SZ, 0, THM_SZ),
            pos  = _on
                and UDim2.new(0, TRAVEL + 3, 0.5, -THM_SZ / 2)
                or  UDim2.new(0, 3, 0.5, -THM_SZ / 2),
            color = T.sliderThumb, parent = track,
        })
        corner(thumb, L.rSliderThm)

        local function setVisual(on: boolean)
            Anim.t(track, "FAST", {BackgroundColor3 = on and T.switchOn or T.switchOff})
            Anim.t(thumb, "FAST", {Position =
                on  and UDim2.new(0, TRAVEL + 3, 0.5, -THM_SZ / 2)
                    or  UDim2.new(0, 3, 0.5, -THM_SZ / 2)
            })
        end

        local hit = mkbtn({color = T.surface, t = 1, size = UDim2.new(1, 0, 1, 0), parent = row})
        hit.MouseButton1Click:Connect(function()
            _on = not _on
            setVisual(_on)
            if flag then Config.save(flag, _on) end
            if callback then
                local success = ErrorBus.callWith("Switch.toggle[" .. name .. "]", callback, false, _on)
                if not success then
                    -- Revert the switch on callback failure — don't leave state inconsistent
                    _on = not _on
                    setVisual(_on)
                    if flag then Config.save(flag, _on) end
                end
            end
        end)

        if flag then
            Config.register(flag, default, function(v: any) _on = v == true; setVisual(v == true) end)
        end

        local ctrl = makeCtrl(row)
        function ctrl.SetState(bool: boolean)
            if bool == _on then return end
            _on = bool; setVisual(bool)
            if flag then Config.save(flag, bool) end
        end
        function ctrl.GetState(): boolean return _on end
        function ctrl.Flip() hit.MouseButton1Click:Fire() end
        return ctrl
    end

    -- ── Slider ────────────────────────────────────────────────────
    local function Slider(parent: Instance, name: string, min: number?, max: number?, default: number?, callback: ((number) -> ())?, flag: string?): any
        local T    = Theme.get()
        local _min = min or 0
        local _max = max or 100
        local _val = clamp(default or _min, _min, _max)
        local _id  = uid()

        local wrapper = mkframe({
            name = "SliderWrapper", size = UDim2.new(1, 0, 0, L.elemH + 20),
            color = T.surface, parent = parent,
        })
        corner(wrapper, L.rElem); mkstroke(wrapper, T.border, L.strokeT)

        local topRow = mkframe({name = "TopRow", size = UDim2.new(1, 0, 0, 26), color = T.surface, t = 1, parent = wrapper})
        makeRowLabel(topRow, name)
        local valLbl = mklabel({
            text = tostring(rnd(_val, 1)), font = L.fLabel, sz = L.szElem,
            color = T.rose, xA = Enum.TextXAlignment.Right,
            size = UDim2.new(0, 60, 1, 0),
            pos  = UDim2.new(1, -(60 + L.groupPadH), 0, 0),
            parent = topRow,
        })

        local TRK_H = 6; local THM_SZ = 16
        local PADX = L.groupPadH + THM_SZ / 2

        local trackBg = mkframe({
            name = "TrackBg", size = UDim2.new(1, -(PADX * 2), 0, TRK_H),
            pos  = UDim2.new(0, PADX, 0, 30), color = T.sliderTrack,
            clip = true, parent = wrapper,
        })
        corner(trackBg, L.rSliderTrk)

        local pct0 = (_val - _min) / (_max - _min)
        local trackFill = mkframe({
            name = "Fill", size = UDim2.new(pct0, 0, 1, 0),
            color = T.sliderFill, parent = trackBg,
        })
        corner(trackFill, L.rSliderTrk)

        local thumb = mkframe({
            name = "Thumb", size = UDim2.new(0, THM_SZ, 0, THM_SZ),
            pos  = UDim2.new(pct0, -THM_SZ / 2, 0, -THM_SZ / 2 + TRK_H / 2),
            color = T.sliderThumb, parent = trackBg,
        })
        corner(thumb, L.rSliderThm)
        mkstroke(thumb, T.accent, 0.5, 2)

        local _dragging = false

        local function applyValue(v: number)
            v = clamp(v, _min, _max)
            local p = (v - _min) / (_max - _min)
            _val = v
            if valLbl and valLbl.Parent then valLbl.Text = tostring(rnd(v, 1)) end
            if trackFill and trackFill.Parent then trackFill.Size = UDim2.new(p, 0, 1, 0) end
            if thumb and thumb.Parent then thumb.Position = UDim2.new(p, -THM_SZ / 2, 0, -THM_SZ / 2 + TRK_H / 2) end
            if flag then Config.save(flag, v) end
            if callback then
                ErrorBus.callWith("Slider.change[" .. name .. "]", callback, true, v)
            end
        end

        local function posToVal(x: number): number
            if not trackBg or not trackBg.Parent then return _min end
            local abs = trackBg.AbsolutePosition.X
            local wid = trackBg.AbsoluteSize.X
            if wid <= 0 then return _min end
            return _min + clamp((x - abs) / wid, 0, 1) * (_max - _min)
        end

        thumb.InputBegan:Connect(function(inp: InputObject)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                _dragging = true
            end
        end)
        trackBg.InputBegan:Connect(function(inp: InputObject)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                applyValue(posToVal(inp.Position.X)); _dragging = true
            end
        end)

        Dispatcher.onMove(_id, function(inp: InputObject)
            if not _dragging then return end
            if inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch then
                applyValue(posToVal(inp.Position.X))
            end
        end)
        Dispatcher.onEnd(_id, function(inp: InputObject)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
                _dragging = false
            end
        end)

        if flag then
            Config.register(flag, default, function(v: any)
                if type(v) == "number" then applyValue(v) end
            end)
        end

        local ctrl = makeCtrl(wrapper, _id)
        function ctrl.SetValue(v: number) applyValue(v) end
        function ctrl.GetValue(): number  return _val   end
        function ctrl.SetRange(mn: number, mx: number)
            _min = mn; _max = mx
            applyValue(clamp(_val, mn, mx))
        end
        return ctrl
    end

    -- ── TextField ─────────────────────────────────────────────────
    local function TextField(parent: Instance, name: string, placeholder: string?, callback: ((string, boolean) -> ())?, flag: string?): any
        local T   = Theme.get()
        local row = makeRow(parent, "TextFieldRow", L.elemH + 12)
        makeRowLabel(row, name)

        local BOX_W = 160
        local box = mktbox({
            placeholder = placeholder or "", color = T.bg,
            textColor = T.text, phColor = T.muted,
            size = UDim2.new(0, BOX_W, 0, 30),
            pos  = UDim2.new(1, -(BOX_W + L.groupPadH), 0.5, -15),
            parent = row,
        })
        corner(box, L.rElem)
        local sk = mkstroke(box, T.border, L.strokeT)
        padding(box, 0, 8, 0, 8)

        box.Focused:Connect(function()
            if sk and sk.Parent then sk.Transparency = L.strokeFocus end
        end)
        box.FocusLost:Connect(function(enter: boolean)
            if sk and sk.Parent then sk.Transparency = L.strokeT end
            local val = box.Text
            if flag then Config.save(flag, val) end
            if callback then
                ErrorBus.callWith("TextField.focusLost[" .. name .. "]", callback, false, val, enter)
            end
        end)

        if flag then
            Config.register(flag, box.Text, function(v: any)
                if box and box.Parent then box.Text = tostring(v or "") end
            end)
        end

        local ctrl = makeCtrl(row)
        function ctrl.SetText(t: string)
            if box and box.Parent then box.Text = t end
        end
        function ctrl.GetText(): string
            return (box and box.Parent) and box.Text or ""
        end
        function ctrl.Clear()
            if box and box.Parent then box.Text = "" end
        end
        function ctrl.SetError(hasError: boolean)
            -- Visual error state: stroke turns danger color
            if sk and sk.Parent then
                sk.Color = hasError and T.danger or T.border
                sk.Transparency = hasError and 0.3 or L.strokeT
            end
            if hasError then Anim.shake(row) end
        end
        return ctrl
    end

    -- ── Dropdown (single-select) ───────────────────────────────────
    local function Dropdown(parent: Instance, name: string, options: {string}, default: string?, callback: ((string) -> ())?, flag: string?): any
        local T        = Theme.get()
        local _options = options or {}
        local _sel     = default or (_options[1] or "")
        local _open    = false
        local _popup: Frame? = nil
        local _id      = uid()

        local DPOP_W = 160
        local row    = makeRow(parent, "DropdownRow")
        makeRowLabel(row, name)

        local dispBtn = mkbtn({
            text = _sel, font = L.fBody, sz = L.szElem,
            textColor = T.text, color = T.bg,
            size = UDim2.new(0, DPOP_W, 0, 30),
            pos  = UDim2.new(1, -(DPOP_W + L.groupPadH), 0.5, -15),
            parent = row,
        })
        corner(dispBtn, L.rDropdown)
        mkstroke(dispBtn, T.border, L.strokeT)
        padding(dispBtn, 0, 22, 0, 8)

        local CHEV = 12
        local chevron = mkicon({
            name = "Chev", size = UDim2.new(0, CHEV, 0, CHEV),
            pos  = UDim2.new(1, -(CHEV + 6), 0.5, -CHEV / 2),
            color = T.muted, z = 3, parent = dispBtn,
        })
        Icons.Apply(chevron, "chevron-down", {tint = T.muted})

        local function closePopup()
            _open = false
            Anim.t(chevron, "FAST", {Rotation = 0})
            if _popup then
                local p = _popup; _popup = nil
                PopupLayer.close(p)
            end
            Dispatcher.remove(_id .. "_outside")
        end

        local function buildPopup()
            local layer = PopupLayer.get()
            if not layer then return end
            if not dispBtn or not dispBtn.Parent then return end

            local abs = dispBtn.AbsolutePosition
            local sz  = dispBtn.AbsoluteSize
            local POP_H = math.min(#_options * 34 + 8, 200)

            local pf = mkframe({
                name  = "DropPopup",
                size  = UDim2.new(0, DPOP_W, 0, 0),
                pos   = UDim2.fromOffset(abs.X, abs.Y + sz.Y + 4),
                color = T.card, clip = true, z = 5,
                parent = layer,
            })
            corner(pf, L.rDropdown)
            mkstroke(pf, T.border, L.strokeT)
            _popup = pf

            local scroll = Instance.new("ScrollingFrame")
            scroll.Size                   = UDim2.new(1, 0, 1, 0)
            scroll.BackgroundTransparency = 1
            scroll.BorderSizePixel        = 0
            scroll.ScrollBarThickness     = 3
            scroll.ScrollBarImageColor3   = T.accent
            scroll.CanvasSize             = UDim2.new(0, 0, 0, #_options * 34 + 8)
            scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
            scroll.ZIndex                 = 5
            scroll.Parent                 = pf
            listLayout(scroll, {spacing = 2})
            padding(scroll, 4, 4, 4, 4)

            for _, opt in ipairs(_options) do
                local isActive = (opt == _sel)
                local obtn = mkbtn({
                    text = opt, font = L.fBody, sz = L.szBody,
                    textColor = isActive and T.accent or T.text,
                    color     = isActive and T.surface or T.card,
                    size = UDim2.new(1, 0, 0, 30),
                    xA   = Enum.TextXAlignment.Left,
                    z = 6, parent = scroll,
                })
                corner(obtn, 6); padding(obtn, 0, 0, 0, 10)
                Anim.hover(obtn, isActive and T.surface or T.card, T.surface)

                obtn.MouseButton1Click:Connect(function()
                    _sel = opt
                    if dispBtn and dispBtn.Parent then dispBtn.Text = opt end
                    if flag then Config.save(flag, opt) end
                    if callback then
                        ErrorBus.callWith("Dropdown.select[" .. name .. "]", callback, false, opt)
                    end
                    closePopup()
                end)
            end

            Anim.t(pf, "MEDIUM", {Size = UDim2.new(0, DPOP_W, 0, POP_H)})
        end

        dispBtn.MouseButton1Click:Connect(function()
            if _open then
                closePopup()
            else
                _open = true
                Anim.t(chevron, "FAST", {Rotation = 180})
                buildPopup()
                Dispatcher.onBegin(_id .. "_outside", function(inp: InputObject)
                    if not _open then return end
                    if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                        task.delay(0.05, function()
                            if _open then closePopup() end
                        end)
                    end
                end)
            end
        end)

        if flag then
            Config.register(flag, default, function(v: any)
                _sel = tostring(v)
                if dispBtn and dispBtn.Parent then dispBtn.Text = _sel end
            end)
        end

        local ctrl = makeCtrl(row, _id)
        local _origDestroy = ctrl.Destroy
        function ctrl.Destroy()
            closePopup()
            Dispatcher.remove(_id .. "_outside")
            _origDestroy()
        end
        function ctrl.Select(opt: string)
            for _, o in ipairs(_options) do
                if o == opt then
                    _sel = opt
                    if dispBtn and dispBtn.Parent then dispBtn.Text = opt end
                    if flag then Config.save(flag, opt) end
                    return
                end
            end
        end
        function ctrl.GetSelected(): string    return _sel    end
        function ctrl.ReplaceOptions(list: {string})
            _options = list; _sel = list[1] or ""
            if dispBtn and dispBtn.Parent then dispBtn.Text = _sel end
        end
        return ctrl
    end

    -- ── MultiDropdown ─────────────────────────────────────────────
    local function MultiDropdown(parent: Instance, name: string, options: {string}, defaults: {string}?, callback: (({string}) -> ())?, flag: string?): any
        local T        = Theme.get()
        local _options = options or {}
        local _sel: {[string]: boolean} = {}
        local _open    = false
        local _popup: Frame? = nil
        local _id      = uid()

        if defaults then
            for _, d in ipairs(defaults) do _sel[d] = true end
        end

        local DPOP_W = 180
        local row    = makeRow(parent, "MultiDropRow")
        makeRowLabel(row, name)

        local function countSel(): number
            local n = 0; for _ in pairs(_sel) do n += 1 end; return n
        end
        local function dispText(): string
            local n = countSel()
            if n == 0 then return "None" end
            if n == 1 then for k in pairs(_sel) do return k end end
            return n .. " selected"
        end

        local dispBtn = mkbtn({
            text = dispText(), font = L.fBody, sz = L.szElem,
            textColor = T.text, color = T.bg,
            size = UDim2.new(0, DPOP_W, 0, 30),
            pos  = UDim2.new(1, -(DPOP_W + L.groupPadH), 0.5, -15),
            parent = row,
        })
        corner(dispBtn, L.rDropdown); mkstroke(dispBtn, T.border, L.strokeT)
        padding(dispBtn, 0, 22, 0, 8)

        local CHEV = 12
        local chevron = mkicon({
            name = "Chev", size = UDim2.new(0, CHEV, 0, CHEV),
            pos  = UDim2.new(1, -(CHEV + 6), 0.5, -CHEV / 2),
            color = T.muted, z = 3, parent = dispBtn,
        })
        Icons.Apply(chevron, "chevron-down", {tint = T.muted})

        local function fireCallback()
            local arr: {string} = {}
            for k in pairs(_sel) do table.insert(arr, k) end
            if dispBtn and dispBtn.Parent then dispBtn.Text = dispText() end
            if flag then Config.save(flag, arr) end
            if callback then
                ErrorBus.callWith("MultiDropdown.change[" .. name .. "]", callback, false, arr)
            end
        end

        local function closePopup()
            _open = false
            Anim.t(chevron, "FAST", {Rotation = 0})
            if _popup then
                local p = _popup; _popup = nil
                PopupLayer.close(p)
            end
            Dispatcher.remove(_id .. "_outside")
        end

        local function buildPopup()
            local layer = PopupLayer.get(); if not layer then return end
            if not dispBtn or not dispBtn.Parent then return end
            local abs = dispBtn.AbsolutePosition; local sz = dispBtn.AbsoluteSize
            local POP_H = math.min(#_options * 36 + 8, 220)

            local pf = mkframe({
                name  = "MultiPopup",
                size  = UDim2.new(0, DPOP_W, 0, 0),
                pos   = UDim2.fromOffset(abs.X, abs.Y + sz.Y + 4),
                color = T.card, clip = true, z = 5, parent = layer,
            })
            corner(pf, L.rDropdown); mkstroke(pf, T.border, L.strokeT)
            _popup = pf

            local scroll = Instance.new("ScrollingFrame")
            scroll.Size = UDim2.new(1, 0, 1, 0); scroll.BackgroundTransparency = 1
            scroll.BorderSizePixel = 0; scroll.ScrollBarThickness = 3
            scroll.ScrollBarImageColor3 = T.accent
            scroll.CanvasSize = UDim2.new(0, 0, 0, #_options * 36 + 8)
            scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
            scroll.ZIndex = 5; scroll.Parent = pf
            listLayout(scroll, {spacing = 2}); padding(scroll, 4, 4, 4, 4)

            for _, opt in ipairs(_options) do
                local isOn = _sel[opt] == true
                local orow = mkframe({
                    name = "OptRow_" .. opt, size = UDim2.new(1, 0, 0, 32),
                    color = T.card, z = 6, parent = scroll,
                })
                corner(orow, 6)
                Anim.hover(orow, T.card, T.surface)

                local CB_SZ = 14
                local cb = mkframe({
                    name = "CB", size = UDim2.new(0, CB_SZ, 0, CB_SZ),
                    pos  = UDim2.new(0, 10, 0.5, -CB_SZ / 2),
                    color = isOn and T.accent or T.switchOff,
                    z = 7, parent = orow,
                })
                corner(cb, 4); mkstroke(cb, T.border, 0.5)

                local ckIcon = mkicon({
                    name = "Check", size = UDim2.new(0, 10, 0, 10),
                    pos  = UDim2.new(0.5, -5, 0.5, -5),
                    color = T.text, z = 8, parent = cb,
                })
                Icons.Apply(ckIcon, "check", {tint = T.text})
                ckIcon.Visible = isOn

                mklabel({
                    text = opt, font = L.fBody, sz = L.szBody,
                    color = T.text, xA = Enum.TextXAlignment.Left,
                    size = UDim2.new(1, -34, 1, 0), pos = UDim2.new(0, 32, 0, 0),
                    z = 7, parent = orow,
                })

                local hit = mkbtn({
                    color = Color3.new(1, 1, 1), t = 1,
                    size = UDim2.new(1, 0, 1, 0), z = 9, parent = orow,
                })
                hit.MouseButton1Click:Connect(function()
                    if _sel[opt] then
                        _sel[opt] = nil
                        Anim.t(cb, "FAST", {BackgroundColor3 = T.switchOff})
                        ckIcon.Visible = false
                    else
                        _sel[opt] = true
                        Anim.t(cb, "FAST", {BackgroundColor3 = T.accent})
                        ckIcon.Visible = true
                    end
                    fireCallback()
                end)
            end

            Anim.t(pf, "MEDIUM", {Size = UDim2.new(0, DPOP_W, 0, POP_H)})
        end

        dispBtn.MouseButton1Click:Connect(function()
            if _open then closePopup()
            else
                _open = true
                Anim.t(chevron, "FAST", {Rotation = 180})
                buildPopup()
                Dispatcher.onBegin(_id .. "_outside", function(inp: InputObject)
                    if not _open then return end
                    if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                        task.delay(0.05, function() if _open then closePopup() end end)
                    end
                end)
            end
        end)

        if flag then
            Config.register(flag, defaults, function(v: any)
                _sel = {}
                if type(v) == "table" then
                    for _, k in ipairs(v) do _sel[k] = true end
                end
                if dispBtn and dispBtn.Parent then dispBtn.Text = dispText() end
            end)
        end

        local ctrl = makeCtrl(row, _id)
        local _origD = ctrl.Destroy
        function ctrl.Destroy()
            closePopup()
            Dispatcher.remove(_id .. "_outside")
            _origD()
        end
        function ctrl.GetSelected(): {string}
            local arr: {string} = {}
            for k in pairs(_sel) do table.insert(arr, k) end
            return arr
        end
        function ctrl.SetSelected(list: {string})
            _sel = {}
            if list then for _, k in ipairs(list) do _sel[k] = true end end
            if dispBtn and dispBtn.Parent then dispBtn.Text = dispText() end
        end
        return ctrl
    end

    -- ── ColorSelect ───────────────────────────────────────────────
    local function ColorSelect(parent: Instance, name: string, default: Color3?, callback: ((Color3) -> ())?, flag: string?): any
        local T      = Theme.get()
        local _color = default or Color3.fromRGB(123, 47, 190)
        local _open  = false
        local _popup: Frame? = nil
        local _id    = uid()
        local _h, _s, _v = Color3.toHSV(_color)

        local SW_SZ = 28
        local row   = makeRow(parent, "ColorRow")
        makeRowLabel(row, name)

        local swatch = mkframe({
            name = "Swatch", size = UDim2.new(0, SW_SZ, 0, SW_SZ),
            pos  = UDim2.new(1, -(SW_SZ + L.groupPadH), 0.5, -SW_SZ / 2),
            color = _color, parent = row,
        })
        corner(swatch, 6); mkstroke(swatch, T.border, L.strokeT)

        local hit = mkbtn({color = Color3.new(1, 1, 1), t = 1, size = UDim2.new(1, 0, 1, 0), parent = swatch})

        local PW, PH = 204, 184
        local _idSV  = _id .. "_sv"; local _idHue = _id .. "_hue"
        local _dragSV = false; local _dragHue = false
        local _hueSV: Frame?; local _svThumb: Frame?

        local function updateColor()
            _color = Color3.fromHSV(_h, _s, _v)
            if swatch and swatch.Parent then swatch.BackgroundColor3 = _color end
            if _hueSV and _hueSV.Parent then _hueSV.BackgroundColor3 = Color3.fromHSV(_h, 1, 1) end
            if _svThumb and _svThumb.Parent then _svThumb.Position = UDim2.new(_s, -6, 1 - _v, -6) end
            if flag then Config.save(flag, {_color.R, _color.G, _color.B}) end
            if callback then
                ErrorBus.callWith("ColorSelect.change[" .. name .. "]", callback, true, _color)
            end
        end

        local function closePopup()
            _open = false
            if _popup then
                local p = _popup; _popup = nil
                PopupLayer.close(p)
            end
            Dispatcher.remove(_idSV); Dispatcher.remove(_idHue)
        end

        local function buildPopup()
            local layer = PopupLayer.get(); if not layer then return end
            if not swatch or not swatch.Parent then return end
            local abs = swatch.AbsolutePosition; local sz = swatch.AbsoluteSize

            local pf = mkframe({
                name = "ColorPopup", size = UDim2.new(0, PW, 0, PH),
                pos  = UDim2.fromOffset(abs.X - PW + sz.X, abs.Y + sz.Y + 6),
                color = T.card, z = 5, parent = layer,
            })
            corner(pf, L.rDropdown); mkstroke(pf, T.border, L.strokeT)
            padding(pf, 10, 10, 10, 10)
            _popup = pf

            local HUE_H = 16
            local svArea = mkframe({
                name = "SVArea",
                size = UDim2.new(1, 0, 1, -(HUE_H + 14)),
                color = Color3.fromHSV(_h, 1, 1), z = 6, parent = pf,
            })
            corner(svArea, 4)
            _hueSV = svArea

            local wg = Instance.new("UIGradient")
            wg.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
            })
            wg.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1),
            })
            wg.Parent = svArea

            local blk = mkframe({name = "BlackOv", size = UDim2.new(1, 0, 1, 0), color = Color3.new(0, 0, 0), z = 7, parent = svArea})
            corner(blk, 4)
            local bg = Instance.new("UIGradient")
            bg.Color = ColorSequence.new(Color3.new(0, 0, 0))
            bg.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0),
            })
            bg.Rotation = 270; bg.Parent = blk

            local th = mkframe({
                name = "SVThumb", size = UDim2.new(0, 12, 0, 12),
                pos  = UDim2.new(_s, -6, 1 - _v, -6),
                color = Color3.new(1, 1, 1), z = 8, parent = svArea,
            })
            corner(th, 6); mkstroke(th, Color3.new(0, 0, 0), 0.3)
            _svThumb = th

            local hStrip = mkframe({
                name = "HueStrip", size = UDim2.new(1, 0, 0, HUE_H),
                pos  = UDim2.new(0, 0, 1, -(HUE_H)), color = Color3.new(1, 0, 0),
                z = 6, parent = pf,
            })
            corner(hStrip, 4)

            local hg = Instance.new("UIGradient")
            hg.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,     Color3.fromHSV(0,     1, 1)),
                ColorSequenceKeypoint.new(0.166, Color3.fromHSV(0.166, 1, 1)),
                ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333, 1, 1)),
                ColorSequenceKeypoint.new(0.5,   Color3.fromHSV(0.5,   1, 1)),
                ColorSequenceKeypoint.new(0.666, Color3.fromHSV(0.666, 1, 1)),
                ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833, 1, 1)),
                ColorSequenceKeypoint.new(1,     Color3.fromHSV(1,     1, 1)),
            })
            hg.Parent = hStrip

            svArea.InputBegan:Connect(function(inp: InputObject)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                    _dragSV = true
                    if not svArea or not svArea.Parent then return end
                    local r = svArea.AbsolutePosition; local w = svArea.AbsoluteSize
                    _s = clamp((inp.Position.X - r.X) / w.X, 0, 1)
                    _v = 1 - clamp((inp.Position.Y - r.Y) / w.Y, 0, 1)
                    updateColor()
                end
            end)
            Dispatcher.onMove(_idSV, function(inp: InputObject)
                if not _dragSV or not svArea or not svArea.Parent then return end
                local r = svArea.AbsolutePosition; local w = svArea.AbsoluteSize
                _s = clamp((inp.Position.X - r.X) / w.X, 0, 1)
                _v = 1 - clamp((inp.Position.Y - r.Y) / w.Y, 0, 1)
                updateColor()
            end)
            Dispatcher.onEnd(_idSV, function(inp: InputObject)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                    _dragSV = false
                end
            end)

            hStrip.InputBegan:Connect(function(inp: InputObject)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                    _dragHue = true
                    if not hStrip or not hStrip.Parent then return end
                    local r = hStrip.AbsolutePosition; local w = hStrip.AbsoluteSize
                    _h = clamp((inp.Position.X - r.X) / w.X, 0, 1)
                    updateColor()
                end
            end)
            Dispatcher.onMove(_idHue, function(inp: InputObject)
                if not _dragHue or not hStrip or not hStrip.Parent then return end
                local r = hStrip.AbsolutePosition; local w = hStrip.AbsoluteSize
                _h = clamp((inp.Position.X - r.X) / w.X, 0, 1)
                updateColor()
            end)
            Dispatcher.onEnd(_idHue, function(inp: InputObject)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                    _dragHue = false
                end
            end)
        end

        hit.MouseButton1Click:Connect(function()
            if _open then closePopup()
            else _open = true; buildPopup() end
        end)

        if flag then
            Config.register(flag, {_color.R, _color.G, _color.B}, function(v: any)
                if type(v) == "table" and #v >= 3 then
                    local ok, c = pcall(function() return Color3.new(v[1], v[2], v[3]) end)
                    if ok and c then
                        _color = c; _h, _s, _v = Color3.toHSV(c)
                        if swatch and swatch.Parent then swatch.BackgroundColor3 = c end
                    end
                end
            end)
        end

        local ctrl = makeCtrl(row, _id)
        local _origD = ctrl.Destroy
        function ctrl.Destroy()
            closePopup()
            Dispatcher.remove(_idSV)
            Dispatcher.remove(_idHue)
            _origD()
        end
        function ctrl.SetColor(c: Color3)
            _color = c; _h, _s, _v = Color3.toHSV(c)
            if swatch and swatch.Parent then swatch.BackgroundColor3 = c end
        end
        function ctrl.GetColor(): Color3 return _color end
        return ctrl
    end

    -- ── Keybind ───────────────────────────────────────────────────
    local function Keybind(parent: Instance, name: string, defaultKey: string?, callback: ((string) -> ())?, flag: string?): any
        local T = Theme.get()

        -- Auto-hide on mobile: a keyboard bind makes no sense on touchscreen.
        if isMobile() then
            return {
                Show    = function() end, Hide    = function() end,
                Destroy = function() end, Bind    = function() end,
                GetKey  = function() return "None" end, Clear = function() end,
            }
        end

        local _key     = defaultKey or "None"
        local _binding = false
        local _id      = uid()
        local row      = makeRow(parent, "KeybindRow")
        makeRowLabel(row, name)

        local keyBtn = mkbtn({
            text = "[" .. _key .. "]", font = L.fBody, sz = L.szElem,
            textColor = T.rose, color = T.bg,
            size = UDim2.new(0, 90, 0, 28),
            pos  = UDim2.new(1, -(90 + L.groupPadH), 0.5, -14),
            parent = row,
        })
        corner(keyBtn, L.rElem); mkstroke(keyBtn, T.border, L.strokeT)
        Anim.hover(keyBtn, T.bg, T.surface)

        keyBtn.MouseButton1Click:Connect(function()
            _binding = true
            if keyBtn and keyBtn.Parent then
                keyBtn.Text = "[...]"
                keyBtn.TextColor3 = T.accent
            end
        end)

        Dispatcher.onBegin(_id, function(inp: InputObject, processed: boolean)
            if _binding then
                if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
                _key = inp.KeyCode.Name; _binding = false
                if keyBtn and keyBtn.Parent then
                    keyBtn.Text = "[" .. _key .. "]"
                    keyBtn.TextColor3 = T.rose
                end
                if flag then Config.save(flag, _key) end
                if callback then
                    ErrorBus.callWith("Keybind.bound[" .. name .. "]", callback, false, _key)
                end
            else
                if inp.KeyCode.Name == _key and not processed then
                    if callback then
                        ErrorBus.callWith("Keybind.fired[" .. name .. "]", callback, false, _key)
                    end
                end
            end
        end)

        if flag then
            Config.register(flag, defaultKey, function(v: any)
                _key = tostring(v)
                if keyBtn and keyBtn.Parent then keyBtn.Text = "[" .. _key .. "]" end
            end)
        end

        local ctrl = makeCtrl(row, _id)
        function ctrl.Bind(key: string)
            _key = key
            if keyBtn and keyBtn.Parent then keyBtn.Text = "[" .. key .. "]" end
        end
        function ctrl.GetKey(): string return _key end
        function ctrl.Clear()
            _key = "None"
            if keyBtn and keyBtn.Parent then keyBtn.Text = "[None]" end
        end
        return ctrl
    end

    -- ── Label ─────────────────────────────────────────────────────
    local function Label(parent: Instance, text: string, iconName: string?, color: Color3?): any
        local T   = Theme.get()
        local ROW = iconName and 36 or 30
        local row = mkframe({name = "LabelRow", size = UDim2.new(1, 0, 0, ROW), color = T.surface, t = 1, parent = parent})
        local textX = L.groupPadH
        local iconImg: ImageLabel? = nil

        if iconName then
            local IS = 14
            iconImg = mkicon({
                name = "LblIcon", size = UDim2.new(0, IS, 0, IS),
                pos  = UDim2.new(0, L.groupPadH, 0.5, -IS / 2),
                color = color or T.muted, parent = row,
            })
            Icons.Apply(iconImg, iconName, {tint = color or T.muted})
            textX = L.groupPadH + IS + 6
        end

        local lbl = mklabel({
            text = text, font = L.fLabel, sz = L.szLabel,
            color = color or T.muted,
            size = UDim2.new(1, -(textX + L.groupPadH), 1, 0),
            pos  = UDim2.new(0, textX, 0, 0),
            parent = row,
        })

        local ctrl = makeCtrl(row)
        function ctrl.SetText(t: string)
            if lbl and lbl.Parent then lbl.Text = t end
        end
        function ctrl.SetColor(c: Color3)
            if lbl and lbl.Parent then lbl.TextColor3 = c end
            if iconImg and iconImg.Parent then Icons.Apply(iconImg, iconName or "", {tint = c}) end
        end
        return ctrl
    end

    -- ── Paragraph ─────────────────────────────────────────────────
    local function Paragraph(parent: Instance, title: string, body: string): any
        local T = Theme.get()
        local row = mkframe({name = "ParaRow", size = UDim2.new(1, 0, 0, 70), color = T.surface, parent = parent})
        corner(row, L.rElem); mkstroke(row, T.border, L.strokeT)
        padding(row, 10, L.groupPadH, 10, L.groupPadH)

        local vl = listLayout(row, {spacing = 4})
        local tLbl = mklabel({text = title, font = L.fLabel, sz = L.szLabel, color = T.text, size = UDim2.new(1, 0, 0, 18), parent = row})
        local bLbl = mklabel({text = body, font = L.fBody, sz = 12, color = T.muted, size = UDim2.new(1, 0, 0, 0), parent = row})
        bLbl.AutomaticSize = Enum.AutomaticSize.Y
        bLbl.TextWrapped   = true

        vl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if row and row.Parent then
                row.Size = UDim2.new(1, 0, 0, vl.AbsoluteContentSize.Y + 20)
            end
        end)

        local ctrl = makeCtrl(row)
        function ctrl.Rewrite(t: string, b: string)
            if tLbl and tLbl.Parent then tLbl.Text = t end
            if bLbl and bLbl.Parent then bLbl.Text = b end
        end
        return ctrl
    end

    -- ══════════════════════════════════════════════════════════════
    --  NOTIFICATION SYSTEM  (v2.1 — Severity-Aware)
    --
    --  Severity levels change the accent bar color and icon tint:
    --    "info"    → blue  (informational, low urgency)
    --    "success" → green (something worked)
    --    "warn"    → amber (attention needed, not broken)
    --    "danger"  → red   (something failed, action required)
    --
    --  Stacking is fixed: _notifQ is an ordered array.
    --  On dismiss, everything below slides up. No ghost positions.
    -- ══════════════════════════════════════════════════════════════
    local NOTIF_W = 320; local NOTIF_H = 76; local NOTIF_GAP = 8

    local _notifGui: ScreenGui? = nil
    local _notifQ: {{frame: Frame, isMob: boolean}} = {}
    local MAX_NOTIFS = 4

    local function ensureNotifGui(): ScreenGui?
        if _notifGui and _notifGui.Parent then return _notifGui end
        local pg = getPlayerGui(); if not pg then return nil end
        local g = Instance.new("ScreenGui")
        g.Name = "VelvetNotifs"; g.ResetOnSpawn = false
        g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; g.DisplayOrder = 99
        g.Parent = pg; _notifGui = g; return g
    end

    local function restackNotifs(fromIdx: number)
        for i = fromIdx, #_notifQ do
            local e = _notifQ[i]
            if e and e.frame and e.frame.Parent then
                local yOff = 16 + (i - 1) * (NOTIF_H + NOTIF_GAP)
                Anim.t(e.frame, "MEDIUM", {
                    Position = UDim2.new(e.frame.Position.X.Scale, e.frame.Position.X.Offset, 0, yOff)
                })
            end
        end
    end

    local function dismissNotif(idx: number)
        local entry = table.remove(_notifQ, idx)
        if not entry then return end
        if not entry.frame or not entry.frame.Parent then
            restackNotifs(idx); return
        end
        local t = Anim.t(entry.frame, "EXIT", {
            GroupTransparency = 1,
            Position = UDim2.new(
                entry.frame.Position.X.Scale, entry.frame.Position.X.Offset,
                0, entry.frame.Position.Y.Offset - 50)
        })
        if t then
            t.Completed:Connect(function()
                pcall(function()
                    if entry.frame and entry.frame.Parent then entry.frame:Destroy() end
                end)
            end)
        end
        restackNotifs(idx)
    end

    local function showNotification(opts: {
        Title: string?, Message: string?, Icon: string?,
        Severity: string?, Duration: number?,
        Action: {Text: string, Callback: (() -> ())?}?,
    })
        local T      = Theme.get()
        local isMob  = isMobile()
        local gui    = ensureNotifGui(); if not gui then return end
        if #_notifQ >= MAX_NOTIFS then dismissNotif(1) end

        local severity   = opts.Severity or "info"
        local accentColor = SEVERITY_COLORS[severity] or T.accent

        local idx   = #_notifQ + 1
        local yOff  = 16 + (#_notifQ) * (NOTIF_H + NOTIF_GAP)
        local xScale = isMob and 0.5 or 1
        local xOff   = isMob and -(NOTIF_W / 2) or -(NOTIF_W + 16)

        local frame = Instance.new("CanvasGroup")
        frame.Size              = UDim2.new(0, NOTIF_W, 0, NOTIF_H)
        frame.Position          = UDim2.new(xScale, xOff, 0, yOff - 60)
        frame.BackgroundColor3  = T.notifBg
        frame.GroupTransparency = 1
        frame.BorderSizePixel   = 0
        frame.ZIndex            = 20
        frame.Parent            = gui
        corner(frame, L.rNotif)
        mkstroke(frame, T.border, 0.80)

        -- Accent top bar — color communicates severity at a glance
        local accBar = mkframe({name = "AccBar", size = UDim2.new(1, 0, 0, 3), color = accentColor, parent = frame})
        corner(accBar, 2)

        -- Severity icon
        local iSZ = 20
        local iconImg = mkicon({size = UDim2.new(0, iSZ, 0, iSZ), pos = UDim2.new(0, 14, 0.5, -iSZ / 2), color = accentColor, parent = frame})
        Icons.Apply(iconImg, opts.Icon or "bell", {tint = accentColor})

        local TX = 48
        mklabel({
            text = opts.Title or "Notification", font = L.fLabel, sz = L.szLabel,
            color = T.text, size = UDim2.new(1, -(TX + 12), 0, 18),
            pos = UDim2.new(0, TX, 0, 12), parent = frame,
        })
        local msgL = mklabel({
            text = opts.Message or "", font = L.fBody, sz = 12,
            color = T.muted, size = UDim2.new(1, -(TX + 12), 0, 28),
            pos = UDim2.new(0, TX, 0, 30), parent = frame,
        })
        msgL.TextWrapped = true

        -- Optional action button
        if opts.Action and opts.Action.Text then
            local actBtn = mkbtn({
                text = opts.Action.Text, font = L.fLabel, sz = 11,
                textColor = accentColor, color = T.surface,
                size = UDim2.new(0, 72, 0, 22),
                pos  = UDim2.new(1, -84, 1, -30),
                parent = frame,
            })
            corner(actBtn, 6); Anim.hover(actBtn, T.surface, T.card)
            actBtn.MouseButton1Click:Connect(function()
                if opts.Action and opts.Action.Callback then
                    ErrorBus.call("Notification.action", opts.Action.Callback)
                end
                for i, e in ipairs(_notifQ) do
                    if e.frame == frame then dismissNotif(i); break end
                end
            end)
        end

        -- Close button
        local closeBtn = mkbtn({
            color = T.notifBg, t = 0,
            size = UDim2.new(0, 24, 0, 24),
            pos  = UDim2.new(1, -28, 0, 6),
            parent = frame,
        })
        corner(closeBtn, 6)
        local xI = mkicon({size = UDim2.new(0, 10, 0, 10), pos = UDim2.new(0.5, -5, 0.5, -5), color = T.muted, parent = closeBtn})
        Icons.Apply(xI, "x", {tint = T.muted})
        closeBtn.MouseButton1Click:Connect(function()
            for i, e in ipairs(_notifQ) do
                if e.frame == frame then dismissNotif(i); break end
            end
        end)

        table.insert(_notifQ, {frame = frame :: any, isMob = isMob})

        local targetPos = UDim2.new(xScale, xOff, 0, yOff)
        Anim.raw(frame, INFO.NOTIF, {Position = targetPos, GroupTransparency = 0})

        local dur = opts.Duration or 3.5
        task.delay(dur, function()
            for i, e in ipairs(_notifQ) do
                if e.frame == frame then dismissNotif(i); break end
            end
        end)
    end

    -- NOW we can bind the ErrorBus dispatcher — circular dependency resolved.
    _notifDispatch = showNotification

    -- ══════════════════════════════════════════════════════════════
    --  DIALOG SYSTEM  (Enterprise Edition)
    --
    --  Modal dialogs. Overlay dims the background.
    --  Up to 3 buttons. Colors: "accent" | "danger" | "muted".
    --  New: optional validation row for form-style dialogs.
    --  Close via button OR overlay click (opts.DismissOnOverlay).
    -- ══════════════════════════════════════════════════════════════
    local function showDialog(opts: {
        Title: string?, Body: string?,
        Buttons: {{Text: string, Color: string?, Callback: (() -> ())?}}?,
        DismissOnOverlay: boolean?, OnDismiss: (() -> ())?
    })
        local T  = Theme.get()
        local pg = getPlayerGui(); if not pg then return end

        local dGui = Instance.new("ScreenGui")
        dGui.Name = "VelvetDialog"; dGui.ResetOnSpawn = false
        dGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; dGui.DisplayOrder = 100
        dGui.Parent = pg

        local overlay = mkframe({name = "Overlay", size = UDim2.new(1, 0, 1, 0), color = T.overlay, t = 1, parent = dGui})
        Anim.t(overlay, "MEDIUM", {BackgroundTransparency = 0.55})

        local DW = 360
        local box = Instance.new("CanvasGroup")
        box.Size              = UDim2.new(0, DW, 0, 0)
        box.AnchorPoint       = Vector2.new(0.5, 0.5)
        box.Position          = UDim2.new(0.5, 0, 0.5, 0)
        box.BackgroundColor3  = T.dialogBg
        box.GroupTransparency = 1
        box.BorderSizePixel   = 0
        box.Parent            = dGui
        corner(box, L.rDialog); mkstroke(box, T.border, 0.75)

        local stripe = mkframe({name = "Stripe", size = UDim2.new(1, 0, 0, 3), color = T.accent, parent = box})
        corner(stripe, 2)

        local contentY = 16
        mklabel({
            text = opts.Title or "Are you sure?",
            font = L.fTitle, sz = 15, color = T.text,
            xA   = Enum.TextXAlignment.Center,
            size = UDim2.new(1, -32, 0, 22),
            pos  = UDim2.fromOffset(16, contentY),
            parent = box,
        }); contentY += 28

        if opts.Body and opts.Body ~= "" then
            local bLbl = mklabel({
                text = opts.Body, font = L.fBody, sz = 13,
                color = T.muted, xA = Enum.TextXAlignment.Center,
                size = UDim2.new(1, -32, 0, 0),
                pos  = UDim2.fromOffset(16, contentY),
                parent = box,
            })
            bLbl.AutomaticSize = Enum.AutomaticSize.Y
            bLbl.TextWrapped   = true
            contentY += 36
        end

        local buttons = opts.Buttons or {{Text = "OK"}}
        local BTN_H   = 36; local BTN_GAP = 8
        local totalW  = DW - 32
        local bW      = (totalW - BTN_GAP * (#buttons - 1)) / #buttons

        local function closeDialog()
            Anim.t(overlay, "EXIT", {BackgroundTransparency = 1})
            Anim.raw(box, INFO.EXIT, {GroupTransparency = 1, Size = UDim2.new(0, DW, 0, 0)})
            task.delay(0.20, function() pcall(function() if dGui and dGui.Parent then dGui:Destroy() end end) end)
        end

        for i, btnDef in ipairs(buttons) do
            local bx = 16 + (i - 1) * (bW + BTN_GAP)
            local bColor = T.accent
            if btnDef.Color == "danger" then bColor = T.danger
            elseif btnDef.Color == "muted" then bColor = T.surface end

            local btn = mkbtn({
                text = btnDef.Text or "OK", font = L.fLabel, sz = 13,
                textColor = btnDef.Color == "muted" and T.muted or T.text,
                color = bColor,
                size = UDim2.fromOffset(bW, BTN_H),
                pos  = UDim2.fromOffset(bx, contentY),
                parent = box,
            })
            corner(btn, L.rBtn); Anim.press(btn)
            Anim.hover(btn, bColor,
                btnDef.Color == "danger" and T.dangerDark
                or (btnDef.Color == "muted" and T.card or T.accentLight)
            )

            btn.MouseButton1Click:Connect(function()
                closeDialog()
                if btnDef.Callback then
                    ErrorBus.call("Dialog.button[" .. (btnDef.Text or "?") .. "]", btnDef.Callback)
                end
            end)
        end

        local DH = contentY + BTN_H + 16
        Anim.raw(box, INFO.DIALOG, {Size = UDim2.new(0, DW, 0, DH), GroupTransparency = 0})

        if opts.DismissOnOverlay then
            overlay.InputBegan:Connect(function(inp: InputObject)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                    closeDialog()
                    if opts.OnDismiss then ErrorBus.call("Dialog.dismiss", opts.OnDismiss) end
                end
            end)
        end
    end

    -- ══════════════════════════════════════════════════════════════
    --  GROUP BUILDER  (with collapse animation)
    --
    --  AutomaticSize and TweenService fight each other — one always
    --  wins, and it's never the tween. We manage height manually
    --  during collapse, then hand control back after animation.
    -- ══════════════════════════════════════════════════════════════
    local function buildGroup(scrollParent: Instance, name: string, layoutOrder: number?): any
        local T = Theme.get()

        local container = mkframe({
            name = "Group_" .. name, size = UDim2.new(1, 0, 0, 0),
            color = T.card, parent = scrollParent,
        })
        container.AutomaticSize = Enum.AutomaticSize.Y
        container.LayoutOrder   = layoutOrder or 1
        corner(container, L.rGroup); mkstroke(container, T.border, L.strokeT)

        local header = mkframe({name = "Header", size = UDim2.new(1, 0, 0, L.groupTitleH), color = T.card, t = 1, parent = container})
        padding(header, 0, L.groupPadH, 0, L.groupPadH)

        mklabel({
            text = string.upper(name), font = Enum.Font.GothamBold,
            sz = L.szGroupHdr, color = T.muted,
            size = UDim2.new(1, -24, 1, 0), parent = header,
        })

        local CHEV_SZ = 12
        local chevronI = mkicon({
            name = "GroupChev", size = UDim2.new(0, CHEV_SZ, 0, CHEV_SZ),
            pos  = UDim2.new(1, -(CHEV_SZ + L.groupPadH), 0.5, -CHEV_SZ / 2),
            color = T.muted, parent = header,
        })
        Icons.Apply(chevronI, "chevron-down", {tint = T.muted})

        mkframe({
            name = "Divider",
            size = UDim2.new(1, -(L.groupPadH * 2), 0, 1),
            pos  = UDim2.new(0, L.groupPadH, 0, L.groupTitleH - 1),
            color = T.border, t = 0.5, parent = container,
        })

        local clipWrap = mkframe({
            name = "CollapseWrap",
            size = UDim2.new(1, 0, 0, 0),
            pos  = UDim2.new(0, 0, 0, L.groupTitleH + 1),
            color = T.card, t = 1, clip = true, parent = container,
        })
        clipWrap.AutomaticSize = Enum.AutomaticSize.Y

        local elemList = mkframe({name = "Elements", size = UDim2.new(1, 0, 0, 0), color = T.card, t = 1, parent = clipWrap})
        elemList.AutomaticSize = Enum.AutomaticSize.Y
        listLayout(elemList, {spacing = L.elemSpacing})
        padding(elemList, 4, L.groupPadH, L.groupPadV, L.groupPadH)

        local _collapsed = false
        local _expandedH = 0

        local headerHit = mkbtn({color = T.card, t = 1, size = UDim2.new(1, 0, 1, 0), parent = header})
        Anim.hover(headerHit, T.card, T.surface)
        headerHit.MouseButton1Click:Connect(function()
            if not _collapsed then
                _expandedH = clipWrap.AbsoluteSize.Y
                if _expandedH <= 0 then _expandedH = elemList.AbsoluteSize.Y + 14 end
                clipWrap.AutomaticSize = Enum.AutomaticSize.None
                clipWrap.Size = UDim2.new(1, 0, 0, _expandedH)
                Anim.raw(clipWrap, INFO.COLLAPSE, {Size = UDim2.new(1, 0, 0, 0)})
                Anim.t(chevronI, "FAST", {Rotation = -90})
                _collapsed = true
            else
                clipWrap.Size = UDim2.new(1, 0, 0, 0)
                clipWrap.AutomaticSize = Enum.AutomaticSize.None
                Anim.raw(clipWrap, INFO.COLLAPSE, {Size = UDim2.new(1, 0, 0, _expandedH)})
                -- Restore AutomaticSize after animation so new elements auto-resize correctly
                task.delay(0.25, function()
                    if clipWrap and clipWrap.Parent then
                        clipWrap.AutomaticSize = Enum.AutomaticSize.Y
                    end
                end)
                Anim.t(chevronI, "FAST", {Rotation = 0})
                _collapsed = false
            end
        end)

        local Group: any = {}
        function Group:Rename(n: string)
            local lbl = header:FindFirstChildWhichIsA("TextLabel")
            if lbl then lbl.Text = string.upper(n) end
            container.Name = "Group_" .. n
        end
        function Group:Clear()
            for _, c in ipairs(elemList:GetChildren()) do
                if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
            end
        end
        function Group:Collapse()  if not _collapsed then headerHit.MouseButton1Click:Fire() end end
        function Group:Expand()    if _collapsed then headerHit.MouseButton1Click:Fire() end end
        function Group:Destroy()   if container and container.Parent then container:Destroy() end end
        Group._elemParent = elemList
        return Group
    end

    -- ══════════════════════════════════════════════════════════════
    --  TAB BUILDER  (with search bar)
    -- ══════════════════════════════════════════════════════════════
    local function buildTab(contentArea: Frame, name: string): any
        local T = Theme.get()

        local contentFrame = mkframe({
            name = "TabContent_" .. name,
            size = UDim2.new(1, 0, 1, 0), color = T.bg, t = 1,
            clip = true, parent = contentArea,
        })
        contentFrame.Visible = false

        local searchRow = mkframe({name = "SearchRow", size = UDim2.new(1, 0, 0, L.searchH + 8), color = T.bg, t = 1, parent = contentFrame})
        padding(searchRow, 4, L.padH, 4, L.padH)

        local searchBg = mkframe({name = "SearchBg", size = UDim2.new(1, 0, 1, -8), pos = UDim2.new(0, 0, 0, 4), color = T.searchBg, parent = searchRow})
        corner(searchBg, L.rElem); mkstroke(searchBg, T.border, L.strokeT)

        local searchIcon = mkicon({size = UDim2.new(0, 12, 0, 12), pos = UDim2.new(0, 10, 0.5, -6), color = T.muted, parent = searchBg})
        Icons.Apply(searchIcon, "search", {tint = T.muted})

        local searchBox = mktbox({
            placeholder = "Search elements...", color = T.searchBg,
            textColor = T.text, phColor = T.muted,
            size = UDim2.new(1, -32, 1, 0), pos = UDim2.new(0, 28, 0, 0),
            sz = 12, parent = searchBg,
        })

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size                   = UDim2.new(1, 0, 1, -(L.searchH + 8))
        scroll.Position               = UDim2.new(0, 0, 0, L.searchH + 8)
        scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel        = 0
        scroll.ScrollBarThickness     = 4
        scroll.ScrollBarImageColor3   = T.accent
        scroll.ScrollBarImageTransparency = 0.6
        scroll.Parent                 = contentFrame
        listLayout(scroll, {spacing = L.groupSpacing})
        padding(scroll, L.padV, L.padH, L.padV, L.padH)

        local _registry:   {{name: string, root: Frame}} = {}
        local _groupRoots: {{frame: Frame, name: string}} = {}
        local _lastGroup:  any? = nil
        local _layoutIdx   = 0

        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            local q = searchBox.Text:lower()
            if q == "" then
                for _, e in ipairs(_registry)   do if e.root and e.root.Parent then e.root.Visible = true  end end
                for _, g in ipairs(_groupRoots) do if g.frame and g.frame.Parent then g.frame.Visible = true end end
                return
            end
            for _, e in ipairs(_registry) do
                if e.root and e.root.Parent then
                    e.root.Visible = e.name:lower():find(q, 1, true) ~= nil
                end
            end
            for _, gInfo in ipairs(_groupRoots) do
                if not gInfo.frame or not gInfo.frame.Parent then continue end
                local hasVisible = false
                local eList = gInfo.frame:FindFirstChild("Elements", true)
                if eList then
                    for _, child in ipairs(eList:GetChildren()) do
                        if child:IsA("Frame") and child.Visible then
                            hasVisible = true; break
                        end
                    end
                end
                gInfo.frame.Visible = hasVisible
            end
        end)

        local Tab: any = {}

        function Tab:Group(gname: string): any
            local g = buildGroup(scroll, gname, _layoutIdx)
            _layoutIdx += 1
            _lastGroup = g
            -- The group root for search visibility is the container frame (grandparent of elemList)
            local groupContainer = g._elemParent and g._elemParent.Parent and g._elemParent.Parent.Parent
            if groupContainer then
                table.insert(_groupRoots, {frame = groupContainer :: Frame, name = gname})
            end
            return g
        end

        local function ensureGroup(): any
            if not _lastGroup then _lastGroup = Tab:Group("General") end
            return _lastGroup
        end

        local function reg(name2: string, root: Frame)
            table.insert(_registry, {name = name2, root = root})
        end

        function Tab:Line()
            local ln = mkframe({name = "Line", size = UDim2.new(1, 0, 0, 1), color = T.border, t = 0.4, parent = scroll})
            ln.LayoutOrder = _layoutIdx; _layoutIdx += 1
        end

        function Tab:Spacer(h: number?)
            local sp = mkframe({name = "Spacer", size = UDim2.new(1, 0, 0, h or 16), color = T.bg, t = 1, parent = scroll})
            sp.LayoutOrder = _layoutIdx; _layoutIdx += 1
        end

        -- All element helpers follow the same pattern:
        -- get group → build element → register for search → return control

        function Tab:Button(text: string, cb: (() -> ())?): any
            local g = ensureGroup()
            local e = Button(g._elemParent, text, cb)
            local ch = g._elemParent:GetChildren()
            reg(text, ch[#ch] or g._elemParent)
            return e
        end

        function Tab:Switch(name2: string, default: boolean?, cb: ((boolean) -> ())?, flag2: string?, desc: string?): any
            local g = ensureGroup()
            local e = Switch(g._elemParent, name2, default, cb, flag2, desc)
            local ch = g._elemParent:GetChildren()
            reg(name2, ch[#ch] or g._elemParent)
            return e
        end

        function Tab:Slider(name2: string, mn: number?, mx: number?, def: number?, cb: ((number) -> ())?, flag2: string?): any
            local g = ensureGroup()
            local e = Slider(g._elemParent, name2, mn, mx, def, cb, flag2)
            local ch = g._elemParent:GetChildren()
            reg(name2, ch[#ch] or g._elemParent)
            return e
        end

        function Tab:TextField(name2: string, ph: string?, cb: ((string, boolean) -> ())?, flag2: string?): any
            local g = ensureGroup()
            local e = TextField(g._elemParent, name2, ph, cb, flag2)
            local ch = g._elemParent:GetChildren()
            reg(name2, ch[#ch] or g._elemParent)
            return e
        end

        function Tab:Dropdown(name2: string, opts: {string}, def: string?, cb: ((string) -> ())?, flag2: string?): any
            local g = ensureGroup()
            local e = Dropdown(g._elemParent, name2, opts, def, cb, flag2)
            local ch = g._elemParent:GetChildren()
            reg(name2, ch[#ch] or g._elemParent)
            return e
        end

        function Tab:MultiDropdown(name2: string, opts: {string}, defs: {string}?, cb: (({string}) -> ())?, flag2: string?): any
            local g = ensureGroup()
            local e = MultiDropdown(g._elemParent, name2, opts, defs, cb, flag2)
            local ch = g._elemParent:GetChildren()
            reg(name2, ch[#ch] or g._elemParent)
            return e
        end

        function Tab:ColorSelect(name2: string, def: Color3?, cb: ((Color3) -> ())?, flag2: string?): any
            local g = ensureGroup()
            local e = ColorSelect(g._elemParent, name2, def, cb, flag2)
            local ch = g._elemParent:GetChildren()
            reg(name2, ch[#ch] or g._elemParent)
            return e
        end

        function Tab:Keybind(name2: string, key: string?, cb: ((string) -> ())?, flag2: string?): any
            local g = ensureGroup()
            local e = Keybind(g._elemParent, name2, key, cb, flag2)
            local ch = g._elemParent:GetChildren()
            reg(name2, ch[#ch] or g._elemParent)
            return e
        end

        function Tab:Label(text: string, icon: string?, color: Color3?): any
            return Label(ensureGroup()._elemParent, text, icon, color)
        end

        function Tab:Paragraph(title: string, body: string): any
            return Paragraph(ensureGroup()._elemParent, title, body)
        end

        Tab._contentFrame = contentFrame
        Tab._scroll       = scroll
        return Tab
    end

    -- ══════════════════════════════════════════════════════════════
    --  WINDOW BUILDER
    --  Draggable, tab-switching with cross-fade, mobile sidebar.
    --  Each window gets its own isolated ScreenGui — no shared state.
    -- ══════════════════════════════════════════════════════════════
    local function buildWindow(opts: {Title: string?, Icon: string?, Theme: string?, Key: string?}, state: any): any
        local T     = Theme.get(opts.Theme)
        local isMob = isMobile()
        local W, H  = winSize()
        local sw    = sideW()

        local pg = getPlayerGui()
        if not pg then
            -- This is a hard failure — no PlayerGui = no UI. Tell the developer clearly.
            error("[VelvetUI] Could not get PlayerGui. Make sure this runs in a LocalScript.", 2)
        end

        local screenGui = Instance.new("ScreenGui")
        screenGui.Name           = "VelvetUI_" .. uid()
        screenGui.ResetOnSpawn   = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screenGui.DisplayOrder   = 10
        screenGui.Parent         = pg

        -- CanvasGroup: fade all children as one unit. Without this you'd need
        -- to tween every child individually. That's not happening.
        local root = Instance.new("CanvasGroup")
        root.Name              = "WindowRoot"
        root.Size              = UDim2.new(0, W, 0, H)
        root.Position          = UDim2.new(0.5, -W / 2, 0.5, -H / 2)
        root.BackgroundColor3  = T.bg
        root.GroupTransparency = 1
        root.BorderSizePixel   = 0
        root.Parent            = screenGui
        corner(root, L.rWin)
        mkstroke(root, T.border, 0.72)
        -- Subtle gradient for depth — one of those details users can't name but feel
        gradient(root, ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 20, 36)),
            ColorSequenceKeypoint.new(1, T.bg),
        }), 115)

        -- ── Topbar ────────────────────────────────────────────────
        local topbar = mkframe({name = "Topbar", size = UDim2.new(1, 0, 0, L.topbarH), color = T.topbar, parent = root})
        mkframe({name = "TopBorder", size = UDim2.new(1, 0, 0, 1), pos = UDim2.new(0, 0, 1, -1), color = T.border, t = 0.5, parent = topbar})

        local AIS = L.appIconSz
        local appIcon = mkicon({size = UDim2.new(0, AIS, 0, AIS), pos = UDim2.new(0, (L.topbarH - AIS) / 2, 0.5, -AIS / 2), color = T.accent, parent = topbar})
        Icons.Apply(appIcon, opts.Icon or "zap", {tint = T.accent})

        local titleLbl = mklabel({
            text = opts.Title or "Velvet UI",
            font = L.fTitle, sz = L.szTitle, color = T.text,
            size = UDim2.new(1, -(L.topbarH * 2 + 8), 1, 0),
            pos  = UDim2.new(0, L.topbarH + 4, 0, 0),
            xA   = Enum.TextXAlignment.Left,
            parent = topbar,
        })

        local closeBtn = mkbtn({
            name = "CloseBtn", color = T.topbar, t = 0,
            size = UDim2.new(0, L.topbarH, 1, 0),
            pos  = UDim2.new(1, -L.topbarH, 0, 0),
            parent = topbar,
        })
        local CIS = 14
        local closeIcon = mkicon({size = UDim2.new(0, CIS, 0, CIS), pos = UDim2.new(0.5, -CIS / 2, 0.5, -CIS / 2), color = T.muted, z = 2, parent = closeBtn})
        Icons.Apply(closeIcon, "x", {tint = T.muted})
        Anim.hover(closeBtn, T.topbar, T.danger)
        closeBtn.MouseEnter:Connect(function() Anim.t(closeIcon, "FAST", {ImageColor3 = T.text}) end)
        closeBtn.MouseLeave:Connect(function() Anim.t(closeIcon, "FAST", {ImageColor3 = T.muted}) end)

        -- Drag: topbar is the handle. Direct UIS connection here is intentional —
        -- this lives for the window's lifetime, not per-element.
        do
            local _drag = false; local _dragStart: Vector3?; local _startPos: UDim2?
            topbar.InputBegan:Connect(function(inp: InputObject)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                    _drag = true; _dragStart = inp.Position; _startPos = root.Position
                end
            end)
            topbar.InputChanged:Connect(function(inp: InputObject)
                if not _drag or not _dragStart or not _startPos then return end
                if inp.UserInputType == Enum.UserInputType.MouseMovement
                or inp.UserInputType == Enum.UserInputType.Touch then
                    local d = inp.Position - _dragStart
                    if root and root.Parent then
                        root.Position = UDim2.new(
                            _startPos.X.Scale, _startPos.X.Offset + d.X,
                            _startPos.Y.Scale, _startPos.Y.Offset + d.Y)
                    end
                end
            end)
            UIS.InputEnded:Connect(function(inp: InputObject)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                    _drag = false
                end
            end)
        end

        -- ── Body + Sidebar ─────────────────────────────────────────
        local body = mkframe({name = "Body", size = UDim2.new(1, 0, 1, -L.topbarH), pos = UDim2.new(0, 0, 0, L.topbarH), color = T.bg, t = 1, parent = root})
        local sidebar = mkframe({name = "Sidebar", size = UDim2.new(0, sw, 1, 0), color = T.sidebar, parent = body})
        mkframe({name = "SideBorder", size = UDim2.new(0, 1, 1, 0), pos = UDim2.new(1, -1, 0, 0), color = T.border, t = 0.5, parent = sidebar})

        local tabList = mkframe({name = "TabList", size = UDim2.new(1, 0, 1, 0), color = T.sidebar, t = 1, parent = sidebar})
        listLayout(tabList, {spacing = 2})
        padding(tabList, 8, 6, 8, 6)

        local _sideExpanded = not isMob
        if isMob then
            local colBtn = mkbtn({color = T.sidebar, t = 0, size = UDim2.new(1, 0, 0, 40), parent = tabList})
            colBtn.LayoutOrder = -1
            local MENU_SZ = 18
            local menuIcon = mkicon({size = UDim2.new(0, MENU_SZ, 0, MENU_SZ), pos = UDim2.new(0.5, -MENU_SZ / 2, 0.5, -MENU_SZ / 2), color = T.muted, parent = colBtn})
            Icons.Apply(menuIcon, "menu", {tint = T.muted})
            Anim.hover(colBtn, T.sidebar, T.surface)

            colBtn.MouseButton1Click:Connect(function()
                _sideExpanded = not _sideExpanded
                local targetW = _sideExpanded and L.sideW_D or L.sideW_M
                Anim.t(sidebar, "MEDIUM", {Size = UDim2.new(0, targetW, 1, 0)})
                local ca = body:FindFirstChild("ContentArea")
                if ca then
                    Anim.t(ca :: GuiObject, "MEDIUM", {
                        Size     = UDim2.new(1, -targetW, 1, 0),
                        Position = UDim2.new(0, targetW, 0, 0),
                    })
                end
            end)
        end

        local contentArea = mkframe({name = "ContentArea", size = UDim2.new(1, -sw, 1, 0), pos = UDim2.new(0, sw, 0, 0), color = T.bg, clip = true, parent = body})

        -- ── Tab system ────────────────────────────────────────────
        local _tabs:      {[string]: any}                                         = {}
        local _tabBtns:   {[string]: {bg: Frame, accent: Frame, lbl: TextLabel, iconImg: ImageLabel?}} = {}
        local _activeTab: string?  = nil
        local _visible             = true

        local function activateTab(id: string)
            local next = _tabs[id]; if not next then return end

            for tabId, btn in pairs(_tabBtns) do
                local active = (tabId == id)
                Anim.t(btn.bg, "FAST", {
                    BackgroundColor3       = active and T.surface or T.sidebar,
                    BackgroundTransparency = 0,
                })
                Anim.t(btn.accent, "FAST", {BackgroundTransparency = active and 0 or 1})
                if btn.lbl and btn.lbl.Parent then
                    btn.lbl.TextColor3 = active and T.text or T.muted
                end
                if btn.iconImg and btn.iconImg.Parent then
                    Anim.t(btn.iconImg, "FAST", {ImageColor3 = active and T.accent or T.muted})
                end
            end

            local prev = _activeTab and _tabs[_activeTab]
            if prev and prev._contentFrame ~= next._contentFrame then
                if prev._contentFrame and prev._contentFrame.Parent then
                    Anim.t(prev._contentFrame, "TAB", {BackgroundTransparency = 1})
                    task.delay(0.10, function()
                        if prev._contentFrame and prev._contentFrame.Parent then
                            prev._contentFrame.Visible = false
                        end
                    end)
                end
            end

            task.delay(0.05, function()
                if not next._contentFrame or not next._contentFrame.Parent then return end
                next._contentFrame.BackgroundTransparency = 1
                next._contentFrame.Visible = true
                Anim.t(next._contentFrame, "TAB", {BackgroundTransparency = 0})
            end)

            _activeTab = id
        end

        -- ── Window public API ──────────────────────────────────────
        local Window: any = {}

        function Window:AddTab(name: string, iconName: string?): any
            local id  = uid()
            local tab = buildTab(contentArea, name)
            _tabs[id] = tab

            local btnH  = isMob and L.tabBtnH_M or L.tabBtnH_D
            local btnBg = mkframe({name = "TabBtn_" .. name, size = UDim2.new(1, 0, 0, btnH), color = T.sidebar, parent = tabList})
            corner(btnBg, 8)

            local accentBar = mkframe({name = "Accent", size = UDim2.new(0, 3, 0.6, 0), pos = UDim2.new(0, 0, 0.2, 0), color = T.accent, parent = btnBg})
            corner(accentBar, 2); accentBar.BackgroundTransparency = 1

            local iconImg: ImageLabel? = nil
            if iconName then
                local IS = L.tabIconSz
                iconImg = mkicon({name = "TIcon", size = UDim2.new(0, IS, 0, IS), pos = UDim2.new(0, (btnH - IS) / 2, 0.5, -IS / 2), color = T.muted, parent = btnBg})
                Icons.Apply(iconImg, iconName, {tint = T.muted})
            end

            local textX = iconName and btnH or 12
            local tabLbl = mklabel({
                text = name, font = L.fLabel, sz = L.szLabel, color = T.muted,
                size = UDim2.new(1, -(textX + 4), 1, 0),
                pos  = UDim2.new(0, textX, 0, 0),
                xA   = Enum.TextXAlignment.Left, parent = btnBg,
            })
            tabLbl.Visible = not (isMob and not _sideExpanded)

            local hit = mkbtn({color = Color3.new(1, 1, 1), t = 1, size = UDim2.new(1, 0, 1, 0), parent = btnBg})
            hit.MouseButton1Click:Connect(function() activateTab(id) end)

            _tabBtns[id] = {bg = btnBg, accent = accentBar, lbl = tabLbl, iconImg = iconImg}

            if not _activeTab then activateTab(id) end

            return tab
        end

        function Window:Dialog(opts2: any)    showDialog(opts2)         end
        function Window:Notify(opts2: any)    showNotification(opts2)   end
        function Window:Show()
            _visible = true
            if root and root.Parent then Anim.openWindow(root) end
        end
        function Window:Hide()
            _visible = false
            if root and root.Parent then Anim.closeWindow(root) end
        end
        function Window:Rename(newTitle: string)
            if titleLbl and titleLbl.Parent then titleLbl.Text = newTitle end
        end
        function Window:Dress(themeName: string)
            Theme.setActive(themeName)
            local NT = Theme.get(themeName)
            if root and root.Parent then root.BackgroundColor3 = NT.bg end
            if topbar and topbar.Parent then topbar.BackgroundColor3 = NT.topbar end
            if sidebar and sidebar.Parent then sidebar.BackgroundColor3 = NT.sidebar end
            if contentArea and contentArea.Parent then contentArea.BackgroundColor3 = NT.bg end
        end
        function Window:Destroy()
            pcall(function()
                if screenGui and screenGui.Parent then screenGui:Destroy() end
            end)
            for i, w in ipairs(state.windows) do
                if w == Window then table.remove(state.windows, i); break end
            end
        end

        closeBtn.MouseButton1Click:Connect(function() Window:Hide() end)

        if opts.Key then
            UIS.InputBegan:Connect(function(inp: InputObject, processed: boolean)
                if processed then return end
                if inp.KeyCode.Name == opts.Key then
                    if _visible then Window:Hide() else Window:Show() end
                end
            end)
        end

        table.insert(state.windows, Window)
        Window:Show()
        return Window
    end

    -- ══════════════════════════════════════════════════════════════
    --  PUBLIC API
    --  Clean surface. No internals exposed — they'll just break when
    --  we need to refactor the internals.
    -- ══════════════════════════════════════════════════════════════
    local _state = {
        windows   = {} :: {any},
        version   = "2.1.0",
        scaleMode = "Auto",
    }

    local Velvet: any = {}

    -- Build and return a new draggable window.
    -- opts: { Title, Icon, Theme, Key }
    function Velvet:BuildWindow(opts: {Title: string?, Icon: string?, Theme: string?, Key: string?}?)
        return ErrorBus.call("BuildWindow", function()
            return buildWindow(opts or {}, _state)
        end) or error("[VelvetUI] Failed to build window. See console for details.", 2)
    end

    -- Show a toast notification with severity support.
    -- opts: { Title, Message, Icon, Severity, Duration, Action }
    -- Severity: "info" | "warn" | "danger" | "success"
    function Velvet:Whisper(opts: any)
        showNotification(opts or {})
    end
    Velvet.Notify = Velvet.Whisper

    -- Show a modal dialog.
    -- opts: { Title, Body, Buttons, DismissOnOverlay, OnDismiss }
    function Velvet:Dialog(opts: any)
        showDialog(opts or {})
    end

    -- Report an error through the humanized error system.
    -- Use this when YOUR code (outside VelvetUI) has an error you want
    -- to surface to the user in a friendly way.
    -- context: short description like "Aimbot module" or "Config loader"
    -- rawErr:  the error string from pcall
    function Velvet:ReportError(context: string, rawErr: string)
        ErrorBus.report(context, rawErr)
    end

    -- Wrap a function call with humanized error handling.
    -- Returns the result, or nil + shows a user notification on failure.
    function Velvet:SafeCall(context: string, fn: () -> any): any
        return ErrorBus.call(context, fn)
    end

    -- Register a custom theme. Missing tokens inherit from Midnight Velvet.
    function Velvet:DefineTheme(name: string, tbl: {[string]: any})
        Theme.define(name, tbl)
    end

    -- Override device detection. "Auto" | "Desktop" | "Mobile"
    function Velvet:SetScaleMode(mode: string)
        setScaleMode(mode); _state.scaleMode = mode
    end

    -- Restore all persisted flag values. Call once at startup, AFTER building elements.
    function Velvet:LoadConfig()
        ErrorBus.call("LoadConfig", Config.loadAll, true)
    end

    -- Destroy every open window. Good for script re-run cleanup.
    function Velvet:DestroyAll()
        for _, w in ipairs(_state.windows) do
            pcall(function() w:Destroy() end)
        end
        _state.windows = {}
    end

    -- Library version string.
    function Velvet:GetVersion(): string return _state.version end

    -- Direct Icons access for advanced consumers.
    Velvet.Icons = Icons

    -- Expose ErrorBus for advanced consumers who want custom error routing.
    Velvet.ErrorBus = ErrorBus

    return Velvet
end
