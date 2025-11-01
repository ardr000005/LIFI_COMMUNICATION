# 💡 Li-Fi Communication System

A complete **Light Fidelity (Li-Fi)** communication project using **ESP32-WROOM-32**, designed to transmit and receive data using **visible light** instead of traditional radio waves.  
This project demonstrates **high-speed wireless optical communication** through a **Flutter-based mobile app** and **ESP32-controlled LED-Photodiode circuits**.

---

## 📁 Project Structure

```
LIFI_COMMUNICATION/
│
├── LIFI APP/lifi_communicator/     # Flutter app for Transmitter and Receiver modes
├── LIFI Transmitter/               # ESP32 Transmitter code (modulates LED light)
├── LIFI RECEIVER/                  # ESP32 Receiver code (decodes photodiode signal)
├── LICENSE                         # Apache 2.0 License
└── README.md                       # Project documentation
```

---

## 🚀 Features

- 🔄 **Bi-directional Communication** – Switch between Transmitter and Receiver modes from the mobile app
- 💡 **Visible Light Data Transfer** – Uses a blue LED to send digital messages via light intensity modulation
- 📱 **Cross-Platform Flutter App** – Control transmission and visualize received messages on Android/iOS
- ⚡ **High-Speed Microcontroller** – Built on ESP32-WROOM-32 for reliable serial and Wi-Fi support
- 🔊 **Analog Signal Amplification** – LM358 operational amplifier boosts the photodiode signal
- 🧠 **Low-Cost Prototype** – Compact, affordable, and suitable for educational or research demonstrations

---

## 🧠 Working Principle

1. The **Transmitter ESP32** reads text input from the Flutter app via serial/Wi-Fi communication
2. The text is converted into binary and transmitted as **light pulses** using a **Blue LED** controlled through a **2N2222A transistor**
3. The **Receiver ESP32** uses a **BPW34 photodiode** and **LM358 amplifier** to detect and amplify light variations
4. The amplified analog signal is processed and decoded back into text, which is displayed in the Flutter app

---

## ⚙️ Hardware Components

| Component | Description | Function |
|-----------|-------------|----------|
| **ESP32-WROOM-32 (x2)** | Wi-Fi + Bluetooth MCU | Main controller for transmitter and receiver |
| **Blue LED** | High-brightness light source | Transmits modulated optical signals |
| **2N2222A Transistor** | NPN transistor | Switches and modulates LED brightness at high speed |
| **BPW34 Photodiode** | High-sensitivity photodiode | Detects transmitted light signal |
| **LM358 Op-Amp** | Dual operational amplifier | Amplifies the photodiode's analog signal |
| **Resistors & Capacitors** | Various values | Used for biasing and signal conditioning |
| **Breadboard & Jumper Wires** | - | Circuit assembly and testing |

---

## 🔌 Circuit Description

### 🔷 **Transmitter Circuit**
- The **ESP32** sends binary data to the **base of the 2N2222A transistor**
- The **Blue LED** is connected to the transistor collector, powered via 3.3V
- The transistor switches the LED ON/OFF rapidly according to data bits

### 🔶 **Receiver Circuit**
- The **BPW34 photodiode** detects light pulses and generates a small current
- The signal is fed into **LM358**, configured as a **non-inverting amplifier**
- The amplified signal goes to an **analog input pin** of the ESP32 receiver
- ESP32 decodes signal timing and reconstructs the transmitted text

---

## 📱 Flutter App Overview

### Folder: `LIFI APP/lifi_communicator/`
The app provides two modes:
- **Transmitter Mode** – Enter and send text messages through the LED transmitter
- **Receiver Mode** – View live decoded messages from the receiver circuit

#### Run the app:
```bash
flutter pub get
flutter run
```

---

## 🧰 Technologies Used

| Layer | Technology |
|-------|------------|
| Microcontroller | ESP32-WROOM-32 |
| Amplifier IC | LM358 |
| Optical Sensor | BPW34 Photodiode |
| Switching Device | 2N2222A Transistor |
| Light Source | Blue LED |
| App Framework | Flutter (Dart) |
| Programming Languages | C / C++ (Arduino), Dart |
| License | Apache License 2.0 |

---

## 🔧 Setup and Usage

### 1. Upload Transmitter Code
- Open `LIFI Transmitter` folder in Arduino IDE
- Select board: ESP32 Dev Module
- Connect your transmitter ESP32 and upload the code

### 2. Upload Receiver Code
- Open `LIFI RECEIVER` folder
- Select board: ESP32 Dev Module
- Upload the receiver firmware

### 3. Connect Hardware
- Assemble the transmitter and receiver circuits as per the schematic
- Align LED and photodiode directly with minimal ambient light

### 4. Run Flutter App
- Pair your app with the ESP32 devices via serial/Wi-Fi
- Choose Transmitter or Receiver mode
- Start sending and receiving messages using light!

---

## 📖 License

This project is licensed under the Apache License 2.0.  
See the `LICENSE` file for more information.

```
Copyright 2025 ardr000005

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at:

   http://www.apache.org/licenses/LICENSE-2.0
```

---

## 👨‍💻 Author

**Aravind R** (ardr000005)  
B.Tech Computer Science and Engineering  
💬 Li-Fi Communication Developer | IoT & Embedded Enthusiast  

⭐ **If you find this project useful, please give it a star on GitHub!**
