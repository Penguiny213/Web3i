#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <MFRC522.h>
#include <Servo.h>
#include <Keypad.h>
#include <TinyGsmClient.h>
#include <GSM.h>
#include <HttpClient.h>

// LCD configuration
LiquidCrystal_I2C lcd(0x27, 20, 4); // Adjust the I2C address if needed

// RFID configuration
#define RST_PIN 22
#define SS_PIN 21
MFRC522 rfid(SS_PIN, RST_PIN);

// Servo motor configuration
Servo sg90Servo;
const int servoPin = 18; // Adjust the pin according to your setup

// Keypad configuration
const byte ROWS = 4; //four rows
const byte COLS = 4; //four columns
char keys[ROWS][COLS] = {
  {'1','2','3','A'},
  {'4','5','6','B'},
  {'7','8','9','C'},
  {'*','0','#','D'}
};
byte rowPins[ROWS] = {14, 13, 12, 27}; //connect to the row pinouts of the keypad
byte colPins[COLS] = {26, 25, 33, 32}; //connect to the column pinouts of the keypad
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

// GSM configuration
#define GSM_RX 16
#define GSM_TX 17
SoftwareSerial gsmSerial(GSM_RX, GSM_TX);
TinyGsm modem(gsmSerial);

const char* simPIN = "1234"; // Replace with your SIM card PIN

const char* server = "your-website.com";
const int port = 80;
const char* endpoint = "/getPhoneNumber"; // Replace with your API endpoint

void setup() {
  Serial.begin(115200);
  lcd.begin(16, 2);
  rfid.begin();
  sg90Servo.attach(servoPin);
  sg90Servo.write(90); // Initial position for the servo

  gsmSerial.begin(9600);

  // Connect to the GSM network
  Serial.println("Connecting to the network...");
  if (!modem.init()) {
    Serial.println("Failed to connect to the network. Check your SIM card and SIM PIN.");
    while (true);
  }

  // Unlock your SIM card with a PIN (if needed)
  if (modem.simUnlock(simPIN) != 1) {
    Serial.println("Failed to unlock SIM card.");
    while (true);
  }

  Serial.println("Connected to the network.");
}

void loop() {
  // RFID reading
  if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    Serial.println("RFID Card detected!");
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("RFID Card ID:");
    lcd.setCursor(0, 1);
    printHex(rfid.uid.uidByte, rfid.uid.size);
    
    // Fetch phone number from the server
    String phoneNumber = getPhoneNumber();
    if (!phoneNumber.isEmpty()) {
      sendSMS("RFID Card detected! User's phone number: " + phoneNumber);
    }
    
    delay(2000); // Display the RFID card for 2 seconds
  }

  // Keypad reading
  char key = keypad.getKey();
  if (key) {
    Serial.println("Keypad key pressed: " + String(key));
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Keypad Key:");
    lcd.setCursor(0, 1);
    lcd.print(key);
    
    // Fetch phone number from the server
    String phoneNumber = getPhoneNumber();
    if (!phoneNumber.isEmpty()) {
      sendSMS("Keypad key pressed: " + String(key) + ". User's phone number: " + phoneNumber);
    }
    
    delay(2000); // Display the keypad key for 2 seconds
  }

  // Servo motor rotation
  sg90Servo.write(0); // Rotate servo to 0 degrees
  delay(1000);
  sg90Servo.write(90); // Rotate servo to 90 degrees
  delay(1000);
}

void printHex(byte *buffer, byte bufferSize) {
  for (byte i = 0; i < bufferSize; i++) {
    lcd.print(buffer[i] < 0x10 ? " 0" : " ");
    lcd.print(buffer[i], HEX);
  }
}

String getPhoneNumber() {
  String phoneNumber = "";

  // Use the ESP32 to make an HTTP request to the server
  // and retrieve the user's phone number from the response

  return phoneNumber;
}

void sendSMS(String message) {
  Serial.println("Sending SMS...");
  if (modem.sendSMS("PHONE_NUMBER", message)) {
    Serial.println("SMS sent successfully!");
  } else {
    Serial.println("Failed to send SMS.");
  }
}