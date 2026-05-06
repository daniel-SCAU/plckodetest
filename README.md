# Traffic Light Controller — Rockwell Studio 5000 / RSLogix 5000

A complete 4-way intersection traffic light controller written in **IEC 61131-3 Structured Text** for Allen-Bradley / Rockwell Automation PLCs (Studio 5000 Logix Designer, RSLogix 5000).

---

## Files

| File | Description |
|------|-------------|
| `TrafficLight_Controller.st` | Human-readable Structured Text source code |
| `TrafficLight_Controller.L5X` | Studio 5000 L5X export (XML) — ready to import |

---

## Intersection Layout

```
                NORTH
                  |
     NS_Red / NS_Yellow / NS_Green
     NS_Ped_Walk / NS_Ped_DontWalk
                  |
 WEST --- EW_Red/EW_Yellow/EW_Green --- EAST
     EW_Ped_Walk / EW_Ped_DontWalk
                  |
                SOUTH
```

---

## State Machine

| State | NS Direction | EW Direction | Duration |
|-------|-------------|--------------|----------|
| **0** | 🟢 GREEN | 🔴 RED | 30 s |
| **1** | 🟡 YELLOW | 🔴 RED | 5 s |
| **2** | 🔴 RED | 🟢 GREEN | 30 s |
| **3** | 🔴 RED | 🟡 YELLOW | 5 s |

Normal cycle: **0 → 1 → 2 → 3 → 0** (repeating)

---

## Features

### Pedestrian Crossing Signals
- **WALK** lamp is active for the duration of the companion green phase.
- **Flashing DON'T WALK** begins 7 seconds before the green ends, warning pedestrians to finish crossing.
- Solid **DON'T WALK** is shown during all non-green phases.

### Pedestrian Push-Button Extension
- `Ped_Btn_NS` — North-South crossing request button.
- `Ped_Btn_EW` — East-West crossing request button.
- Pressing a button latches a request. When the phase timer expires, the green is extended once by up to **10 seconds** (`T_Extend`) to let pedestrians complete their crossing before transitioning.

### Emergency Vehicle Override
- Setting `Emergency_Override = TRUE` (from an emergency-vehicle detector, siren sensor, or operator panel) immediately forces **all lights to RED** and **all pedestrian signals to DON'T WALK**.
- The phase timer is paused during the override.
- Normal sequencing resumes as soon as `Emergency_Override` returns to `FALSE`.

---

## Tags Reference

### Outputs (map to digital output module)

| Tag | Type | Description |
|-----|------|-------------|
| `NS_Red` | BOOL | North-South RED lamp |
| `NS_Yellow` | BOOL | North-South YELLOW lamp |
| `NS_Green` | BOOL | North-South GREEN lamp |
| `NS_Ped_Walk` | BOOL | North-South pedestrian WALK lamp |
| `NS_Ped_DontWalk` | BOOL | North-South pedestrian DON'T WALK lamp |
| `EW_Red` | BOOL | East-West RED lamp |
| `EW_Yellow` | BOOL | East-West YELLOW lamp |
| `EW_Green` | BOOL | East-West GREEN lamp |
| `EW_Ped_Walk` | BOOL | East-West pedestrian WALK lamp |
| `EW_Ped_DontWalk` | BOOL | East-West pedestrian DON'T WALK lamp |

### Inputs (map to digital input module)

| Tag | Type | Description |
|-----|------|-------------|
| `Ped_Btn_NS` | BOOL | Pedestrian push-button — North-South crossing |
| `Ped_Btn_EW` | BOOL | Pedestrian push-button — East-West crossing |
| `Emergency_Override` | BOOL | Emergency all-RED override |

### Internal (controller tags only)

| Tag | Type | Description |
|-----|------|-------------|
| `State` | INT | Current state (0–3) |
| `T_Phase` | TIMER | Phase timer (green 30 s / yellow 5 s) |
| `T_Ped_Flash` | TIMER | 500 ms oscillator for flashing DON'T WALK |
| `T_Extend` | TIMER | Pedestrian green-extension timer (max 10 s) |
| `Ped_Req_NS` | BOOL | Latched N-S pedestrian crossing request |
| `Ped_Req_EW` | BOOL | Latched E-W pedestrian crossing request |
| `Flash_Bit` | BOOL | 500 ms toggle bit for flashing output |
| `First_Scan` | BOOL | TRUE on first PLC scan (triggers init) |

---

## Timing Diagram

```
Time →    0         30        35        65        70        (s)
          |---------|---------|---------|---------|
NS_Green  ██████████████████████
NS_Yellow                    █████
EW_Green                           ██████████████████████
EW_Yellow                                              █████
NS_Walk   ████████████████████
NS_Don'tW         (flash 7s)██████
EW_Walk                            ████████████████████
EW_Don'tW                                    (flash 7s)████
```

---

## How to Import into Studio 5000

1. Open **Studio 5000 Logix Designer**.
2. Create a new project targeting your ControlLogix / CompactLogix controller.
3. In the **Controller Organizer**, right-click the controller node and choose **"Import Component…"**.
4. Select `TrafficLight_Controller.L5X` and click **Open**.
5. In the **I/O Configuration**, map the output tags (`NS_Red`, `NS_Green`, etc.) to the physical output module channels and the input tags (`Ped_Btn_NS`, `Emergency_Override`, etc.) to input module channels.
6. **Verify** (Ctrl+K) and **Download** the project.
7. Set the controller to **RUN** mode.