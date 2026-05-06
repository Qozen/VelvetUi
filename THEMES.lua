--!strict
--[[
    VelvetUI v2.1 — THEMES.lua  ·  Enterprise Edition
    ────────────────────────────────────────────────────────────────
    All 6 extra palettes, upgraded with v2.1 tokens:
      · dangerDark   — darker hover state for danger buttons
      · info         — informational accent (used by ErrorBus)

    USAGE:
        local Velvet = loadstring(readfile("VelvetUI.lua"))()(Icons)
        local Themes = loadstring(readfile("THEMES.lua"))()
        Themes.registerAll(Velvet)

    AVAILABLE THEMES:
        "Midnight Velvet"   built-in to init.lua
        "Neon Abyss"        dark teal/cyan rave energy
        "Rose Gold"         warm blush + gold
        "Ocean Depth"       deep navy + ice-blue
        "Crimson Night"     dark grey + vivid red
        "Jade Forest"       dark green, earthy
        "Monochrome"        pure greyscale, zero colour

    NOTES:
        · Missing tokens auto-inherit from Midnight Velvet.
        · Partial themes work — only override what changes.
        · All palettes are table.freeze'd after registration.
        · dangerDark is used for danger button hover states in dialogs.
        · info is used by ErrorBus severity colouring.
--]]

local Themes = {}

-- ── Neon Abyss ────────────────────────────────────────────────────────────────
-- Dark navy base, electric cyan accent.
-- Every element pops like a Tokyo arcade at 2am.
local NEON_ABYSS = {
    bg          = Color3.fromRGB(10,  11,  20),
    surface     = Color3.fromRGB(18,  20,  34),
    card        = Color3.fromRGB(22,  25,  42),
    sidebar     = Color3.fromRGB(14,  15,  26),
    topbar      = Color3.fromRGB(12,  13,  22),
    accent      = Color3.fromRGB(0,   210, 200),
    accentLight = Color3.fromRGB(40,  230, 220),
    accentDark  = Color3.fromRGB(0,   170, 160),
    rose        = Color3.fromRGB(255, 100, 180),
    roseDark    = Color3.fromRGB(200, 70,  140),
    border      = Color3.fromRGB(30,  35,  62),
    borderFocus = Color3.fromRGB(0,   210, 200),
    text        = Color3.fromRGB(220, 240, 248),
    muted       = Color3.fromRGB(100, 120, 150),
    switchOn    = Color3.fromRGB(0,   210, 200),
    switchOff   = Color3.fromRGB(42,  48,  72),
    sliderFill  = Color3.fromRGB(0,   210, 200),
    sliderTrack = Color3.fromRGB(30,  35,  62),
    notifBg     = Color3.fromRGB(18,  20,  34),
    searchBg    = Color3.fromRGB(15,  17,  28),
    dialogBg    = Color3.fromRGB(20,  22,  38),
    -- v2.1 tokens
    dangerDark  = Color3.fromRGB(200, 50,  50),
    info        = Color3.fromRGB(0,   210, 200),  -- cyan as info in this palette
}

-- ── Rose Gold ─────────────────────────────────────────────────────────────────
-- Warm pinks + champagne. Passes the vibe check every time.
local ROSE_GOLD = {
    bg          = Color3.fromRGB(20,  14,  16),
    surface     = Color3.fromRGB(32,  22,  26),
    card        = Color3.fromRGB(38,  27,  32),
    sidebar     = Color3.fromRGB(26,  17,  21),
    topbar      = Color3.fromRGB(22,  15,  18),
    accent      = Color3.fromRGB(220, 140, 120),
    accentLight = Color3.fromRGB(240, 165, 145),
    accentDark  = Color3.fromRGB(185, 110, 90),
    rose        = Color3.fromRGB(200, 170, 100),
    roseDark    = Color3.fromRGB(165, 138, 75),
    border      = Color3.fromRGB(58,  38,  46),
    borderFocus = Color3.fromRGB(220, 140, 120),
    text        = Color3.fromRGB(248, 235, 232),
    muted       = Color3.fromRGB(160, 120, 115),
    switchOn    = Color3.fromRGB(220, 140, 120),
    switchOff   = Color3.fromRGB(70,  46,  55),
    sliderFill  = Color3.fromRGB(220, 140, 120),
    sliderTrack = Color3.fromRGB(58,  38,  46),
    notifBg     = Color3.fromRGB(32,  22,  26),
    searchBg    = Color3.fromRGB(26,  18,  22),
    dialogBg    = Color3.fromRGB(34,  23,  28),
    -- v2.1 tokens
    dangerDark  = Color3.fromRGB(200, 50,  50),
    info        = Color3.fromRGB(180, 140, 220),
}

-- ── Ocean Depth ───────────────────────────────────────────────────────────────
-- Navy so dark it's almost black, ice-blue accents.
-- Calm, technical, authoritative. Like Bloomberg Terminal but beautiful.
local OCEAN_DEPTH = {
    bg          = Color3.fromRGB(8,   14,  26),
    surface     = Color3.fromRGB(14,  22,  40),
    card        = Color3.fromRGB(18,  28,  50),
    sidebar     = Color3.fromRGB(11,  18,  33),
    topbar      = Color3.fromRGB(9,   15,  28),
    accent      = Color3.fromRGB(80,  180, 255),
    accentLight = Color3.fromRGB(110, 200, 255),
    accentDark  = Color3.fromRGB(55,  150, 220),
    rose        = Color3.fromRGB(130, 220, 210),
    roseDark    = Color3.fromRGB(100, 185, 175),
    border      = Color3.fromRGB(24,  40,  72),
    borderFocus = Color3.fromRGB(80,  180, 255),
    text        = Color3.fromRGB(210, 230, 255),
    muted       = Color3.fromRGB(90,  115, 160),
    switchOn    = Color3.fromRGB(80,  180, 255),
    switchOff   = Color3.fromRGB(34,  54,  88),
    sliderFill  = Color3.fromRGB(80,  180, 255),
    sliderTrack = Color3.fromRGB(24,  40,  72),
    notifBg     = Color3.fromRGB(14,  22,  40),
    searchBg    = Color3.fromRGB(11,  18,  34),
    dialogBg    = Color3.fromRGB(16,  26,  46),
    -- v2.1 tokens
    dangerDark  = Color3.fromRGB(200, 50,  50),
    info        = Color3.fromRGB(80,  180, 255),
}

-- ── Crimson Night ─────────────────────────────────────────────────────────────
-- Dark charcoal + vivid red. The classic.
-- This one doesn't look like a 2019 FE GUI. Promise.
local CRIMSON_NIGHT = {
    bg          = Color3.fromRGB(12,  11,  11),
    surface     = Color3.fromRGB(22,  19,  19),
    card        = Color3.fromRGB(28,  24,  24),
    sidebar     = Color3.fromRGB(17,  14,  14),
    topbar      = Color3.fromRGB(14,  11,  11),
    accent      = Color3.fromRGB(220, 55,  55),
    accentLight = Color3.fromRGB(240, 75,  75),
    accentDark  = Color3.fromRGB(180, 38,  38),
    rose        = Color3.fromRGB(220, 140, 80),
    roseDark    = Color3.fromRGB(180, 110, 55),
    border      = Color3.fromRGB(44,  34,  34),
    borderFocus = Color3.fromRGB(220, 55,  55),
    text        = Color3.fromRGB(240, 232, 232),
    muted       = Color3.fromRGB(145, 120, 120),
    switchOn    = Color3.fromRGB(220, 55,  55),
    switchOff   = Color3.fromRGB(62,  44,  44),
    sliderFill  = Color3.fromRGB(220, 55,  55),
    sliderTrack = Color3.fromRGB(44,  34,  34),
    notifBg     = Color3.fromRGB(22,  19,  19),
    searchBg    = Color3.fromRGB(18,  15,  15),
    dialogBg    = Color3.fromRGB(25,  21,  21),
    -- v2.1 tokens
    dangerDark  = Color3.fromRGB(180, 38,  38),  -- same as accentDark in this palette
    info        = Color3.fromRGB(100, 150, 220),
}

-- ── Jade Forest ───────────────────────────────────────────────────────────────
-- Dark with soft greens. Earthy, calm, distinctly not a typical exploit GUI.
-- That's intentional.
local JADE_FOREST = {
    bg          = Color3.fromRGB(10,  16,  13),
    surface     = Color3.fromRGB(17,  26,  21),
    card        = Color3.fromRGB(22,  33,  27),
    sidebar     = Color3.fromRGB(13,  20,  16),
    topbar      = Color3.fromRGB(11,  17,  14),
    accent      = Color3.fromRGB(72,  200, 130),
    accentLight = Color3.fromRGB(95,  220, 155),
    accentDark  = Color3.fromRGB(52,  165, 105),
    rose        = Color3.fromRGB(175, 215, 135),
    roseDark    = Color3.fromRGB(140, 175, 105),
    border      = Color3.fromRGB(30,  50,  38),
    borderFocus = Color3.fromRGB(72,  200, 130),
    text        = Color3.fromRGB(215, 240, 225),
    muted       = Color3.fromRGB(95,  135, 110),
    switchOn    = Color3.fromRGB(72,  200, 130),
    switchOff   = Color3.fromRGB(38,  65,  50),
    sliderFill  = Color3.fromRGB(72,  200, 130),
    sliderTrack = Color3.fromRGB(30,  50,  38),
    notifBg     = Color3.fromRGB(17,  26,  21),
    searchBg    = Color3.fromRGB(13,  21,  17),
    dialogBg    = Color3.fromRGB(19,  30,  24),
    -- v2.1 tokens
    dangerDark  = Color3.fromRGB(200, 50,  50),
    info        = Color3.fromRGB(72,  200, 130),
}

-- ── Monochrome ────────────────────────────────────────────────────────────────
-- Zero colour. Pure contrast. Absolute discipline.
-- For scripts where the content speaks, not the theme.
local MONOCHROME = {
    bg          = Color3.fromRGB(10,  10,  10),
    surface     = Color3.fromRGB(20,  20,  20),
    card        = Color3.fromRGB(26,  26,  26),
    sidebar     = Color3.fromRGB(15,  15,  15),
    topbar      = Color3.fromRGB(12,  12,  12),
    accent      = Color3.fromRGB(220, 220, 220),
    accentLight = Color3.fromRGB(240, 240, 240),
    accentDark  = Color3.fromRGB(170, 170, 170),
    rose        = Color3.fromRGB(180, 180, 180),
    roseDark    = Color3.fromRGB(140, 140, 140),
    border      = Color3.fromRGB(38,  38,  38),
    borderFocus = Color3.fromRGB(200, 200, 200),
    text        = Color3.fromRGB(240, 240, 240),
    muted       = Color3.fromRGB(130, 130, 130),
    switchOn    = Color3.fromRGB(200, 200, 200),
    switchOff   = Color3.fromRGB(55,  55,  55),
    sliderFill  = Color3.fromRGB(200, 200, 200),
    sliderThumb = Color3.fromRGB(255, 255, 255),
    sliderTrack = Color3.fromRGB(40,  40,  40),
    notifBg     = Color3.fromRGB(22,  22,  22),
    searchBg    = Color3.fromRGB(16,  16,  16),
    dialogBg    = Color3.fromRGB(24,  24,  24),
    -- In monochrome, severity colours are subtle greys instead of vivid.
    -- They still differentiate — just without the colour drama.
    success     = Color3.fromRGB(210, 210, 210),
    warning     = Color3.fromRGB(200, 200, 200),
    danger      = Color3.fromRGB(230, 230, 230),
    info        = Color3.fromRGB(185, 185, 185),
    -- v2.1 tokens
    dangerDark  = Color3.fromRGB(180, 180, 180),
}

-- ── Public API ────────────────────────────────────────────────────────────────

-- Register a single named theme into a Velvet instance.
function Themes.register(Velvet: any, name: string, palette: {[string]: any})
    Velvet:DefineTheme(name, palette)
end

-- Register ALL bundled themes at once. This is the recommended call.
-- After this, any name in Themes.list() is valid in BuildWindow({ Theme = "..." }).
function Themes.registerAll(Velvet: any)
    Velvet:DefineTheme("Neon Abyss",    NEON_ABYSS)
    Velvet:DefineTheme("Rose Gold",     ROSE_GOLD)
    Velvet:DefineTheme("Ocean Depth",   OCEAN_DEPTH)
    Velvet:DefineTheme("Crimson Night", CRIMSON_NIGHT)
    Velvet:DefineTheme("Jade Forest",   JADE_FOREST)
    Velvet:DefineTheme("Monochrome",    MONOCHROME)
end

-- Get the raw palette table without registering it.
-- Useful for composing a new theme on top of an existing one.
function Themes.getPalette(name: string): {[string]: any}?
    local palettes: {[string]: {[string]: any}} = {
        ["Neon Abyss"]    = NEON_ABYSS,
        ["Rose Gold"]     = ROSE_GOLD,
        ["Ocean Depth"]   = OCEAN_DEPTH,
        ["Crimson Night"] = CRIMSON_NIGHT,
        ["Jade Forest"]   = JADE_FOREST,
        ["Monochrome"]    = MONOCHROME,
    }
    return palettes[name]
end

-- All available theme names including the built-in Midnight Velvet.
function Themes.list(): {string}
    return {
        "Midnight Velvet",
        "Neon Abyss",
        "Rose Gold",
        "Ocean Depth",
        "Crimson Night",
        "Jade Forest",
        "Monochrome",
    }
end

return Themes
