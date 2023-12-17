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
Keypad keypad = Keypad(makeKeymap("123A456B789C*0#D"), AO, A1, A2, A3);
SoftwareSerial serialGSM(10,11);
TinyGsm modem(serialGSM);
RTC_DS3231 rtc;

const char *ssid ="WifiName" //name sa wifi e connect
const char *password ="Wifipassword" //password sa wifi
const char *server = "Website.com"// ngan sa website server

void setup() {
  Serial.begin(115200);
  SPI.begin();
  mfrc522.PCD_Init();
  sg90.attach(9);
  rtc.begin();

  //connect sa wifi
  Wifi.begin(ssid, password);
  while(Wifi.status()!= WL_CONNECTED) {
    delay(1000);
    Serial.println("Connecting to Wifi...");
  }
  Serial.println("Connected to Wifi");
}

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
      handleHallpass(cardId);
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
  if (Wifi.status() == WL_CONNECTED) {
    String url = "/attendance?cardId=" + cardId + "&time=" + timestamp;
    sendToServer(url);
  } else {
    saveToSD(cardId, timestamp, "Attendance");
    sendSMS(getUserPhoneNumber(cardId), "Attendance has been taken at" + timestamp);
  }
}
 //pasaka sa hallpass if '2'
void handleHallpass(String cardId) {
  sg90.write(90);
  delay(1000);
  sg90.write(0);
}

String getTimestamp() {
  DateTime now = rtc.now();
  return String(now.year()) + "-" + now.month() + now.day() + " "+ now.hour() + ":" + now.minute() + ":" + now.second();
}
 //Connect sa data padung sa website 
void sendToServer(String url) {
  HTTPClient http;
  http.begin(server + url);
  int httpCode = http.GET();
  if (httpCode > 0) {
    Serial.println("Data sent to server");
  }
  http.end();
}
//store data if walay connection og automatically mo send sa data nga store sa website if mo balik ang connection

void saveToSD(String cardId, String timestamp, String type) {
  if (WiFi.status() != WL_CONNECTED) {
    // If there is no WiFi connection, save data to SD card
    if (SD.begin(4)) {
      File file = SD.open(type + ".txt", FILE_WRITE);
      if (file) {
        file.println("Card ID: " + cardId + ", Time: " + timestamp);
        file.close();
      }
    }
  } else {
    // If there is a WiFi connection, attempt to send data to the server
    String url = "/send_data"; // Replace with the appropriate URL for sending data
    String data = "cardId=" + cardId + "&time=" + timestamp;

    HTTPClient http;
    http.begin(server + url);
    http.addHeader("Content-Type", "application/x-www-form-urlencoded");

    int httpCode = http.POST(data);

    if (httpCode > 0) {
      Serial.println("Data sent to server");
    }

    http.end();
  }
}
String getPhoneNumber(String cardId) {
  String url = "/getPhoneNumber?cardId=" + cardId;
  HTTPClient http;
  http.begin(server + url);

  int httpCode = http.GET();
  String phoneNumber = "";

  if (httpCode > 0) {
    // Assuming the phone number is returned in the response body
    phoneNumber = http.getString();
    Serial.println("Received phone number: " + phoneNumber);
  } else {
    Serial.println("Failed to get phone number");
  }

  http.end();
  return phoneNumber;
}