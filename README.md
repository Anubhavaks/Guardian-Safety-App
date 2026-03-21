# 🛡️ Guardian Safety Ecosystem
**A proactive, AI-powered personal safety network built for Hack Heist.**

![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![Python](https://img.shields.io/badge/AI_Engine-Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Twilio](https://img.shields.io/badge/Integration-Twilio-F22F46?style=for-the-badge&logo=twilio&logoColor=white)
![Google Maps](https://img.shields.io/badge/Mapping-Google_Maps-4285F4?style=for-the-badge&logo=googlemaps&logoColor=white)

## ⚡ Overview
Most safety applications are reactive—they require a victim to unlock their phone, open an app, and manually press a button while in active danger. 

**Guardian Safety** is a full-stack, preventative safety ecosystem designed to protect users *before, during, and after* an incident. By combining hardware sensors, real-time WebSockets, offline cellular fallbacks, and AI audio analysis, Guardian acts as an invisible shield for the user.

---

## 🔥 Key Technical Features

### 1. 🎙️ AI Audio Distress Detection (NLP)
Upon SOS activation, the app stealthily captures 10 seconds of background audio, uploads it to the Python backend, and processes it through a Speech-to-Text engine. If the NLP algorithm detects distress keywords (e.g., "help", "stop"), it automatically escalates the alert to a Tier-2 emergency.

### 2. 📵 Unstoppable Offline Fallback (Native SMS)
If a user is dragged into a basement with zero Wi-Fi or 4G data, standard web-based apps fail. Guardian detects network drops and natively hijacks the device's cellular radio via the Android Telephony API to blast SMS coordinates directly over cell towers.

### 3. 📡 Live WebSocket Radar
The moment an emergency is triggered, a two-way WebSocket connection opens between the Flutter client and the FastAPI server, streaming live latitude and longitude coordinates to emergency contacts in real-time.

### 4. ⏱️ The Dead Man's Switch (Journey Timer)
Users can set a countdown timer when walking through dangerous areas. If they do not explicitly enter their secure 4-digit PIN to dismantle the timer before it hits zero, the app assumes they are incapacitated and auto-triggers the global SOS response.

### 5. 🗺️ Crowdsourced Danger Heatmap
Every triggered SOS coordinate is permanently logged in our PostgreSQL database. Using the Google Maps SDK, the app clusters this historical data into a visual heatmap, actively highlighting "Danger Zones" so users can safely route their walk home.

### 6. 📞 Preventative Fake Caller Bot
A stealthy UI element that, when tapped, waits 10 seconds before triggering a hyper-realistic incoming phone call screen. This gives users a socially acceptable, non-confrontational excuse to walk away from uncomfortable situations.

---

## 🛠️ System Architecture

* **Frontend:** Flutter (Dart) - Optimized for Android hardware integration (Sensors, SMS, GPS).
* **Backend:** FastAPI (Python) - High-performance asynchronous API and WebSocket management.
* **Database:** PostgreSQL / SQLAlchemy ORM.
* **Authentication:** JWT (JSON Web Tokens) for secure user sessions and PIN validation.
* **External APIs:** Twilio Communications API (Cloud SMS), Google Maps SDK, Google Speech Recognition.

---

## 🚀 Local Setup & Installation

To test the full hardware capabilities (Shake-to-SOS, Offline SMS), **the Flutter app must be compiled to a physical Android device**, not a web browser or emulator.

### 1. Backend Setup (FastAPI)
```bash
cd backend
python -m venv venv
source venv/bin/activate  # Or `venv\Scripts\activate` on Windows
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
