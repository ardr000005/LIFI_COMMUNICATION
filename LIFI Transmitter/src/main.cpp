#include <Arduino.h>

const int LASER_PIN = 2;
const int BIT_DELAY = 300;
const unsigned long INTER_LETTER_DELAY = 7000;  // 7 seconds between letters
const unsigned long INTER_WORD_DELAY = 10000;   // 10 seconds between words

void setup() {
  pinMode(LASER_PIN, OUTPUT);
  digitalWrite(LASER_PIN, LOW);  // Start with laser OFF
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("--- Li-Fi Transmitter (FINAL CORRECTED) ---");
  Serial.printf("Bit delay: %dms\n", BIT_DELAY);
  Serial.println("Ready to transmit...");
}

void sendBit(bool value) {
  digitalWrite(LASER_PIN, value ? HIGH : LOW);
  delay(BIT_DELAY);
}

void sendByte(byte data) {
  Serial.printf("Sending: 0x%02X ('%c')\n", data, isprint(data) ? data : '.');
  
  // Start bit (0)
  sendBit(LOW);
  
  // 8 data bits (LSB FIRST - this is the key fix!)
  for (int i = 0; i < 8; i++) {
    bool bitValue = (data >> i) & 0x01;  // Get bit i (LSB first)
    sendBit(bitValue);
  }
  
  // Stop bit (1)
  sendBit(HIGH);
  
  Serial.println("Byte sent successfully");
}

void sendMessage(const String &message) {
  Serial.printf("\n=== Transmitting: '%s' ===\n", message.c_str());
  
  for (size_t i = 0; i < message.length(); i++) {
    char c = message[i];
    sendByte((byte)c);
    
    // Delay between letters (except after last letter)
    if (i < message.length() - 1) {
      Serial.printf("Waiting %d seconds before next letter...\n", INTER_LETTER_DELAY / 1000);
      delay(INTER_LETTER_DELAY);
    }
  }
  
  Serial.printf("=== Message complete. Waiting %d seconds ===\n\n", INTER_WORD_DELAY / 1000);
  delay(INTER_WORD_DELAY);
}

void loop() {
  sendMessage("HELLO");
  sendMessage("TEST");
  sendMessage("ABC");
}