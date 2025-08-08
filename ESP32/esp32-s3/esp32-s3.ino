#include "BLEDevice.h"
#include "BLEServer.h"
#include "BLEUtils.h"
#include "BLE2902.h"
#include "USB.h"
#include "USBHIDKeyboard.h"

// デバッグ用フラグ - リリース時は無効にしてメモリ・パフォーマンス向上
// #define DEBUG_ENABLED
#ifdef DEBUG_ENABLED
  #define DEBUG_PRINT(x) Serial.print(x)
  #define DEBUG_PRINTLN(x) Serial.println(x)
#else
  #define DEBUG_PRINT(x)
  #define DEBUG_PRINTLN(x)
#endif

// BLE設定
#define SERVICE_UUID        "12345678-1234-1234-1234-123456789abc"
#define CHARACTERISTIC_UUID "87654321-4321-4321-4321-cba987654321"

// 特殊キーコード定数
#define KEY_ESC_CODE         0x1B
#define KEY_TAB_CODE         0x09
#define KEY_BACKSPACE_CODE   0x08
#define KEY_ENTER_CODE1      0x0D
#define KEY_ENTER_CODE2      0x0A
#define KEY_SPACE_CODE       0x20
#define KEY_CTRL_SPACE_CODE  0xFF
#define KEY_CTRL_L_CODE      0x0C
#define KEY_CTRL_CODE        0x11
#define KEY_ALT_CODE         0x12
#define KEY_SHIFT_CODE       0x10

// タイミング設定
#define KEY_PRESS_DELAY      30  // キー入力間隔（ms）
#define INIT_DELAY           500 // 初期化待機時間
#define CONNECTION_CHECK_INTERVAL 10000 // 接続状態チェック間隔

// グローバル変数
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
USBHIDKeyboard keyboard;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// 関数の前方宣言
void processReceivedData(String data);
bool sendSpecialKey(char c);
void sendModifierKey(char c);
void sendSymbol(char c);
void sendCharacter(char c);

// 接続状態管理用コールバック
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      DEBUG_PRINTLN("=== BLE Device Connected ===");
      DEBUG_PRINT("Connected devices: ");
      DEBUG_PRINTLN(pServer->getConnectedCount());
      
      // 接続確認用のテストメッセージ
      if (pCharacteristic != NULL) {
        String testMsg = "ESP32 Ready";
        pCharacteristic->setValue(testMsg.c_str());
        pCharacteristic->notify();
        DEBUG_PRINTLN("Sent ready notification to iPhone");
      }
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      DEBUG_PRINTLN("=== BLE Device Disconnected ===");
      DEBUG_PRINT("Remaining connected devices: ");
      DEBUG_PRINTLN(pServer->getConnectedCount());
    }
};

// データ受信コールバック
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      DEBUG_PRINTLN("=== BLE Data Received ===");
      std::string rxValue = pCharacteristic->getValue();
      String data = String(rxValue.c_str());
      
      DEBUG_PRINT("Data length: ");
      DEBUG_PRINTLN(data.length());

      if (data.length() > 0) {
        #ifdef DEBUG_ENABLED
        DEBUG_PRINT("Raw data (HEX): ");
        for (int i = 0; i < data.length(); i++) {
          DEBUG_PRINT("0x");
          DEBUG_PRINT((uint8_t)data[i]);
          DEBUG_PRINT(" ");
        }
        DEBUG_PRINTLN();
        
        DEBUG_PRINT("Raw data (ASCII): ");
        for (int i = 0; i < data.length(); i++) {
          if (data[i] >= 32 && data[i] <= 126) {
            DEBUG_PRINT((char)data[i]);
          } else {
            DEBUG_PRINT("[");
            DEBUG_PRINT((uint8_t)data[i]);
            DEBUG_PRINT("]");
          }
        }
        DEBUG_PRINTLN();
        #endif

        // 受信したデータを処理
        processReceivedData(data);
      } else {
        DEBUG_PRINTLN("Empty data received");
      }
      DEBUG_PRINTLN("=== BLE Processing End ===");
    }
    
    void onRead(BLECharacteristic *pCharacteristic) {
      DEBUG_PRINTLN("BLE Read request received");
    }
};

// 特殊キーの処理
bool sendSpecialKey(char c) {
  switch (c) {
    case KEY_ESC_CODE:
      keyboard.press(KEY_ESC);
      keyboard.releaseAll();
      DEBUG_PRINTLN("Sent: ESC");
      return true;
    case KEY_TAB_CODE:
      keyboard.press(KEY_TAB);
      keyboard.releaseAll();
      DEBUG_PRINTLN("Sent: TAB");
      return true;
    case KEY_BACKSPACE_CODE:
      keyboard.press(KEY_BACKSPACE);
      keyboard.releaseAll();
      DEBUG_PRINTLN("Sent: BACKSPACE");
      return true;
    case KEY_ENTER_CODE1:
    case KEY_ENTER_CODE2:
      keyboard.press(KEY_RETURN);
      keyboard.releaseAll();
      DEBUG_PRINTLN("Sent: ENTER");
      return true;
    case KEY_SPACE_CODE:
      keyboard.press(' ');
      keyboard.releaseAll();
      DEBUG_PRINTLN("Sent: SPACE");
      return true;
    case KEY_CTRL_SPACE_CODE:
      keyboard.press(KEY_LEFT_CTRL);
      keyboard.press(' ');
      keyboard.releaseAll();
      DEBUG_PRINTLN("Sent: CTRL+SPACE");
      return true;
    case KEY_CTRL_L_CODE:
      keyboard.press(KEY_LEFT_CTRL);
      keyboard.press('l');
      keyboard.releaseAll();
      DEBUG_PRINTLN("Sent: CTRL+L");
      return true;
    default:
      return false;
  }
}

// 修飾キーの処理
void sendModifierKey(char c) {
  switch (c) {
    case KEY_CTRL_CODE:
      keyboard.press(KEY_LEFT_CTRL);
      keyboard.releaseAll();
      DEBUG_PRINTLN("Sent: CTRL");
      break;
    case KEY_ALT_CODE:
      keyboard.press(KEY_LEFT_ALT);
      keyboard.releaseAll();
      DEBUG_PRINTLN("Sent: ALT");
      break;
    case KEY_SHIFT_CODE:
      keyboard.press(KEY_LEFT_SHIFT);
      keyboard.releaseAll();
      DEBUG_PRINTLN("Sent: SHIFT");
      break;
  }
}

// 通常文字の処理
void sendCharacter(char c) {
  if (c >= 'a' && c <= 'z') {
    keyboard.press(c);
    keyboard.releaseAll();
    DEBUG_PRINT("Sent char: ");
    DEBUG_PRINTLN(c);
  }
  else if (c >= 'A' && c <= 'Z') {
    keyboard.press(KEY_LEFT_SHIFT);
    keyboard.press(c - 'A' + 'a');
    keyboard.releaseAll();
    DEBUG_PRINT("Sent SHIFT+");
    DEBUG_PRINTLN((char)(c - 'A' + 'a'));
  }
  else if (c >= '0' && c <= '9') {
    keyboard.press(c);
    keyboard.releaseAll();
    DEBUG_PRINT("Sent number: ");
    DEBUG_PRINTLN(c);
  }
  else {
    DEBUG_PRINT("Sending symbol: ");
    DEBUG_PRINTLN(c);
    sendSymbol(c);
  }
}

// ASCIIコードをスキャンコードに変換して送信（最適化版）
void processReceivedData(String data) {
  #ifdef DEBUG_ENABLED
  DEBUG_PRINT("Processing data: ");
  for (int i = 0; i < data.length(); i++) {
    DEBUG_PRINT("0x");
    DEBUG_PRINT((uint8_t)data[i]);
    DEBUG_PRINT(" ");
  }
  DEBUG_PRINTLN();
  #endif

  for (int i = 0; i < data.length(); i++) {
    char c = data[i];
    
    DEBUG_PRINT("Sending key: ");
    DEBUG_PRINT(c);
    DEBUG_PRINT(" (0x");
    DEBUG_PRINT((uint8_t)c);
    DEBUG_PRINTLN(")");
    
    // 特殊キー → 修飾キー → 通常文字の順で処理
    if (sendSpecialKey(c)) {
      // 処理済み
    } else if (c == KEY_CTRL_CODE || c == KEY_ALT_CODE || c == KEY_SHIFT_CODE) {
      sendModifierKey(c);
    } else {
      sendCharacter(c);
    }
    
    delay(KEY_PRESS_DELAY);
  }
  DEBUG_PRINTLN("Data processing completed");
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
  #ifdef DEBUG_ENABLED
  Serial.begin(115200);
  DEBUG_PRINTLN("Starting BLE to USB Keyboard Bridge...");
  #endif
  delay(INIT_DELAY); // 初期化待機

  // USB初期化を最初に行う
  USB.begin();
  delay(INIT_DELAY);
  
  // USB HIDキーボードの初期化
  keyboard.begin();
  delay(INIT_DELAY * 2); // キーボード初期化待機
  
  DEBUG_PRINTLN("USB HID Keyboard initialized");

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
  
  DEBUG_PRINTLN("BLE Peripheral ready and advertising...");
  DEBUG_PRINTLN("Device name: ESP32-Keyboard");
  DEBUG_PRINTLN("Service UUID: " + String(SERVICE_UUID));
  DEBUG_PRINTLN("Waiting for iPhone connection...");
}

void loop() {
  // 接続状態の変化を監視
  if (!deviceConnected && oldDeviceConnected) {
    DEBUG_PRINTLN("Device disconnected. Restarting advertising...");
    delay(INIT_DELAY); // スタック処理のための短い待機
    pServer->getAdvertising()->start(); // 再接続のためのアドバタイジング再開
    DEBUG_PRINTLN("Advertising restarted");
    oldDeviceConnected = deviceConnected;
  }
  
  // 新しい接続を検出
  if (deviceConnected && !oldDeviceConnected) {
    DEBUG_PRINTLN("Device connected successfully");
    oldDeviceConnected = deviceConnected;
  }

  // アドバタイジング状態の定期チェック（デバッグ時のみ）
  #ifdef DEBUG_ENABLED
  static unsigned long lastCheck = 0;
  if (millis() - lastCheck > CONNECTION_CHECK_INTERVAL) {
    if (!deviceConnected) {
      DEBUG_PRINTLN("Still advertising and waiting for connection...");
    } else {
      DEBUG_PRINTLN("BLE connected, waiting for data...");
    }
    lastCheck = millis();
  }
  #endif

  delay(100);
}