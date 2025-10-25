#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

const int LASER_PIN = 2;
const int BIT_DELAY = 300;
const unsigned long INTER_LETTER_DELAY = 7000;
const unsigned long INTER_WORD_DELAY = 10000;

// Bluetooth definitions
#define SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic = NULL;
BLECharacteristic *pRxCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

String receivedMessage = "";
bool newMessageAvailable = false;

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

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string rxValue = pCharacteristic->getValue();
      if (rxValue.length() > 0) {
        receivedMessage = "";
        for (int i = 0; i < rxValue.length(); i++) {
          receivedMessage += rxValue[i];
        }
        newMessageAvailable = true;
        Serial.println("Received via Bluetooth: " + receivedMessage);
        
        String ack = "ACK: " + String(receivedMessage.length()) + " bytes";
        pTxCharacteristic->setValue(ack.c_str());
        pTxCharacteristic->notify();
      }
    }
};

void setup() {
  pinMode(LASER_PIN, OUTPUT);
  digitalWrite(LASER_PIN, LOW);
  
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("--- Li-Fi Transmitter with Bluetooth ---");
  Serial.println("Send messages via Bluetooth app to transmit");

  // Bluetooth setup
  BLEDevice::init("LiFi_Transmitter");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pTxCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID_TX,
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
                      
  pRxCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID_RX,
                      BLECharacteristic::PROPERTY_WRITE
                    );
  pRxCharacteristic->setCallbacks(new MyCallbacks());

  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();
  
  Serial.println("Ready! Connect via Bluetooth and send messages to transmit.");
}

void sendBit(bool value) {
  digitalWrite(LASER_PIN, value ? HIGH : LOW);
  delay(BIT_DELAY);
}

void sendByte(byte data) {
  Serial.printf("Li-Fi Sending: 0x%02X ('%c')\n", data, isprint(data) ? data : '.');
  
  // Start bit (0)
  sendBit(LOW);
  
  // 8 data bits (LSB FIRST)
  for (int i = 0; i < 8; i++) {
    bool bitValue = (data >> i) & 0x01;
    sendBit(bitValue);
  }
  
  // Stop bit (1)
  sendBit(HIGH);
}

void sendMessage(const String &message) {
  Serial.printf("\n=== Li-Fi Transmitting: '%s' ===\n", message.c_str());
  
  if (deviceConnected) {
    String status = "TX: " + message;
    pTxCharacteristic->setValue(status.c_str());
    pTxCharacteristic->notify();
  }
  
  // ADDED: Send dummy '#' character first to fix first character loss
  sendByte('#');
  delay(INTER_LETTER_DELAY);
  sendByte('1');
  delay(INTER_LETTER_DELAY);
  
  // Then send actual message
  for (size_t i = 0; i < message.length(); i++) {
    char c = message[i];
    sendByte((byte)c);
    
    if (i < message.length() - 1) {
      delay(INTER_LETTER_DELAY);
    }
  }
  
  Serial.println("=== Message complete ===");
  
  if (deviceConnected) {
    pTxCharacteristic->setValue("TRANSMISSION_COMPLETE");
    pTxCharacteristic->notify();
  }
  
  delay(INTER_WORD_DELAY);
}

void loop() {
  // Only transmit when Bluetooth message is received
  if (newMessageAvailable) {
    Serial.println("Transmitting via Li-Fi: " + receivedMessage);
    sendMessage(receivedMessage);
    newMessageAvailable = false;
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
  
  delay(100);
}