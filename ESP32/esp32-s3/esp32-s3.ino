#include "BLEDevice.h"
#include "BLEServer.h"
#include "BLEUtils.h"
#include "BLE2902.h"
#include "USB.h"
#include "USBHIDKeyboard.h"

// デバッグ用フラグ
#define DEBUG_USB_KEYBOARD

// BLE設定
#define SERVICE_UUID        "12345678-1234-1234-1234-123456789abc"
#define CHARACTERISTIC_UUID "87654321-4321-4321-4321-cba987654321"

// グローバル変数
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
USBHIDKeyboard keyboard;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// 関数の前方宣言
void processReceivedData(std::string data);
void sendSymbol(char c);

// 接続状態管理用コールバック
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("=== BLE Device Connected ===");
      Serial.print("Connected devices: ");
      Serial.println(pServer->getConnectedCount());
      
      // 接続確認用のテストメッセージ
      if (pCharacteristic != NULL) {
        std::string testMsg = "ESP32 Ready";
        pCharacteristic->setValue(testMsg);
        pCharacteristic->notify();
        Serial.println("Sent ready notification to iPhone");
      }
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("=== BLE Device Disconnected ===");
      Serial.print("Remaining connected devices: ");
      Serial.println(pServer->getConnectedCount());
    }
};

// データ受信コールバック
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      Serial.println("=== BLE Data Received ===");
      std::string rxValue = pCharacteristic->getValue();
      
      Serial.print("Data length: ");
      Serial.println(rxValue.length());

      if (rxValue.length() > 0) {
        Serial.print("Raw data (HEX): ");
        for (int i = 0; i < rxValue.length(); i++) {
          Serial.print("0x");
          Serial.print((uint8_t)rxValue[i], HEX);
          Serial.print(" ");
        }
        Serial.println();
        
        Serial.print("Raw data (ASCII): ");
        for (int i = 0; i < rxValue.length(); i++) {
          if (rxValue[i] >= 32 && rxValue[i] <= 126) {
            Serial.print((char)rxValue[i]);
          } else {
            Serial.print("[");
            Serial.print((uint8_t)rxValue[i]);
            Serial.print("]");
          }
        }
        Serial.println();

        // 受信したデータを処理
        processReceivedData(rxValue);
      } else {
        Serial.println("Empty data received");
      }
      Serial.println("=== BLE Processing End ===");
    }
    
    void onRead(BLECharacteristic *pCharacteristic) {
      Serial.println("BLE Read request received");
    }
};

// ASCIIコードをスキャンコードに変換して送信
void processReceivedData(std::string data) {
  Serial.print("Processing data: ");
  for (int i = 0; i < data.length(); i++) {
    Serial.print("0x");
    Serial.print((uint8_t)data[i], HEX);
    Serial.print(" ");
  }
  Serial.println();

  for (int i = 0; i < data.length(); i++) {
    char c = data[i];
    
    Serial.print("Sending key: ");
    Serial.print(c);
    Serial.print(" (0x");
    Serial.print((uint8_t)c, HEX);
    Serial.println(")");
    
    // 特殊なコマンドの処理
    if (c == 0x1B) { // ESC
      keyboard.press(KEY_ESC);
      keyboard.releaseAll();
      Serial.println("Sent: ESC");
      continue;
    }
    
    if (c == 0x09) { // Tab
      keyboard.press(KEY_TAB);
      keyboard.releaseAll();
      Serial.println("Sent: TAB");
      continue;
    }
    
    if (c == 0x08) { // Backspace (Del)
      keyboard.press(KEY_BACKSPACE);
      keyboard.releaseAll();
      Serial.println("Sent: BACKSPACE");
      continue;
    }
    
    if (c == 0x0D || c == 0x0A) { // Enter
      keyboard.press(KEY_RETURN);
      keyboard.releaseAll();
      Serial.println("Sent: ENTER");
      continue;
    }
    
    if (c == 0x20) { // Space
      keyboard.press(' ');
      keyboard.releaseAll();
      Serial.println("Sent: SPACE");
      continue;
    }

    // Ctrl+Space の組み合わせ（「Aあ」キー用）
    // if (i + 1 < data.length() && c == 0x11 && data[i + 1] == 0x20) {
    if (c == 0xff) {
      keyboard.press(KEY_LEFT_CTRL);
      keyboard.press(' ');
      keyboard.releaseAll();
      Serial.println("Sent: CTRL+SPACE");
      i++; // 次の文字（Space）をスキップ
      continue;
    }
    
    // 修飾キーの処理
    if (c == 0x11) { // Ctrl
      keyboard.press(KEY_LEFT_CTRL);
      keyboard.releaseAll();
      Serial.println("Sent: CTRL");
      continue;
    }
    
    if (c == 0x12) { // Alt
      keyboard.press(KEY_LEFT_ALT);
      keyboard.releaseAll();
      Serial.println("Sent: ALT");
      continue;
    }
    
    if (c == 0x10) { // Shift
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.releaseAll();
      Serial.println("Sent: SHIFT");
      continue;
    }

    // 通常の文字・数字・記号の処理
    if (c >= 'a' && c <= 'z') {
      keyboard.press(c);
      keyboard.releaseAll();
      Serial.print("Sent char: ");
      Serial.println(c);
    }
    else if (c >= 'A' && c <= 'Z') {
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press(c - 'A' + 'a'); // 小文字に変換してShiftと組み合わせ
      keyboard.releaseAll();
      Serial.print("Sent SHIFT+");
      Serial.println((char)(c - 'A' + 'a'));
    }
    else if (c >= '0' && c <= '9') {
      keyboard.press(c);
      keyboard.releaseAll();
      Serial.print("Sent number: ");
      Serial.println(c);
    }
    else {
      // 記号の処理
      Serial.print("Sending symbol: ");
      Serial.println(c);
      sendSymbol(c);
    }
    
    delay(50); // キー入力間隔を少し長めに
  }
  Serial.println("Data processing completed");
}

// 記号の送信処理
void sendSymbol(char c) {
  switch (c) {
    case '!':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('1');
      break;
    case '@':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('2');
      break;
    case '#':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('3');
      break;
    case '$':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('4');
      break;
    case '%':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('5');
      break;
    case '^':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('6');
      break;
    case '&':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('7');
      break;
    case '*':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('8');
      break;
    case '(':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('9');
      break;
    case ')':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('0');
      break;
    case '_':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('-');
      break;
    case '+':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('=');
      break;
    case '{':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('[');
      break;
    case '}':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press(']');
      break;
    case '|':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('\\');
      break;
    case ':':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press(';');
      break;
    case '"':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('\'');
      break;
    case '<':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press(',');
      break;
    case '>':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('.');
      break;
    case '?':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('/');
      break;
    case '~':
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.press('`');
      break;
    // Shiftなしの記号
    case '-':
    case '=':
    case '[':
    case ']':
    case '\\':
    case ';':
    case '\'':
    case ',':
    case '.':
    case '/':
    case '`':
      keyboard.press(c);
      break;
    default:
      // 未対応の文字はそのまま送信を試す
      keyboard.press(c);
      break;
  }
  keyboard.releaseAll();
}

void setup() {
  Serial.begin(115200);
  Serial.println("Starting BLE to USB Keyboard Bridge...");
  delay(1000); // 初期化待機

  // USB初期化を最初に行う
  USB.begin();
  delay(500);
  
  // USB HIDキーボードの初期化
  keyboard.begin();
  delay(1000); // キーボード初期化待機
  
  Serial.println("USB HID Keyboard initialized");
  
  // テスト用のキー送信
  // Serial.println("Testing USB keyboard...");
  // delay(2000); // PCに認識される時間を与える
  // keyboard.print("USB Keyboard Test - ");
  // delay(500);
  // keyboard.println("Ready!");
  // Serial.println("USB keyboard test completed");

  // BLEデバイスの初期化
  BLEDevice::init("ESP32-Keyboard");
  
  // BLEサーバーの作成
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // BLEサービスの作成
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // BLE特性の作成
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_WRITE |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );

  pCharacteristic->setCallbacks(new MyCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());

  // サービス開始
  pService->start();

  // アドバタイジング設定
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // iPhone接続性向上
  pAdvertising->setMaxPreferred(0x12);
  
  // アドバタイジング開始
  pServer->getAdvertising()->start();
  
  Serial.println("BLE Peripheral ready and advertising...");
  Serial.println("Device name: ESP32-Keyboard");
  Serial.println("Service UUID: " + String(SERVICE_UUID));
  Serial.println("Waiting for iPhone connection...");
}

void loop() {
  // 接続状態の変化を監視
  if (!deviceConnected && oldDeviceConnected) {
    Serial.println("Device disconnected. Restarting advertising...");
    delay(500); // スタック処理のための短い待機
    pServer->getAdvertising()->start(); // 再接続のためのアドバタイジング再開
    Serial.println("Advertising restarted");
    oldDeviceConnected = deviceConnected;
  }
  
  // 新しい接続を検出
  if (deviceConnected && !oldDeviceConnected) {
    Serial.println("Device connected successfully");
    oldDeviceConnected = deviceConnected;
  }

  // シリアル入力からのテスト機能
  // if (Serial.available()) {
  //   String testInput = Serial.readString();
  //   testInput.trim();
  //   Serial.print("Serial test input: ");
  //   Serial.println(testInput);
    
  //   // シリアル入力をキーボードに送信（テスト用）
  //   keyboard.print(testInput);
  //   Serial.println("Test input sent to keyboard");
  // }

  // アドバタイジング状態の定期チェック
  static unsigned long lastCheck = 0;
  if (millis() - lastCheck > 10000) { // 10秒ごとにチェック
    if (!deviceConnected) {
      Serial.println("Still advertising and waiting for connection...");
    } else {
      Serial.println("BLE connected, waiting for data...");
    }
    lastCheck = millis();
  }

  delay(100);
}