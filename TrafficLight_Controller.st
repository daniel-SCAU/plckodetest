(*
================================================================================
  PROGRAM: TrafficLight_Controller
  DESCRIPTION: Complete 4-way intersection traffic light controller
               for Rockwell Studio 5000 / RSLogix 5000 (Allen-Bradley PLC)

  INTERSECTION LAYOUT:
                  NORTH
                    |
         NS_Red / NS_Yellow / NS_Green
         NS_Ped_Walk / NS_Ped_DontWalk
                    |
   WEST --- EW_Red/EW_Yellow/EW_Green --- EAST
         EW_Ped_Walk / EW_Ped_DontWalk
                    |
                  SOUTH

  STATE MACHINE:
    State 0 (NS_GREEN)  : North-South GREEN,  East-West RED       (30 s)
    State 1 (NS_YELLOW) : North-South YELLOW, East-West RED       ( 5 s)
    State 2 (EW_GREEN)  : North-South RED,    East-West GREEN     (30 s)
    State 3 (EW_YELLOW) : North-South RED,    East-West YELLOW    ( 5 s)

  PEDESTRIAN SIGNALS:
    - Walk signal is active during the companion green phase
    - Flashing Don't Walk starts 7 s before the phase ends
    - A push-button request extends the green phase by up to 10 s

  EMERGENCY OVERRIDE:
    - Setting Emergency_Override forces all lights RED immediately
    - Normal sequencing resumes when Emergency_Override is cleared

  AUTHOR  : GitHub Copilot (generated for daniel-SCAU/plckodetest)
  DATE    : 2026-05-04
  VERSION : 1.0
================================================================================
*)

(* ----------------------------- TAG DECLARATIONS ----------------------------- *)
(*
  The following tags must be created in the Studio 5000 Controller Tags database
  before downloading this program.  Data types and descriptions are listed here
  for documentation purposes; actual tag creation is done via the L5X file or
  the Studio 5000 tag editor.

  --  OUTPUTS (mapped to physical I/O module)  --
  NS_Red          BOOL    North-South RED lamp
  NS_Yellow       BOOL    North-South YELLOW lamp
  NS_Green        BOOL    North-South GREEN lamp
  NS_Ped_Walk     BOOL    North-South pedestrian WALK lamp
  NS_Ped_DontWalk BOOL    North-South pedestrian DON'T WALK lamp (also used flashing)

  EW_Red          BOOL    East-West RED lamp
  EW_Yellow       BOOL    East-West YELLOW lamp
  EW_Green        BOOL    East-West GREEN lamp
  EW_Ped_Walk     BOOL    East-West pedestrian WALK lamp
  EW_Ped_DontWalk BOOL    East-West pedestrian DON'T WALK lamp (also used flashing)

  --  INPUTS (mapped to physical I/O module)  --
  Ped_Btn_NS      BOOL    Pedestrian push-button request, North-South crossing
  Ped_Btn_EW      BOOL    Pedestrian push-button request, East-West crossing
  Emergency_Override BOOL Set HIGH by emergency-vehicle detector or operator panel

  --  INTERNAL (controller tags only)  --
  State           INT     Current state (0-3)
  T_Phase         TON     Phase timer (green and yellow durations)
  T_Ped_Flash     TON     Pedestrian DON'T WALK flash timer (0.5 s period)
  T_Extend        TON     Pedestrian green-extension timer (max 10 s)
  Ped_Req_NS      BOOL    Latched pedestrian request — North-South
  Ped_Req_EW      BOOL    Latched pedestrian request — East-West
  Flash_Bit       BOOL    0.5 s toggle bit used for flashing DON'T WALK lamps
  First_Scan      BOOL    TRUE only on the very first PLC scan
*)

(* ========================  CONSTANTS  ======================================= *)
VAR_GLOBAL CONSTANT
    GREEN_TIME      : TIME := T#30s;   (* Normal green phase duration          *)
    YELLOW_TIME     : TIME := T#5s;    (* Yellow phase duration                *)
    PED_WARN_TIME   : TIME := T#7s;    (* Flashing Don't Walk warning period   *)
    PED_EXT_TIME    : TIME := T#10s;   (* Max pedestrian green extension       *)
    FLASH_PERIOD    : TIME := T#500ms; (* DON'T WALK flash period              *)
END_VAR

(* ========================  PROGRAM BODY  ==================================== *)

(* ---- Initialization on first scan ---------------------------------------- *)
IF First_Scan THEN
    State      := 0;
    Ped_Req_NS := FALSE;
    Ped_Req_EW := FALSE;
    First_Scan := FALSE;

    (* Start in State 0: NS Green, EW Red *)
    T_Phase(IN := TRUE, PT := GREEN_TIME);
END_IF;

(* ---- Latch pedestrian push-button requests -------------------------------- *)
IF Ped_Btn_NS THEN Ped_Req_NS := TRUE; END_IF;
IF Ped_Btn_EW THEN Ped_Req_EW := TRUE; END_IF;

(* ---- Emergency override: force all RED ------------------------------------ *)
IF Emergency_Override THEN
    NS_Red          := TRUE;
    NS_Yellow       := FALSE;
    NS_Green        := FALSE;
    NS_Ped_Walk     := FALSE;
    NS_Ped_DontWalk := TRUE;

    EW_Red          := TRUE;
    EW_Yellow       := FALSE;
    EW_Green        := FALSE;
    EW_Ped_Walk     := FALSE;
    EW_Ped_DontWalk := TRUE;

    (* Pause the phase timer while override is active *)
    T_Phase(IN := FALSE, PT := GREEN_TIME);
    RETURN;
END_IF;

(* ---- 0.5-second flash oscillator for DON'T WALK lamps -------------------- *)
T_Ped_Flash(IN := NOT T_Ped_Flash.DN, PT := FLASH_PERIOD);
IF T_Ped_Flash.DN THEN
    Flash_Bit := NOT Flash_Bit;
    T_Ped_Flash(IN := FALSE, PT := FLASH_PERIOD); (* reset *)
    T_Ped_Flash(IN := TRUE,  PT := FLASH_PERIOD);
END_IF;

(* ---- State machine -------------------------------------------------------- *)
CASE State OF

    (* ------------------------------------------------------------------ *)
    (* STATE 0: North-South GREEN  /  East-West RED                        *)
    (* ------------------------------------------------------------------ *)
    0:
        NS_Red          := FALSE;
        NS_Yellow       := FALSE;
        NS_Green        := TRUE;
        EW_Red          := TRUE;
        EW_Yellow       := FALSE;
        EW_Green        := FALSE;

        (* Pedestrian WALK active for North-South *)
        NS_Ped_Walk     := TRUE;
        EW_Ped_Walk     := FALSE;

        (* --- Pedestrian extension logic --- *)
        (* If NS button was pressed, allow up to PED_EXT_TIME extra green *)
        IF Ped_Req_NS AND NOT T_Extend.DN THEN
            T_Extend(IN := TRUE, PT := PED_EXT_TIME);
        END_IF;

        (* Start the phase timer *)
        T_Phase(IN := TRUE, PT := GREEN_TIME);

        (* --- Flashing DON'T WALK warning in the last PED_WARN_TIME --- *)
        IF (GREEN_TIME - T_Phase.ACC) <= PED_WARN_TIME THEN
            NS_Ped_Walk     := FALSE;
            NS_Ped_DontWalk := Flash_Bit;   (* flashing *)
            EW_Ped_DontWalk := TRUE;        (* solid *)
        ELSE
            NS_Ped_DontWalk := FALSE;
            EW_Ped_DontWalk := TRUE;
        END_IF;

        (* --- Transition to STATE 1 when timer expires --- *)
        (* Extend only if a pedestrian request exists and extension not done *)
        IF T_Phase.DN THEN
            IF Ped_Req_NS AND NOT T_Extend.DN THEN
                (* Stay green until extension timer expires *)
                T_Phase(IN := FALSE, PT := GREEN_TIME);
                T_Phase(IN := TRUE,  PT := GREEN_TIME);
            ELSE
                State := 1;
                T_Phase(IN := FALSE, PT := GREEN_TIME);
                T_Phase(IN := TRUE,  PT := YELLOW_TIME);
                T_Extend(IN := FALSE, PT := PED_EXT_TIME); (* reset *)
                Ped_Req_NS := FALSE;
            END_IF;
        END_IF;

    (* ------------------------------------------------------------------ *)
    (* STATE 1: North-South YELLOW  /  East-West RED                       *)
    (* ------------------------------------------------------------------ *)
    1:
        NS_Red          := FALSE;
        NS_Yellow       := TRUE;
        NS_Green        := FALSE;
        EW_Red          := TRUE;
        EW_Yellow       := FALSE;
        EW_Green        := FALSE;

        NS_Ped_Walk     := FALSE;
        NS_Ped_DontWalk := TRUE;   (* solid DON'T WALK *)
        EW_Ped_Walk     := FALSE;
        EW_Ped_DontWalk := TRUE;

        T_Phase(IN := TRUE, PT := YELLOW_TIME);

        IF T_Phase.DN THEN
            State := 2;
            T_Phase(IN := FALSE, PT := YELLOW_TIME);
            T_Phase(IN := TRUE,  PT := GREEN_TIME);
        END_IF;

    (* ------------------------------------------------------------------ *)
    (* STATE 2: North-South RED  /  East-West GREEN                        *)
    (* ------------------------------------------------------------------ *)
    2:
        NS_Red          := TRUE;
        NS_Yellow       := FALSE;
        NS_Green        := FALSE;
        EW_Red          := FALSE;
        EW_Yellow       := FALSE;
        EW_Green        := TRUE;

        NS_Ped_Walk     := FALSE;
        EW_Ped_Walk     := TRUE;

        (* --- Pedestrian extension logic --- *)
        IF Ped_Req_EW AND NOT T_Extend.DN THEN
            T_Extend(IN := TRUE, PT := PED_EXT_TIME);
        END_IF;

        T_Phase(IN := TRUE, PT := GREEN_TIME);

        (* --- Flashing DON'T WALK warning --- *)
        IF (GREEN_TIME - T_Phase.ACC) <= PED_WARN_TIME THEN
            EW_Ped_Walk     := FALSE;
            EW_Ped_DontWalk := Flash_Bit;   (* flashing *)
            NS_Ped_DontWalk := TRUE;        (* solid *)
        ELSE
            EW_Ped_DontWalk := FALSE;
            NS_Ped_DontWalk := TRUE;
        END_IF;

        (* --- Transition to STATE 3 --- *)
        IF T_Phase.DN THEN
            IF Ped_Req_EW AND NOT T_Extend.DN THEN
                T_Phase(IN := FALSE, PT := GREEN_TIME);
                T_Phase(IN := TRUE,  PT := GREEN_TIME);
            ELSE
                State := 3;
                T_Phase(IN := FALSE, PT := GREEN_TIME);
                T_Phase(IN := TRUE,  PT := YELLOW_TIME);
                T_Extend(IN := FALSE, PT := PED_EXT_TIME);
                Ped_Req_EW := FALSE;
            END_IF;
        END_IF;

    (* ------------------------------------------------------------------ *)
    (* STATE 3: North-South RED  /  East-West YELLOW                       *)
    (* ------------------------------------------------------------------ *)
    3:
        NS_Red          := TRUE;
        NS_Yellow       := FALSE;
        NS_Green        := FALSE;
        EW_Red          := FALSE;
        EW_Yellow       := TRUE;
        EW_Green        := FALSE;

        NS_Ped_Walk     := FALSE;
        NS_Ped_DontWalk := TRUE;
        EW_Ped_Walk     := FALSE;
        EW_Ped_DontWalk := TRUE;

        T_Phase(IN := TRUE, PT := YELLOW_TIME);

        IF T_Phase.DN THEN
            State := 0;
            T_Phase(IN := FALSE, PT := YELLOW_TIME);
            T_Phase(IN := TRUE,  PT := GREEN_TIME);
        END_IF;

    (* ---- Default: safe fallback to all-RED ----------------------------- *)
    ELSE
        NS_Red          := TRUE;
        NS_Yellow       := FALSE;
        NS_Green        := FALSE;
        EW_Red          := TRUE;
        EW_Yellow       := FALSE;
        EW_Green        := FALSE;
        NS_Ped_Walk     := FALSE;
        NS_Ped_DontWalk := TRUE;
        EW_Ped_Walk     := FALSE;
        EW_Ped_DontWalk := TRUE;
        State           := 0;
        T_Phase(IN := FALSE, PT := GREEN_TIME);
        T_Phase(IN := TRUE,  PT := GREEN_TIME);

END_CASE;
