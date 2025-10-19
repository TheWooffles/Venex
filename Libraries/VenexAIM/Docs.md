# 🎯 Aimbot Library — Executor-Compatible Edition

A lightweight, optimized **Aimbot ModuleScript** designed for Roblox executors.
Includes built-in support for protected GUIs via `protectgui()` and `gethui()`.

---

## 📦 Overview

`AimbotLib` is a standalone, reusable module that provides smooth camera-based aimbot functionality for executors.
It’s optimized for performance, customizable, and compatible with environments that support the Drawing API or require GUI-based visuals.

---

## ⚙️ Features

✅ **Optimized for Executors**

* Uses `protectgui()` or `protect_gui()` (if available)
* Automatically hides the UI from detection layers

✅ **Drawing + GUI Visuals**

* Drawing API: FOV circle + target indicator
* Protected ScreenGui fallback for environments without Drawing

✅ **Customizable Settings**

* Adjustable FOV radius, color, smoothness, prediction
* Optional team check and wall check
* Toggleable GUI and drawing visibility

✅ **Performance Focused**

* Caches player lists and camera references
* Uses `RenderStepped` for smooth, stable aiming

---

## 📚 Installation

1. **Save the Module**

   * Create a new ModuleScript named `AimbotLib.lua`
   * Paste the full library code inside.

2. **Place it in your environment**

   * Recommended: `ReplicatedStorage`, `Executor workspace`, or similar safe path.

3. **Require it in your script**

   ```lua
   local AimbotLib = require(path.to.AimbotLib)
   ```

---

## 🚀 Basic Usage

```lua
-- Load the library
local AimbotLib = require(path.to.AimbotLib)

-- Create an instance with custom options
local Aimbot = AimbotLib.new({
    Radius = 120,
    TargetPart = "Head",
    Smoothness = 0.18,
    Prediction = 0.14,
    FovColor = Color3.fromRGB(255, 80, 80),
    UseGui = true,         -- Enables protected GUI
    GuiVisible = true,
})

-- Enable aimbot
Aimbot:SetEnabled(true)
```

---

## 🧩 Public API Reference

### `AimbotLib.new(options)`

Creates a new Aimbot instance.

#### **Parameters**

| Name         | Type       | Default                 | Description                          |
| ------------ | ---------- | ----------------------- | ------------------------------------ |
| `Radius`     | `number`   | `50`                    | Radius of the FOV circle in pixels   |
| `TargetPart` | `string`   | `"Head"`                | Body part to aim at                  |
| `TeamCheck`  | `boolean`  | `true`                  | Skip players on the same team        |
| `WallCheck`  | `boolean`  | `true`                  | Raycast to confirm line-of-sight     |
| `Prediction` | `number`   | `0.143`                 | Multiplier for projectile prediction |
| `Smoothness` | `number`   | `0.2`                   | Lerp smoothing for aiming            |
| `FovColor`   | `Color3`   | Purple                  | FOV & GUI color                      |
| `UseGui`     | `boolean`  | `true`                  | Enables protected GUI creation       |
| `GuiVisible` | `boolean`  | `true`                  | Whether the GUI is visible           |
| `GuiParent`  | `Instance` | `gethui()` or `CoreGui` | Where the GUI is parented            |

---

### 🧠 Aimbot Methods

#### `:SetEnabled(boolean)`

Turns the aimbot on or off.

#### `:SetRadius(number)`

Adjusts the radius of the FOV.

#### `:SetTargetPart(string)`

Changes which body part to aim at.

#### `:SetSmoothness(number)`

Changes how smoothly the camera follows the target.

#### `:SetPrediction(number)`

Sets projectile prediction multiplier.

#### `:SetTeamCheck(boolean)`

Enable/disable same-team filtering.

#### `:SetWallCheck(boolean)`

Enable/disable wall check via raycasting.

#### `:SetFovVisibility(boolean)`

Shows or hides the Drawing circle and GUI indicator.

#### `:SetFovColor(Color3)`

Changes color of both Drawing and GUI visuals.

#### `:SetOffset(Vector2)`

Moves the FOV circle’s center by a pixel offset.

#### `:SetGuiVisible(boolean)`

Shows or hides the protected GUI.

#### `:SetUseGui(boolean)`

Creates or destroys the protected GUI dynamically.

#### `:ForceAimAt(Player)`

Forces aim at a specific player (bypasses FOV filtering).

#### `:GetClosestTarget()`

Returns the current closest visible target player.

#### `:Destroy()`

Cleans up visuals, connections, and removes protected UI safely.

---

## 🧱 Internal Protections

### Protected GUI Layer

When `UseGui = true`:

1. The library creates a hidden `ScreenGui` in:

   * `gethui()` (if available)
   * or `CoreGui` as fallback
2. It calls:

   ```lua
   protectgui(screenGui)
   ```

   or

   ```lua
   protect_gui(screenGui)
   ```

   depending on what’s available in the executor.

This hides and protects the GUI from the default Roblox UI hierarchy.

---

## 🎨 Visuals

### Drawing Layer (PC Executors)

* **Circle** — FOV range
* **Small circle indicator** — shows locked target

### GUI Layer (Fallback / Optional)

* **TextLabel** — shows aimbot status (`ON` / `OFF`)
* **Frame** — small crosshair / indicator
* Both are auto-protected and hidden if Drawing is available.

---

## 🧩 Example: Toggle Keybind

```lua
local UserInputService = game:GetService("UserInputService")
local AimbotLib = require(path.to.AimbotLib)
local aim = AimbotLib.new({Radius = 100, FovColor = Color3.fromRGB(0,255,0)})

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightAlt then
        aim:SetEnabled(not aim.Config.Enabled)
    end
end)
```

---

## 🧠 Tips & Notes

* **Best suited for PC executors** (Synapse, Solara, etc.)
* Drawing visuals automatically hide if unsupported.
* You can build your own **UI sliders or toggles** inside the protected GUI.
* For projectile aimbots, tweak `Prediction` based on bullet speed.

---