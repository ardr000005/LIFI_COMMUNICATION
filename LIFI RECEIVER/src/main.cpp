#include <Arduino.h>

const int ADC_PIN = 34;
const int BIT_DELAY = 300;
const int SAMPLES_PER_BIT = 5;
const unsigned long LETTER_GAP_MS = 8000;  // 8 seconds
const int SIGNAL_THRESHOLD_DIFF = 500;

int lightLevel, darkLevel, threshold;
String msg = "";
unsigned long lastCharTime = 0;
bool signalInverted = false;

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n--- Li-Fi Receiver (FINAL CORRECTED) ---");
  Serial.println("Calibrating... Point laser directly at photodiode");

  // Calibrate with laser OFF (dark)
  Serial.println("Ensure laser is OFF for dark calibration...");
  delay(3000);
  darkLevel = 0;
  for (int i = 0; i < 50; i++) {
    darkLevel += analogRead(ADC_PIN);
    delay(50);
  }
  darkLevel /= 50;

  // Calibrate with laser ON (light)
  Serial.println("Now turn laser ON for light calibration...");
  delay(3000);
  lightLevel = 0;
  for (int i = 0; i < 50; i++) {
    lightLevel += analogRead(ADC_PIN);
    delay(50);
  }
  lightLevel /= 50;

  // Set threshold
  threshold = (lightLevel + darkLevel) / 2;
  
  Serial.printf("Dark level: %d, Light level: %d\n", darkLevel, lightLevel);
  Serial.printf("Threshold: %d, Difference: %d\n", threshold, abs(lightLevel - darkLevel));

  if (abs(lightLevel - darkLevel) < SIGNAL_THRESHOLD_DIFF) {
    Serial.println("ERROR: Signal difference too small!");
    Serial.println("Check laser alignment and photodiode connection");
    while(1) delay(1000);
  }

  // Determine if signal is inverted
  if (lightLevel < darkLevel) {
    signalInverted = true;
    Serial.println("Signal: INVERTED (laser ON = lower voltage)");
  } else {
    signalInverted = false;
    Serial.println("Signal: NORMAL (laser ON = higher voltage)");
  }

  Serial.println("Ready! Waiting for transmission...");
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
  
  while (millis() - startTime < 3000) {
    if (readSignal() == 0) {
      consecutiveZeros++;
      if (consecutiveZeros >= 2) {
        // Found potential start bit, wait to center in the bit
        delay(BIT_DELAY * 0.75);
        return true;
      }
    } else {
      consecutiveZeros = 0;
    }
    delay(BIT_DELAY / 4);
    samples++;
    
    // Show we're alive
    if (samples % 10 == 0) {
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
  
  // Read 8 data bits (LSB FIRST to match transmitter)
  for (int i = 0; i < 8; i++) {
    int bitValue = readBit();
    result |= (bitValue << i);  // LSB first
  }
  
  // Read stop bit
  int stopBit = readBit();
  
  return (stopBit == 1);  // Valid if stop bit is 1
}

void loop() {
  if (waitForStartBit()) {
    Serial.print("\n[START] ");
    
    byte receivedByte;
    if (receiveByte(receivedByte)) {
      // Store the character
      if (isprint(receivedByte)) {
        msg += (char)receivedByte;
        Serial.printf("Received: '%c' (0x%02X)\n", receivedByte, receivedByte);
      } else {
        msg += "[" + String(receivedByte, HEX) + "]";
        Serial.printf("Received: 0x%02X (non-printable)\n", receivedByte);
      }
      
      lastCharTime = millis();
      Serial.printf("Message so far: '%s'\n", msg.c_str());
    } else {
      Serial.println("FRAME ERROR - Bad stop bit");
    }
  }
  
  // Check if message is complete (no data for a while)
  if (msg.length() > 0 && (millis() - lastCharTime > LETTER_GAP_MS)) {
    Serial.println("\n=== COMPLETE MESSAGE ===");
    Serial.println(msg);
    Serial.println("========================");
    msg = "";
    Serial.println("Ready for next message...");
  }
}