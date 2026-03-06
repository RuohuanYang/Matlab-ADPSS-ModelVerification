Model Validation Tool for Comparing HIL and ADPSS Simulation Data (HVRT & LVRT)

This MATLAB toolbox provides a systematic framework for validating HIL test results against simulation data from ADPSS. It supports both High Voltage Ride Through (HVRT) and Low Voltage Ride Through (LVRT) scenarios, enabling comprehensive model assessment under various grid disturbance conditions.
The toolbox consists of two main scripts:
HVRT_validation.m – for high voltage ride through events.
LVRT_validation.m – for low voltage ride through events.
Both scripts share the same core methodology but differ in the fault detection logic and the file-naming conventions used to organize test cases.

Features
Data Import: Reads HIL data from either .mat (MATLAB binary) or .csv files, and ADPSS data from .csv files.
Event Detection:
HVRT: Fault inception is detected when the voltage rises above 1.11 times the pre‑fault mean.
LVRT: Fault inception is detected when the voltage drops below 0.89 times the pre‑fault mean.
Divides each time series into five regions:
pre‑fault steady-state, transition into fault, during‑fault steady-state, transition out of fault, and post‑fault steady-state
Nine indicators are computed for each of the five electrical quantities (voltage U, active power P, reactive power Q, d‑axis current Id, q‑axis current Iq):
F1‑Pre, F1‑Trs, F1‑Pst: mean differences in steady‑state regions.
F2‑Trs, F2‑Pst: mean differences in transition regions.
F3‑Pre, F3‑Trs, F3‑Pst: maximum absolute differences (after interpolation) in each region.
FG: a weighted composite score (10% pre‑fault, 60% during‑fault, 30% post‑fault).
Threshold Comparison: Compares computed errors against predefined limits (Fmax in global_variables.m) to determine pass/fail status.
Visualisation: Generates comparative plots for each variable, with optional saving as JPEG files.
Detailed Output: For failing cases, a table is printed showing which specific indicators exceed the allowed thresholds.

Usage
Place HIL and ADPSS data in the appropriate folders (../m_tools/HIL_pu and ../m_tools/ADPSS_Windows_pu).
Ensure the file‑naming convention files (FilenameCheck_HVRT.m and FilenameCheck_LVRT.m) correctly list the files for each test condition.
Run either HVRT_validation.m or LVRT_validation.m.
Follow the interactive prompts to specify data format and operation mode.
Results are displayed in the command window; error matrices can be saved for further analysis.

Dependencies
global_variables.m – defines global parameters (F_error, Fmax, Fdvi_error).
Figure_Mode.m – sets default figure appearance (font, colors, line width).
FilenameCheck_HVRT.m and FilenameCheck_LVRT.m – provide cell arrays HIL_filename and ADP_filename for file matching.

Customisation
The time windows for pre‑fault, during‑fault, and post‑fault periods can be adjusted via the time_set variable in each script.
The error threshold matrix Fmax can be modified in global_variables.m to suit different validation requirements.
This toolbox is designed to be flexible and can be adapted for other transient events by modifying the event detection criteria and the segmentation algorithm.
