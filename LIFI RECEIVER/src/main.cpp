#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

const int ADC_PIN = 34;
const int BIT_DELAY = 300;
const int SAMPLES_PER_BIT = 5;
const unsigned long LETTER_GAP_MS = 8000;
const int SIGNAL_THRESHOLD_DIFF = 500;
const int CALIBRATION_SAMPLES = 100;

// Bluetooth definitions
#define SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

int lightLevel, darkLevel, threshold;
String msg = "";
unsigned long lastCharTime = 0;
bool signalInverted = false;
bool firstCharReceived = false; // Track if we've received the first dummy character
char firstActualChar = 0; // Store the first actual character to remove it later

BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Device connected");
    }

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Device disconnected");
    }
};

void autoCalibrate() {
  Serial.println("Auto-calibrating... Please ensure laser is OFF");
  
  // Measure ambient light (laser OFF)
  darkLevel = 0;
  for (int i = 0; i < CALIBRATION_SAMPLES; i++) {
    darkLevel += analogRead(ADC_PIN);
    delay(20);
    
    // Show progress
    if (i % 20 == 0) {
      Serial.printf("Calibrating dark level... %d%%\n", (i * 100) / CALIBRATION_SAMPLES);
    }
  }
  darkLevel /= CALIBRATION_SAMPLES;
  
  Serial.println("Now calibrating light level... Please turn laser ON");
  Serial.println("Waiting for laser signal...");
  
  // Wait for laser signal and measure
  unsigned long startTime = millis();
  bool laserDetected = false;
  
  while (millis() - startTime < 10000) { // Wait up to 10 seconds for laser
    int currentValue = analogRead(ADC_PIN);
    
    // Check if laser is detected (significant change from dark level)
    if (abs(currentValue - darkLevel) > SIGNAL_THRESHOLD_DIFF) {
      laserDetected = true;
      Serial.println("Laser detected! Measuring light level...");
      break;
    }
    
    delay(100);
    
    // Show we're waiting
    if ((millis() - startTime) % 2000 == 0) {
      Serial.println("Waiting for laser signal...");
    }
  }
  
  if (!laserDetected) {
    Serial.println("WARNING: No laser detected. Using estimated values.");
    // Estimate light level based on typical difference
    lightLevel = darkLevel + 800; // Conservative estimate
  } else {
    // Measure with laser ON
    lightLevel = 0;
    for (int i = 0; i < CALIBRATION_SAMPLES; i++) {
      lightLevel += analogRead(ADC_PIN);
      delay(20);
      
      if (i % 20 == 0) {
        Serial.printf("Calibrating light level... %d%%\n", (i * 100) / CALIBRATION_SAMPLES);
      }
    }
    lightLevel /= CALIBRATION_SAMPLES;
  }
  
  threshold = (lightLevel + darkLevel) / 2;
  
  Serial.printf("\n=== CALIBRATION RESULTS ===\n");
  Serial.printf("Dark level (laser OFF): %d\n", darkLevel);
  Serial.printf("Light level (laser ON): %d\n", lightLevel);
  Serial.printf("Threshold: %d\n", threshold);
  Serial.printf("Signal difference: %d\n", abs(lightLevel - darkLevel));
  
  if (abs(lightLevel - darkLevel) < SIGNAL_THRESHOLD_DIFF) {
    Serial.println("WARNING: Signal difference may be too small for reliable reception");
    Serial.println("Check laser alignment and photodiode connection");
  } else {
    Serial.println("Signal strength: GOOD");
  }
  
  signalInverted = (lightLevel < darkLevel);
  Serial.println(signalInverted ? "Signal: INVERTED" : "Signal: NORMAL");
  Serial.println("============================\n");
}

void sendToBluetooth(const String &message) {
  if (deviceConnected && pTxCharacteristic != NULL) {
    pTxCharacteristic->setValue(message.c_str());
    pTxCharacteristic->notify();
    Serial.println("BT Sent: " + message);
  }
}

int readSignal() {
  int value = analogRead(ADC_PIN);
  bool isLight = signalInverted ? (value < threshold) : (value > threshold);
  return isLight ? 1 : 0;
}

bool waitForStartBit() {
  unsigned long startTime = millis();
  int consecutiveZeros = 0;
  int samples = 0;
  
  while (millis() - startTime < 5000) {
    int signal = readSignal();
    
    if (signal == 0) {
      consecutiveZeros++;
      if (consecutiveZeros >= 2) {
        Serial.println("\n[START BIT DETECTED]");
        delay(BIT_DELAY * 0.75);
        return true;
      }
    } else {
      consecutiveZeros = 0;
    }
    
    delay(BIT_DELAY / 4);
    samples++;
    
    if (samples % 20 == 0) {
      Serial.print(".");
      samples = 0;
    }
  }
  return false;
}

int readBit() {
  int sum = 0;
  for (int i = 0; i < SAMPLES_PER_BIT; i++) {
    sum += readSignal();
    delay(BIT_DELAY / SAMPLES_PER_BIT);
  }
  return (sum > SAMPLES_PER_BIT / 2) ? 1 : 0;
}

bool receiveByte(byte &result) {
  result = 0;
  
  for (int i = 0; i < 8; i++) {
    int bitValue = readBit();
    result |= (bitValue << i);
  }
  
  int stopBit = readBit();
  return (stopBit == 1);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n--- Li-Fi Receiver with Bluetooth ---");
  
  // Bluetooth setup first
  BLEDevice::init("LiFi_Receiver");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pTxCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID_TX,
                      BLECharacteristic::PROPERTY_NOTIFY
                    );

  pService->createCharacteristic(
    CHARACTERISTIC_UUID_RX,
    BLECharacteristic::PROPERTY_WRITE
  );

  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  // Auto-calibration
  autoCalibrate();
  
  sendToBluetooth("Receiver Ready - Calibration Complete");
  Serial.println("Ready! Waiting for Li-Fi transmission...");
}

void loop() {
  if (waitForStartBit()) {    
    byte receivedByte;
    if (receiveByte(receivedByte)) {
      // Skip the first dummy character '#'
      if (!firstCharReceived) {
        Serial.printf("Dummy character received: '%c' (0x%02X) - IGNORED\n", receivedByte, receivedByte);
        firstCharReceived = true;
      } else {
        // Store the first actual character separately
        if (msg.length() == 0) {
          firstActualChar = receivedByte;
          Serial.printf("First actual character stored: '%c' (0x%02X) - WILL BE REMOVED LATER\n", receivedByte, receivedByte);
        }
        
        // This is the actual data - add everything to message
        if (isprint(receivedByte)) {
          msg += (char)receivedByte;
          Serial.printf("Received char: '%c' (0x%02X)\n", receivedByte, receivedByte);
        } else {
          msg += "[" + String(receivedByte, HEX) + "]";
          Serial.printf("Received hex: 0x%02X\n", receivedByte);
        }
        
        lastCharTime = millis();
        Serial.printf("Current message: '%s'\n", msg.c_str());
      }
    } else {
      Serial.println("FRAME ERROR - Bad stop bit");
      sendToBluetooth("ERROR: Frame error");
    }
  }
  
  // Check if message is complete (no data for a while)
  if (msg.length() > 0 && (millis() - lastCharTime > LETTER_GAP_MS)) {
    Serial.println("\n=== COMPLETE MESSAGE RECEIVED ===");
    Serial.println("Original: " + msg);
    
    // SIMPLE FIX: Remove the first character from the message
    String finalMessage = msg;
    if (finalMessage.length() > 0) {
      finalMessage = finalMessage.substring(1); // Remove first character
      Serial.println("After removing first char: " + finalMessage);
    }
    
    Serial.println("=================================");
    
    // Send cleaned message to Bluetooth
    sendToBluetooth(finalMessage);
    
    // Reset for next transmission
    firstCharReceived = false;
    firstActualChar = 0;
    msg = "";
    Serial.println("Ready for next message...");
  }
  
  // Handle Bluetooth connection
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("Bluetooth advertising started");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
  
  delay(10);
}