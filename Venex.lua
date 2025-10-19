if _G.VenexExecuted then
    return warn("[Venex] Error : Already Loaded!")
end

--//Load Funtions
local function safeHttpGet(url)
    local ok, res = pcall(game.HttpGet, game, url)
    if ok then return res end
    -- The original code has an issue: `game.HttpGet` might not exist depending on the context (e.g., if it's an environment function passed as a global). 
    -- Assuming `HttpGet` is a global function, the pcall should use it directly, but this is a common pattern in injectors.
    warn("[Venex] Error : HttpGet failed:", url, res)
    return nil
end

local function safeLoad(url)
    local src = safeHttpGet(url)
    if not src then return nil end
    local ok, fn = pcall(loadstring, src)
    if ok and type(fn) == "function" then
        local success, lib = pcall(fn)
        if success then return lib end
        warn("[Venex] Error : loadstring run failed:", url, lib)
    else
        warn("[Venex] Error : loadstring compile failed:", url, fn)
    end
    return nil
end

local MenuColor = Color3.fromRGB(255, 255, 255)

--// Libraries
local repo          = 'https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexUI/'
local Sense         = safeLoad('https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexESP/Venex.lua')
local Library       = safeLoad(repo .. 'Library.lua')
local ThemeManager  = safeLoad(repo .. 'addons/ThemeManager.lua')
local SaveManager   = safeLoad(repo .. 'addons/SaveManager.lua')

if not (Library and ThemeManager and SaveManager) then
    warn("[Venex] One or more libs failed to load. Some features may be unavailable.")
end

local function notify(msg, dur)
    if Library and Library.Notify then
        Library:Notify(msg, dur or 3)
        print(msg)
    end
end

local Window = Library:CreateWindow({
    Title = 'Venex<font color="rgb(255, 0, 0)"> Vantage</font>',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})
-- Assuming Options is a global object provided by the injected environment/library.
Options.AccentColor:SetValueRGB(MenuColor)

local Tabs = {
    Combat   = Window:AddTab('Combat'),
    Visuals  = Window:AddTab('Visuals'),
    Player   = Window:AddTab('Player'),
    Misc     = Window:AddTab('Misc'),
    Settings = Window:AddTab('Settings')
}

-- Fixed Groupbox Names/Layout for clarity:
-- Aimbot and Enemy ESP on Left
local AimbotLG = Tabs.Misc:AddLeftGroupbox('Aimbot')
local EnemyEspLG = Tabs.Misc:AddLeftGroupbox('Enemy ESP')
-- Ally ESP and Scripts on Right
local AllyEspRG = Tabs.Misc:AddRightGroupbox('Ally ESP') -- Renamed from AllyEspLG for consistency
local ScMiscRG   = Tabs.Misc:AddRightGroupbox('Scripts')

-- --- Enemy ESP (EnemyEspLG) ---
-- Master Toggle
EnemyEspLG:AddToggle('EnemyEspEnabled', {
    Text = 'Enable', Default = false, Tooltip = 'Toggle all Enemy ESP features.',
    Callback = function(v) Sense.teamSettings.enemy.enabled = v end
})

-- Box Settings
EnemyEspLG:AddToggle('EspEnemyBox2d', {
    Text = 'Box 2D', Default = false, Tooltip = 'Draw a 2D box around enemies.',
    Callback = function(v) Sense.teamSettings.enemy.box = v end
})
EnemyEspLG:AddToggle('EspEnemyBox3d', {
    Text = 'Box 3D', Default = false, Tooltip = 'Draw a 3D box around enemies.',
    Callback = function(v) Sense.teamSettings.enemy.box3d = v end
})
EnemyEspLG:AddLabel('Box Color'):AddColorPicker('EspEnemyBoxColor', {
    Text = 'Box Color', Default = Color3.fromRGB(255,0,0), Tooltip = 'Color of the enemy ESP box.', 
    Callback = function(v) Sense.teamSettings.enemy.boxColor = v end
})
EnemyEspLG:AddSlider('EspEnemyBoxThickness', {
    Text = 'Box Thickness', Default = 1, Min = 1, Max = 5, Rounding = 0, Tooltip = 'Thickness of the enemy ESP box.',
    Callback = function(v) Sense.teamSettings.enemy.boxThickness = v end
})
EnemyEspLG:AddToggle('EspEnemyBoxOutline', {
    Text = 'Box Outline', Default = true, Tooltip = 'Add an outline to the ESP box.',
    Callback = function(v) Sense.teamSettings.enemy.boxOutline = v end
})

-- Info & Health
EnemyEspLG:AddToggle('EspEnemyName', {
    Text = 'Name', Default = false, Tooltip = 'Show enemy name.',
    Callback = function(v) Sense.teamSettings.enemy.name = v end
})
EnemyEspLG:AddLabel('Name Color'):AddColorPicker('EspEnemyNameColor', {
    Text = 'Name Color', Default = Color3.fromRGB(255,255,255), Tooltip = 'Color of enemy name text.',
    Callback = function(v) Sense.teamSettings.enemy.textColor = v end
})
EnemyEspLG:AddToggle('EspEnemyHealthBar', {
    Text = 'Health Bar', Default = false, Tooltip = 'Show enemy health as a bar.',
    Callback = function(v) Sense.teamSettings.enemy.healthBar = v end
})
EnemyEspLG:AddToggle('EspEnemyHealthText', {
    Text = 'Health Text', Default = false, Tooltip = 'Show enemy health as a number.',
    Callback = function(v) Sense.teamSettings.enemy.healthText = v end
})
EnemyEspLG:AddLabel('Health Color'):AddColorPicker('EspEnemyHealthColor', {
    Text = 'Health Color', Default = Color3.fromRGB(0,255,0), Tooltip = 'Color of enemy health display.',
    Callback = function(v) Sense.teamSettings.enemy.healthColor = v end
})

-- Tracers
EnemyEspLG:AddToggle('EspEnemyTracer', {
    Text = 'Tracers', Default = false, Tooltip = 'Draw a line to the enemy.',
    Callback = function(v) Sense.teamSettings.enemy.tracer = v end
})
EnemyEspLG:AddLabel('Tracer Color'):AddColorPicker('EspEnemyTracerColor', {
    Text = 'Tracer Color', Default = Color3.fromRGB(255,0,0), Tooltip = 'Color of the enemy tracer line.',
    Callback = function(v) Sense.teamSettings.enemy.tracerColor = v end
})
EnemyEspLG:AddDropdown('EspEnemyTracerOrigin', {
    Text = 'Tracer Origin', Values = {'Bottom','Middle','Top'}, Default = 'Bottom', Tooltip = 'Where the tracer line starts from your screen.',
    Callback = function(v) Sense.teamSettings.enemy.tracerOrigin = v end
})

-- Chams
EnemyEspLG:AddToggle('EspEnemyChams', {
    Text = 'Chams', Default = false, Tooltip = 'Color enemies through walls.',
    Callback = function(v) Sense.teamSettings.enemy.chams = v end
})
EnemyEspLG:AddToggle('EspEnemyChamsVisible', {
    Text = 'Chams Visible Check', Default = false, Tooltip = 'Only color chams when the enemy is visible.',
    Callback = function(v) Sense.teamSettings.enemy.chamsVisibleOnly = v end
})
EnemyEspLG:AddToggle('EspEnemyWeapon', { -- Corrected typo: EspEmemyWeapon -> EspEnemyWeapon
    Text = 'Weapon/Tool', Default = false, Tooltip = 'Show the enemy\'s held weapon or tool.',
    Callback = function(v) Sense.teamSettings.enemy.weapon = v end
})
EnemyEspLG:AddLabel('Chams Color'):AddColorPicker('EspEnemyChamsColor', {
    Text = 'Chams Color', Default = Color3.fromRGB(255,0,0), Tooltip = 'Color for enemy chams.',
    Callback = function(v) Sense.teamSettings.enemy.chamsColor = v end
})
EnemyEspLG:AddSlider('EspEnemyChamsTransparency', {
    Text = 'Chams Transparency', Default = 0.25, Min = 0, Max = 1, Rounding = 2, Tooltip = 'Set the transparency level for chams.',
    Callback = function(v) Sense.teamSettings.enemy.chamsTransparency = v end
})

-- --- Ally ESP (AllyEspRG) ---
-- Master Toggle
AllyEspRG:AddToggle('EspAlly', {
    Text = 'Enable', Default = false, Tooltip = 'Toggle all Ally ESP features.',
    Callback = function(v) Sense.teamSettings.friendly.enabled = v end
})

-- Box Settings
AllyEspRG:AddToggle('EspAllyBox', {
    Text = 'Box 2D', Default = false, Tooltip = 'Draw a 2D box around allies.',
    Callback = function(v) Sense.teamSettings.friendly.box = v end
})
AllyEspRG:AddToggle('EspAllyBox3d', { -- Added missing Ally Box 3D toggle for feature parity
    Text = 'Box 3D', Default = false, Tooltip = 'Draw a 3D box around allies.',
    Callback = function(v) Sense.teamSettings.friendly.box3d = v end
})
AllyEspRG:AddLabel('Box Color'):AddColorPicker('EspAllyBoxColor', {
    Text = 'Box Color', Default = Color3.fromRGB(80,200,255), Tooltip = 'Color of the friendly ESP box.',
    Callback = function(v) Sense.teamSettings.friendly.boxColor = v end
})
AllyEspRG:AddSlider('EspAllyBoxThickness', {
    Text = 'Box Thickness', Default = 1, Min = 1, Max = 5, Rounding = 0, Tooltip = 'Thickness of the friendly ESP box.',
    Callback = function(v) Sense.teamSettings.friendly.boxThickness = v end
})
AllyEspRG:AddToggle('EspAllyBoxOutline', {
    Text = 'Box Outline', Default = true, Tooltip = 'Add an outline to the friendly ESP box.',
    Callback = function(v) Sense.teamSettings.friendly.boxOutline = v end
})

-- Info & Health
AllyEspRG:AddToggle('EspAllyName', {
    Text = 'Name', Default = false, Tooltip = 'Show friendly name.',
    Callback = function(v) Sense.teamSettings.friendly.name = v end
})
AllyEspRG:AddLabel('Name Color'):AddColorPicker('EspAllyNameColor', {
    Text = 'Name Color', Default = Color3.fromRGB(255,255,255), Tooltip = 'Color of friendly name text.',
    Callback = function(v) Sense.teamSettings.friendly.textColor = v end
})
AllyEspRG:AddToggle('EspAllyHealthBar', {
    Text = 'Health Bar', Default = false, Tooltip = 'Show friendly health as a bar.',
    Callback = function(v) Sense.teamSettings.friendly.healthBar = v end
})
AllyEspRG:AddToggle('EspAllyHealthText', {
    Text = 'Health Text', Default = false, Tooltip = 'Show friendly health as a number.',
    Callback = function(v) Sense.teamSettings.friendly.healthText = v end
})
AllyEspRG:AddLabel('Health Color'):AddColorPicker('EspAllyHealthColor', {
    Text = 'Health Color', Default = Color3.fromRGB(0,255,0), Tooltip = 'Color of friendly health display.',
    Callback = function(v) Sense.teamSettings.friendly.healthColor = v end
})

-- Tracers
AllyEspRG:AddToggle('EspAllyTracer', {
    Text = 'Tracers', Default = false, Tooltip = 'Draw a line to the ally.',
    Callback = function(v) Sense.teamSettings.friendly.tracer = v end
})
AllyEspRG:AddLabel('Tracer Color'):AddColorPicker('EspAllyTracerColor', {
    Text = 'Tracer Color', Default = Color3.fromRGB(80,200,255), Tooltip = 'Color of the friendly tracer line.',
    Callback = function(v) Sense.teamSettings.friendly.tracerColor = v end
})
AllyEspRG:AddDropdown('EspAllyTracerOrigin', {
    Text = 'Tracer Origin', Values = {'Bottom','Middle','Top'}, Default = 'Bottom', Tooltip = 'Where the tracer line starts from your screen.',
    Callback = function(v) Sense.teamSettings.friendly.tracerOrigin = v end
})

-- Chams
AllyEspRG:AddToggle('EspAllyChams', {
    Text = 'Chams', Default = false, Tooltip = 'Color allies through walls.',
    Callback = function(v) Sense.teamSettings.friendly.chams = v end
})
AllyEspRG:AddToggle('EspAllyChamsVisible', {
    Text = 'Chams Visible Check', Default = false, Tooltip = 'Only color chams when the ally is visible.',
    Callback = function(v) Sense.teamSettings.friendly.chamsVisibleOnly = v end
})
AllyEspRG:AddLabel('Chams Color'):AddColorPicker('EspAllyChamsColor', {
    Text = 'Chams Color', Default = Color3.fromRGB(0,170,255), Tooltip = 'Color for friendly chams.',
    Callback = function(v) Sense.teamSettings.friendly.chamsColor = v end
})
AllyEspRG:AddSlider('EspAllyChamsTransparency', {
    Text = 'Chams Transparency', Default = 0.25, Min = 0, Max = 1, Rounding = 2, Tooltip = 'Set the transparency level for chams.',
    Callback = function(v) Sense.teamSettings.friendly.chamsTransparency = v end
})

local DexLoaded = false
ScMiscRG:AddButton('Execute Dex Debugger', function()
    if DexLoaded then return notify('Dex Debugger already executed!', 3) end
    DexLoaded = true
    notify('[Venex] Info : Executing Dex', 3)
    safeLoad('https://raw.githubusercontent.com/TheWooffles/Venex/main/Libraries/VenexDex/DexFinal.lua')
    notify('[Venex] Info : Executed!', 3)
end)

Library:SetWatermarkVisibility(true)
local FrameTimer = tick()
local FrameCounter = 0;
local FPS = 60;

local WatermarkConnection = game:GetService('RunService').RenderStepped:Connect(function()
    FrameCounter += 1;

    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter;
        FrameTimer = tick();
        FrameCounter = 0;
    end;

    Library:SetWatermark(('Venex | %s fps | %s ms'):format(
        math.floor(FPS),
        math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
    ));
end);

Library:OnUnload(function()
    WatermarkConnection:Disconnect()
    Sense.Unload()

    print('Unloaded!')
    Library.Unloaded = true
    _G.VenexExecuted = false
end)

-- UI Settings
local MenuGroup = Tabs.Settings:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Destroy', function() Library:Unload() end)
MenuGroup:AddLabel('Menu Bind'):AddKeyPicker('MenuKeybind', { Default = 'RightShift', NoUI = true, Text = 'Menu keybind' })
Library.ToggleKeybind = Options.MenuKeybind -- Allows you to have a custom keybind for the menu

Sense.Load()
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
ThemeManager:SetFolder('VenexThemes')
SaveManager:SetFolder('VenexConfigs')
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
_G.VenexExecuted = true