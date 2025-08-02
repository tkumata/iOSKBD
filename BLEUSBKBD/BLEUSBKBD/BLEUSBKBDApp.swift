//
//  BLEUSBKBDApp.swift
//  BLEUSBKBD
//
//  Created by Tomokatsu Kumata on 2025/08/02.
//

import SwiftUI
import CoreBluetooth

// MARK: - Main App
@main
struct FlickKeyboardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - BLE Manager
class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isConnected = false
    @Published var connectionStatus = "未接続"
    @Published var discoveredDevices: [String] = []
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var isScanning = false
    
    // Arduino Nano ESP32のサービスUUID（実際の値に変更してください）
    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    private let characteristicUUID = CBUUID(string: "87654321-4321-4321-4321-CBA987654321")
    
    // デバッグ用：より一般的なサービスUUIDでもスキャン
    private let genericServiceUUID = CBUUID(string: "FFE0") // よく使われるUUID
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            switch central.state {
            case .poweredOn:
                self.connectionStatus = "Bluetooth準備完了"
                self.startScanning()
            case .poweredOff:
                self.connectionStatus = "Bluetooth OFF"
            case .unauthorized:
                self.connectionStatus = "Bluetooth 未許可"
            case .resetting:
                self.connectionStatus = "Bluetooth リセット中"
            case .unsupported:
                self.connectionStatus = "Bluetooth 非対応"
            case .unknown:
                self.connectionStatus = "Bluetooth 状態不明"
            @unknown default:
                self.connectionStatus = "Bluetooth 未知の状態"
            }
        }
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth not ready")
            return
        }
        
        if isScanning {
            centralManager.stopScan()
        }
        
        DispatchQueue.main.async {
            self.connectionStatus = "全デバイススキャン中..."
            self.discoveredDevices.removeAll()
        }
        
        // まず全デバイスをスキャン（デバッグ用）
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        isScanning = true
        
        print("Started scanning for all BLE devices")
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        DispatchQueue.main.async {
            self.connectionStatus += " (スキャン停止)"
        }
    }
    
    func connectToDevice(named deviceName: String) {
        // 発見済みデバイスから接続を試行
        // 実際の実装では、発見したペリフェラルを保存しておく必要があります
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "名前なし"
        let identifier = peripheral.identifier.uuidString
        
        print("発見したデバイス: \(deviceName), RSSI: \(RSSI), ID: \(identifier)")
        
        DispatchQueue.main.async {
            let deviceInfo = "\(deviceName) (\(RSSI)dBm)"
            if !self.discoveredDevices.contains(deviceInfo) {
                self.discoveredDevices.append(deviceInfo)
            }
        }
        
        // Arduino Nano ESP32らしいデバイス名で自動接続を試行
        if deviceName.lowercased().contains("arduino") ||
           deviceName.lowercased().contains("esp32") ||
           deviceName.lowercased().contains("nano") {
            
            print("Arduino ESP32らしいデバイスを発見: \(deviceName)")
            self.peripheral = peripheral
            peripheral.delegate = self
            centralManager.stopScan()
            isScanning = false
            
            DispatchQueue.main.async {
                self.connectionStatus = "接続中: \(deviceName)"
            }
            
            centralManager.connect(peripheral, options: nil)
        }
        
        // 30秒後にスキャンを停止
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if self.isScanning {
                self.stopScanning()
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("デバイスに接続成功: \(peripheral.name ?? "Unknown")")
        DispatchQueue.main.async {
            self.connectionStatus = "サービス検索中..."
        }
        
        // 全てのサービスを検索（デバッグ用）
        peripheral.discoverServices(nil)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("サービス検索エラー: \(error)")
            return
        }
        
        guard let services = peripheral.services else {
            print("サービスが見つかりません")
            return
        }
        
        print("発見したサービス数: \(services.count)")
        for service in services {
            print("サービスUUID: \(service.uuid)")
            // 全ての特性を検索
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("特性検索エラー: \(error)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("特性が見つかりません")
            return
        }
        
        print("サービス \(service.uuid) の特性数: \(characteristics.count)")
        for characteristic in characteristics {
            print("特性UUID: \(characteristic.uuid), プロパティ: \(characteristic.properties)")
            
            // 書き込み可能な特性を探す
            if characteristic.properties.contains(.write) ||
               characteristic.properties.contains(.writeWithoutResponse) {
                print("書き込み可能な特性を発見: \(characteristic.uuid)")
                self.characteristic = characteristic
                
                DispatchQueue.main.async {
                    self.isConnected = true
                    self.connectionStatus = "接続済み (特性: \(characteristic.uuid.uuidString.prefix(8)))"
                }
                
                // テスト送信
                self.sendTestMessage()
                return
            }
        }
        
        // 書き込み可能な特性が見つからない場合
        if self.characteristic == nil {
            print("書き込み可能な特性が見つかりません")
            DispatchQueue.main.async {
                self.connectionStatus = "特性エラー: 書き込み不可"
            }
        }
    }
    
    func sendTestMessage() {
        print("テストメッセージを送信します")
        sendASCII(65) // 'A'
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "切断されました"
        }
        // 自動再接続
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.startScanning()
        }
    }
    
    func sendASCII(_ ascii: UInt8) {
        guard let characteristic = characteristic,
              let peripheral = peripheral else {
            print("送信エラー: 特性またはペリフェラルが無効")
            return
        }
        
        let data = Data([ascii])
        print("送信データ: \(ascii) (文字: \(Character(UnicodeScalar(ascii))))")
        
        // 特性のプロパティに応じて送信方法を選択
        if characteristic.properties.contains(.writeWithoutResponse) {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            print("writeWithoutResponseで送信")
        } else if characteristic.properties.contains(.write) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            print("withResponseで送信")
        } else {
            print("送信エラー: 書き込み不可能な特性")
        }
    }
    
    func sendString(_ string: String) {
        guard isConnected else {
            print("送信エラー: 未接続")
            return
        }
        
        print("文字列送信: \(string)")
        for char in string {
            if let ascii = char.asciiValue {
                sendASCII(ascii)
                // 少し間隔を空ける
                usleep(50000) // 50ms (少し長めに)
            }
        }
    }
    
    // 書き込み完了の確認
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("書き込みエラー: \(error)")
        } else {
            print("書き込み成功: \(characteristic.uuid)")
        }
    }
}

// MARK: - Keyboard Types
enum KeyboardType {
    case kana
    case english
    case symbol
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var currentKeyboard: KeyboardType = .kana
    
    var body: some View {
        VStack {
            // 接続状態表示
            VStack(alignment: .leading) {
                HStack {
                    Circle()
                        .fill(bleManager.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(bleManager.connectionStatus)
                        .font(.caption)
                    Spacer()
                    Button("再スキャン") {
                        bleManager.startScanning()
                    }
                    .font(.caption)
                }
                
                // 発見したデバイス一覧
                if !bleManager.discoveredDevices.isEmpty {
                    VStack(alignment: .leading) {
                        Text("発見されたデバイス:")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        ForEach(bleManager.discoveredDevices.prefix(5), id: \.self) { device in
                            Text("• \(device)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding()
            
            // キーボード切り替えタブ
            HStack {
                Button("あ") { currentKeyboard = .kana }
                    .foregroundColor(currentKeyboard == .kana ? .blue : .gray)
                Button("A") { currentKeyboard = .english }
                    .foregroundColor(currentKeyboard == .english ? .blue : .gray)
                Button("#") { currentKeyboard = .symbol }
                    .foregroundColor(currentKeyboard == .symbol ? .blue : .gray)
            }
            .padding()
            
            // キーボード表示
            switch currentKeyboard {
            case .kana:
                KanaKeyboardView(bleManager: bleManager)
            case .english:
                EnglishKeyboardView(bleManager: bleManager)
            case .symbol:
                SymbolKeyboardView(bleManager: bleManager)
            }
            
            Spacer()
        }
    }
}

// MARK: - Kana Keyboard View
struct KanaKeyboardView: View {
    let bleManager: BLEManager
    
    private let kanaRows = [
        ["あ", "か", "さ", "た", "な"],
        ["は", "ま", "や", "ら", "わ"],
        ["を", "ん", "、", "。", "ー"],
        ["？", "Aあ", "Space", "Del", "Enter"]
    ]
    
    // フリック対応の文字マップ
    private let flickMap: [String: [String]] = [
        "あ": ["あ", "い", "う", "え", "お"],
        "か": ["か", "き", "く", "け", "こ"],
        "さ": ["さ", "し", "す", "せ", "そ"],
        "た": ["た", "ち", "つ", "て", "と"],
        "な": ["な", "に", "ぬ", "ね", "の"],
        "は": ["は", "ひ", "ふ", "へ", "ほ"],
        "ま": ["ま", "み", "む", "め", "も"],
        "や": ["や", "ゆ", "よ"],
        "ら": ["ら", "り", "る", "れ", "ろ"],
        "わ": ["わ", "ん"]
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(kanaRows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        FlickKeyButton(
                            key: key,
                            flickChars: flickMap[key] ?? [key],
                            onTap: { char in
                                handleKeyTap(char)
                            }
                        )
                    }
                }
            }
        }
        .padding()
    }
    
    private func handleKeyTap(_ char: String) {
        switch char {
        case "Space":
            bleManager.sendASCII(32) // Space
        case "Del":
            bleManager.sendASCII(8) // Backspace
        case "Enter":
            bleManager.sendASCII(13) // Enter
        case "Aあ":
            // Ctrl + Space で日本語入力切り替え
            bleManager.sendASCII(17) // Ctrl
            bleManager.sendASCII(32) // Space
        default:
            // ひらがなをローマ字に変換して送信
            let romaji = convertToRomaji(char)
            bleManager.sendString(romaji)
        }
    }
    
    private func convertToRomaji(_ hiragana: String) -> String {
        let romajiMap: [String: String] = [
            "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
            "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
            "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
            "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
            "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
            "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
            "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
            "や": "ya", "ゆ": "yu", "よ": "yo",
            "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
            "わ": "wa", "ん": "nn", "を": "wo",
            "、": ",", "。": ".", "ー": "-", "？": "?"
        ]
        return romajiMap[hiragana] ?? hiragana
    }
}

// MARK: - Flick Key Button
struct FlickKeyButton: View {
    let key: String
    let flickChars: [String]
    let onTap: (String) -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var selectedChar = ""
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 50)
                .cornerRadius(8)
                .overlay(
                    Text(selectedChar.isEmpty ? key : selectedChar)
                        .font(.headline)
                )
            
            // フリック候補表示
            if !selectedChar.isEmpty && flickChars.count > 1 {
                VStack {
                    if flickChars.count > 2 { Text(flickChars[2]).font(.caption) }
                    HStack {
                        if flickChars.count > 3 { Text(flickChars[3]).font(.caption) }
                        Spacer()
                        if flickChars.count > 1 { Text(flickChars[1]).font(.caption) }
                    }
                    if flickChars.count > 4 { Text(flickChars[4]).font(.caption) }
                }
                .frame(width: 80, height: 70)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    selectedChar = getFlickChar(for: dragOffset)
                }
                .onEnded { _ in
                    let finalChar = selectedChar.isEmpty ? key : selectedChar
                    onTap(finalChar)
                    selectedChar = ""
                    dragOffset = .zero
                }
        )
    }
    
    private func getFlickChar(for offset: CGSize) -> String {
        guard flickChars.count > 1 else { return key }
        
        let threshold: CGFloat = 20
        
        if abs(offset.width) < threshold && abs(offset.height) < threshold {
            return flickChars[0] // 中央
        } else if offset.height < -threshold && abs(offset.width) < threshold {
            return flickChars.count > 2 ? flickChars[2] : flickChars[0] // 上
        } else if offset.width > threshold && abs(offset.height) < threshold {
            return flickChars.count > 1 ? flickChars[1] : flickChars[0] // 右
        } else if offset.height > threshold && abs(offset.width) < threshold {
            return flickChars.count > 4 ? flickChars[4] : flickChars[0] // 下
        } else if offset.width < -threshold && abs(offset.height) < threshold {
            return flickChars.count > 3 ? flickChars[3] : flickChars[0] // 左
        }
        
        return flickChars[0]
    }
}

// MARK: - English Keyboard View
struct EnglishKeyboardView: View {
    let bleManager: BLEManager
    
    private let alphabetRows = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]
    
    private let numberRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    
    var body: some View {
        VStack(spacing: 8) {
            // 数字行
            HStack(spacing: 4) {
                ForEach(numberRow, id: \.self) { key in
                    KeyButton(text: key) {
                        bleManager.sendASCII(UInt8(key.unicodeScalars.first!.value))
                    }
                }
            }
            
            // アルファベット行
            ForEach(alphabetRows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { key in
                        KeyButton(text: key) {
                            bleManager.sendASCII(UInt8(key.unicodeScalars.first!.value))
                        }
                    }
                }
            }
            
            // 機能キー行
            HStack(spacing: 8) {
                KeyButton(text: "ESC", width: 50) {
                    bleManager.sendASCII(27) // ESC
                }
                KeyButton(text: "Tab", width: 50) {
                    bleManager.sendASCII(9) // Tab
                }
                KeyButton(text: "Space", width: 120) {
                    bleManager.sendASCII(32) // Space
                }
                KeyButton(text: "Del", width: 50) {
                    bleManager.sendASCII(8) // Backspace
                }
                KeyButton(text: "Enter", width: 60) {
                    bleManager.sendASCII(13) // Enter
                }
            }
        }
        .padding()
    }
}

// MARK: - Symbol Keyboard View
struct SymbolKeyboardView: View {
    let bleManager: BLEManager
    
    private let symbolRows = [
        ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"],
        ["_", "+", "-", "=", "[", "]", "\\", "{", "}", "|"],
        [";", "'", ":", "\"", ",", ".", "/", "<", ">", "?"]
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(symbolRows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { key in
                        KeyButton(text: key) {
                            bleManager.sendASCII(UInt8(key.unicodeScalars.first!.value))
                        }
                    }
                }
            }
            
            // 機能キー
            HStack(spacing: 8) {
                KeyButton(text: "Space", width: 200) {
                    bleManager.sendASCII(32) // Space
                }
                KeyButton(text: "Del", width: 80) {
                    bleManager.sendASCII(8) // Backspace
                }
                KeyButton(text: "Enter", width: 80) {
                    bleManager.sendASCII(13) // Enter
                }
            }
        }
        .padding()
    }
}

// MARK: - Key Button
struct KeyButton: View {
    let text: String
    let width: CGFloat
    let action: () -> Void
    
    init(text: String, width: CGFloat = 30, action: @escaping () -> Void) {
        self.text = text
        self.width = width
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 16))
                .frame(width: width, height: 40)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView()
}
