#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <MFRC522.h>
#include <Servo.h>
#include <Keypad.h>
#include <SD.h>
#include <SoftwareSerial.h>
#include <TinyGsmClient.h>
#include <HTTPClient.h>
#include <RTClib.h>

#define SS_PIN 5
#define RST_PIN 22
MFRC522 mfrc522(SS_PIN, RST_PIN);

LiquidCrystal_I2C lcd(0x3F, 20, 4);
Servo sg90;
Keypad keypad = Keypad(makeKeymap("123A456B789C*0#D"), A0, A1, A2, A3);
SoftwareSerial serialGSM(10, 11);
TinyGsm modem(serialGSM);
RTC_DS3231 rtc;

const char *ssid = "yourSSID";
const char *password = "yourPassword";
const char *server = "your-website.com";

void setup() {
  Serial.begin(115200);
  SPI.begin();
  mfrc522.PCD_Init();
  lcd.begin(16, 2);
  sg90.attach(9);
  rtc.begin();

  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Connecting to WiFi...");
  }
  Serial.println("Connected to WiFi");
}

void loop() {
  if (mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
    String cardId = getCardId();
    lcd.clear();
    lcd.print("Card ID: " + cardId);
    lcd.setCursor(0, 1);
    lcd.print("1: Attendance");
    lcd.setCursor(0, 2);
    lcd.print("2: Hallpass");

    char key = keypad.getKey();
    if (key == '1') {
      handleAttendance(cardId);
    } else if (key == '2') {
      handleHallpass();
    }
  }
}

String getCardId() {
  String cardId = "";
  for (byte i = 0; i < mfrc522.uid.size; i++) {
    cardId += String(mfrc522.uid.uidByte[i] < 0x10 ? "0" : "");
    cardId += String(mfrc522.uid.uidByte[i], HEX);
  }
  return cardId;
}

void handleAttendance(String cardId) {
  String timestamp = getTimestamp();
  if (WiFi.status() == WL_CONNECTED) {
    String url = "/attendance?cardId=" + cardId + "&time=" + timestamp;
    sendToServer(url);
  } else {
    saveToSD(cardId, timestamp, "Attendance");
  }
}

void handleHallpass() {
  sg90.write(90);
  delay(1000);
  sg90.write(0);

  if (WiFi.status() == WL_CONNECTED) {
    String timestamp = getTimestamp();
    String url = "/hallpass?time=" + timestamp;
    sendToServer(url);
  } else {
    saveToSD("Hallpass", getTimestamp(), "Event");
  }

  // Get user's phone number from GSM module and send SMS
  String phoneNumber = getUserPhoneNumber();
  String message = "Hallpass granted at " + getTimestamp();
  sendSMS(phoneNumber, message);
}

String getTimestamp() {
  DateTime now = rtc.now();
  return String(now.year()) + "-" + now.month() + "-" + now.day() + " " + now.hour() + ":" + now.minute() + ":" + now.second();
}

void sendToServer(String url) {
  HTTPClient http;
  http.begin(server + url);
  int httpCode = http.GET();
  if (httpCode > 0) {
    Serial.println("Data sent to server");
  }
  http.end();
}

void saveToSD(String data, String timestamp, String type) {
  if (SD.begin(4)) {
    File file = SD.open(type + ".txt", FILE_WRITE);
    if (file) {
      file.println(data + "," + timestamp);
      file.close();
    }
  }
}

String getUserPhoneNumber() {
  // Implement GSM functionality to get the user's phone number
  // Example: serialGSM.println("AT+CNUM");
  // Parse the response to extract the phone number
  return "userPhoneNumber";
}

void sendSMS(String phoneNumber, String message) {
  modem.beginSMS(phoneNumber.c_str());
  modem.print(message);
  modem.endSMS();
}