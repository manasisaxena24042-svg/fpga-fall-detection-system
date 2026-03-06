# FPGA Fall Detection System

A real-time fall detection system implemented on the **DE10-Lite FPGA** using **VHDL** and the **ADXL345 accelerometer**.

The system continuously reads acceleration data, processes it in hardware, detects potential fall events, and triggers an alert with a user-cancellation countdown.

---

## Hardware Used
- DE10-Lite FPGA (Intel MAX10)
- ADXL345 Accelerometer
- On-board push buttons
- Seven-segment display

---

## System Overview

The accelerometer data is read via an **I2C interface**, processed using a **magnitude-squared fall detection algorithm**, and controlled through a **Finite State Machine (FSM)** that manages system states such as monitoring, fall detection, and user response.

Key features:
- Real-time acceleration monitoring
- Magnitude-squared fall detection algorithm
- Custom I2C master controller
- FSM-based system control
- 30-second user cancellation timer
- Button debouncing for reliable input
- Seven-segment display status output

---

## Project Architecture

Top module:
- `fall_detector_top.vhd` – Integrates all modules and manages system connections.

Core modules:
- `Main_Control_FSM.vhd` – Central controller for system states and event handling.
- `fall_detection_logic.vhd` – Implements the fall detection algorithm.
- `accelerometer_interface.vhd` – Interfaces with the ADXL345 sensor.
- `i2c_master.vhd` – Custom I2C controller for sensor communication.

Supporting modules:
- `mag_sq.vhd` – Computes magnitude squared of acceleration vectors.
- `countdown_timer_30s.vhd` – Handles the user cancellation timer.
- `button_debouncer.vhd` – Debounces push-button inputs.
- `io_controller.vhd` – Manages I/O signals.
- `ssd_driver.vhd` – Controls the seven-segment display.
- `fall_pkg.vhd` – Shared constants and type definitions.

---

## Team

This project was developed as a **group FPGA design project**.

Team members:
- Manasi Saxena– Fall detection subsystem
- Malhar Salunkhe– Accelerometer interface
- Muskan Kumari– Control FSM
- Nethi Pratheekshan– Display and I/O modules

---

## My Contribution

I was responsible for the **fall detection subsystem (Part 2 of the project)**.

My work focused on designing and implementing the hardware logic that determines whether a fall event has occurred based on accelerometer data.

Modules developed by me:
- `fall_detection_logic.vhd` – Implements the fall detection algorithm.
- `mag_sq.vhd` – Computes the magnitude-squared of acceleration vectors.
- `fall_pkg.vhd` – Contains shared constants and parameters used in the detection logic.

Responsibilities:
- Designed the magnitude-squared based fall detection algorithm in VHDL
- Implemented the detection pipeline for real-time FPGA processing
- Integrated the detection logic with the system control FSM
- Tested functionality through simulation and FPGA synthesis

---

## Demo

Project demonstration video:  
(https://drive.google.com/drive/folders/1ZFHApQVdgc4gycO4dSYbovHTnhnI01Bb)
