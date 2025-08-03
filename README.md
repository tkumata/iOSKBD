# マイコンを通じて iPhone をパソコンのキーボードにする

## 概要

Arduino Nano ESP32 を用いて iPhone をパソコンの HID デバイスにする。

## 準備

- Arduino IDE
- Arduino Nano ESP32
- iPhone
- Apple Silicone Mac
- Xcode

## Arduino IDE

### ボードマネージャ

- Arduino ESP32 Boards by Arduino

### ライブラリ

- 何も入れない

注意:

- esp32 by Espressif Systems は表記が Arduino ESP32 なので注意が必要。これは dev 版なので入れない。
- USBHID は競合するから不要。
- Arduino Nano ESP32 は DFU モードにする (基本、boot ボタンを押しっぱで電源に接続)

あああああiPhoneからtype
