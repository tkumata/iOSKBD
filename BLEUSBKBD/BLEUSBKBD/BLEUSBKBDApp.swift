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
//                self.sendTestMessage()
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
    
    func sendControlSequence(ctrl: Bool, key: UInt8) {
        guard isConnected else {
            print("送信エラー: 未接続")
            return
        }
        
        print("制御シーケンス送信 - Ctrl: \(ctrl), Key: \(key)")
        
        if ctrl {
            // Ctrl+キーの組み合わせを送信
            // 多くのシステムでは Ctrl + 文字は文字コード -64 か -96 で表現される
            let ctrlKey = key >= 96 ? key - 96 : key
            sendASCII(ctrlKey)
        } else {
            sendASCII(key)
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
    @State private var showModifierKeys = false
    @State private var lastInputChar = ""
    @State private var modifierKeyTimer: Timer?
    
    private let kanaRows = [
        ["あ", "か", "さ", "た"],
        ["な", "は", "ま", "や"],
        ["ら", "わ", "ん", "、"],
        ["Aあ", "Space", "Del", "Enter"]
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
        "わ": ["わ", "ん"],
        "、": ["、", "。", "ー"]
    ]
    
    // 濁音・半濁音対応マップ
    private let dakutenMap: [String: String] = [
        "か": "が", "き": "ぎ", "く": "ぐ", "け": "げ", "こ": "ご",
        "さ": "ざ", "し": "じ", "す": "ず", "せ": "ぜ", "そ": "ぞ",
        "た": "だ", "ち": "ぢ", "つ": "づ", "て": "で", "と": "ど",
        "は": "ば", "ひ": "び", "ふ": "ぶ", "へ": "べ", "ほ": "ぼ"
    ]
    
    private let handakutenMap: [String: String] = [
        "は": "ぱ", "ひ": "ぴ", "ふ": "ぷ", "へ": "ぺ", "ほ": "ぽ"
    ]
    
    // 小書き文字対応マップ
    private let smallCharMap: [String: String] = [
        "あ": "ぁ", "い": "ぃ", "う": "ぅ", "え": "ぇ", "お": "ぉ",
        "や": "ゃ", "ゆ": "ゅ", "よ": "ょ",
        "つ": "っ", "わ": "ゎ"
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // 修飾キー行（濁音・半濁音・小書き文字）
            if showModifierKeys {
                HStack(spacing: 8) {
                    // 濁音キー
                    if dakutenMap[lastInputChar] != nil {
                        ModifierCharButton(
                            char: dakutenMap[lastInputChar]!,
                            label: "゛",
                            onTap: { char in
                                handleModifierKeyTap(char)
                            }
                        )
                    }
                    
                    // 半濁音キー（は行のみ）
                    if handakutenMap[lastInputChar] != nil {
                        ModifierCharButton(
                            char: handakutenMap[lastInputChar]!,
                            label: "゜",
                            onTap: { char in
                                handleModifierKeyTap(char)
                            }
                        )
                    }
                    
                    // 小書き文字キー
                    if smallCharMap[lastInputChar] != nil {
                        ModifierCharButton(
                            char: smallCharMap[lastInputChar]!,
                            label: "小",
                            onTap: { char in
                                handleModifierKeyTap(char)
                            }
                        )
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // 通常のキーボード行
            ForEach(kanaRows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { key in
                        IOSFlickKeyButton(
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
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemGray6))
        )
        .padding(.horizontal, 4)
    }
    
    private func handleKeyTap(_ char: String) {
        print("かなキーボード入力: \(char)")
        
        // 修飾キー表示をリセット
        hideModifierKeys()
        
        switch char {
        case "Space":
            bleManager.sendASCII(32) // Space
        case "Del":
            bleManager.sendASCII(8) // Backspace
        case "Enter":
            bleManager.sendASCII(13) // Enter
        case "123":
            // 数字キーボードに切り替える処理を実装する必要がある
            print("数字キーボード切り替え")
        case "Aあ":
            // Ctrl + Space で日本語入力切り替え（同時送信）
            print("Aあキーが押されました - Ctrl+Space送信")
            bleManager.sendASCII(255) // よくないけど未割り当てのコードを送信
        case "、":
            bleManager.sendASCII(44) // カンマ ","
        case "。":
            bleManager.sendASCII(46) // ピリオド "."
        case "ー":
            bleManager.sendASCII(45) // ハイフン "-"
        case "？":
            bleManager.sendASCII(63) // クエスチョン "?"
        default:
            // ひらがなをローマ字に変換して送信
            let romaji = convertToRomaji(char)
            if !romaji.isEmpty {
                bleManager.sendString(romaji)
                
                // 濁音・半濁音・小書き文字が可能な文字の場合、修飾キーを表示
                if canShowModifierKeys(for: char) {
                    showModifierKeysFor(char)
                }
            }
        }
    }
    
    private func handleModifierKeyTap(_ char: String) {
        print("修飾キー入力: \(char)")
        
        // 前の文字を削除（Backspace）
        bleManager.sendASCII(8)
        usleep(30000) // 30ms待機
        
        // 修飾後の文字を送信
        let romaji = convertToRomaji(char)
        if !romaji.isEmpty {
            bleManager.sendString(romaji)
        }
        
        // 修飾キーを非表示
        hideModifierKeys()
    }
    
    private func canShowModifierKeys(for char: String) -> Bool {
        return dakutenMap[char] != nil || handakutenMap[char] != nil || smallCharMap[char] != nil
    }
    
    private func showModifierKeysFor(_ char: String) {
        lastInputChar = char
        withAnimation(.easeInOut(duration: 0.2)) {
            showModifierKeys = true
        }
        
        // 3秒後に自動的に非表示
        modifierKeyTimer?.invalidate()
        modifierKeyTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            hideModifierKeys()
        }
    }
    
    private func hideModifierKeys() {
        modifierKeyTimer?.invalidate()
        withAnimation(.easeInOut(duration: 0.2)) {
            showModifierKeys = false
        }
        lastInputChar = ""
    }
    
    private func convertToRomaji(_ hiragana: String) -> String {
        let romajiMap: [String: String] = [
            // 基本文字
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
            
            // 濁音
            "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
            "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
            "だ": "da", "ぢ": "di", "づ": "du", "で": "de", "ど": "do",
            "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
            
            // 半濁音
            "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
            
            // 小書き文字
            "ぁ": "xa", "ぃ": "xi", "ぅ": "xu", "ぇ": "xe", "ぉ": "xo",
            "ゃ": "xya", "ゅ": "xyu", "ょ": "xyo",
            "っ": "xtu", "ゎ": "xwa",
            
            // 記号
            "、": ",", "。": ".", "ー": "-", "？": "?"
        ]
        return romajiMap[hiragana] ?? hiragana
    }
}

// MARK: - Modifier Character Button
struct ModifierCharButton: View {
    let char: String
    let label: String
    let onTap: (String) -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            onTap(char)
        }) {
            VStack(spacing: 2) {
                Text(char)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPressed ? Color(UIColor.systemGray3) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                    )
                    .shadow(
                        color: Color.black.opacity(0.25),
                        radius: 2,
                        x: 0,
                        y: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
            if pressing {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }, perform: {})
    }
}

// MARK: - iOS Style Flick Key Button (かなキーボードのみ)
struct IOSFlickKeyButton: View {
    let key: String
    let flickChars: [String]
    let onTap: (String) -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var selectedChar = ""
    @State private var isDragging = false
    @State private var hasTriggered = false
    @State private var isPressed = false
    
    private var isSpecialKey: Bool {
        return !["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ", "ん", "、", "。"].contains(key)
    }
    
    private var keyWidth: CGFloat {
        switch key {
        case "Space":
            return 120
        case "Del", "123", "Aあ", "Enter":
            return 70
        default:
            return 70
        }
    }
    
    var body: some View {
        ZStack {
            // キーの背景
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isPressed ?
                    Color(UIColor.systemGray3) :
                    (isSpecialKey ? Color(UIColor.systemGray2) : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(
                    color: Color.black.opacity(0.25),
                    radius: 2,
                    x: 0,
                    y: 2
                )
                .frame(width: keyWidth, height: 50)
            
            // キーのテキスト
            Text(selectedChar.isEmpty ? getDisplayText(key) : selectedChar)
                .font(.system(size: getFontSize(key), weight: .medium))
                .foregroundColor(isSpecialKey ? Color(UIColor.systemGray) : Color.black)
            
            // フリック候補表示オーバーレイ
            if !selectedChar.isEmpty && flickChars.count > 1 && isDragging {
                FlickCandidatesOverlay(
                    candidates: flickChars,
                    selectedChar: selectedChar
                )
            }
        }
        .scaleEffect(isPressed ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !hasTriggered {
                        if !isPressed {
                            isPressed = true
                            // タプティックフィードバック
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        
                        dragOffset = value.translation
                        let distance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                        
                        if distance > 20 && flickChars.count > 1 {
                            // フリック入力として処理
                            isDragging = true
                            let newSelectedChar = getFlickChar(for: dragOffset)
                            if selectedChar != newSelectedChar {
                                selectedChar = newSelectedChar
                                // フリック時のフィードバック
                                let selectionFeedback = UISelectionFeedbackGenerator()
                                selectionFeedback.selectionChanged()
                            }
                        }
                    }
                }
                .onEnded { value in
                    if !hasTriggered {
                        hasTriggered = true
                        isPressed = false
                        
                        let distance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                        
                        if distance <= 20 {
                            // タップとして処理
                            print("タップされたキー: \(key)")
                            onTap(key)
                        } else {
                            // フリック入力として処理
                            let finalChar = selectedChar.isEmpty ? key : selectedChar
                            print("フリック入力されたキー: \(finalChar)")
                            onTap(finalChar)
                        }
                        
                        // 状態をリセット
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            selectedChar = ""
                            dragOffset = .zero
                            isDragging = false
                            hasTriggered = false
                        }
                    }
                }
        )
    }
    
    private func getDisplayText(_ key: String) -> String {
        switch key {
        case "Space":
            return "空白"
        case "Del":
            return "削除"
        case "Enter":
            return "改行"
        case "Aあ":
            return "英/あ"
        case "123":
            return "123"
        default:
            return key
        }
    }
    
    private func getFontSize(_ key: String) -> CGFloat {
        switch key {
        case "Space", "Del", "Enter", "Aあ", "123":
            return 16
        default:
            return 22
        }
    }
    
    private func getFlickChar(for offset: CGSize) -> String {
        guard flickChars.count > 1 else { return key }
        
        let threshold: CGFloat = 25
        
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

// MARK: - Flick Candidates Overlay
struct FlickCandidatesOverlay: View {
    let candidates: [String]
    let selectedChar: String
    
    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemGray5))
                .shadow(
                    color: Color.black.opacity(0.25),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                .frame(width: 140, height: 120)
            
            // 候補文字配置
            VStack(spacing: 8) {
                // 上（う）
                if candidates.count > 2 {
                    CandidateCharView(
                        char: candidates[2],
                        isSelected: selectedChar == candidates[2]
                    )
                } else {
                    Spacer().frame(height: 24)
                }
                
                HStack(spacing: 12) {
                    // 左（え）
                    if candidates.count > 3 {
                        CandidateCharView(
                            char: candidates[3],
                            isSelected: selectedChar == candidates[3]
                        )
                    } else {
                        Spacer().frame(width: 24)
                    }
                    
                    // 中央（あ）
                    CandidateCharView(
                        char: candidates[0],
                        isSelected: selectedChar == candidates[0],
                        isCenter: true
                    )
                    
                    // 右（い）
                    if candidates.count > 1 {
                        CandidateCharView(
                            char: candidates[1],
                            isSelected: selectedChar == candidates[1]
                        )
                    } else {
                        Spacer().frame(width: 24)
                    }
                }
                
                // 下（お）
                if candidates.count > 4 {
                    CandidateCharView(
                        char: candidates[4],
                        isSelected: selectedChar == candidates[4]
                    )
                } else {
                    Spacer().frame(height: 24)
                }
            }
        }
        .offset(y: -80) // キーの上に表示
    }
}

// MARK: - Candidate Character View
struct CandidateCharView: View {
    let char: String
    let isSelected: Bool
    let isCenter: Bool
    
    init(char: String, isSelected: Bool, isCenter: Bool = false) {
        self.char = char
        self.isSelected = isSelected
        self.isCenter = isCenter
    }
    
    var body: some View {
        Text(char)
            .font(.system(size: isCenter ? 22 : 18, weight: isSelected ? .bold : .medium))
            .foregroundColor(
                isSelected ?
                Color.white :
                (isCenter ? Color.black : Color(UIColor.systemGray))
            )
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
}

// MARK: - English Keyboard View
struct EnglishKeyboardView: View {
    let bleManager: BLEManager
    @State private var isShiftPressed = false
    @State private var isCtrlPressed = false
    @State private var isAltPressed = false
    
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
                    KeyButton(text: key, width: 35) {
                        sendModifiedKey(key)
                    }
                }
            }
            
            // アルファベット行
            ForEach(alphabetRows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { key in
                        KeyButton(text: key, width: 35) {
                            sendModifiedKey(key)
                        }
                    }
                }
            }
            
            // 修飾キー行
            HStack(spacing: 8) {
                Spacer()
                ModifierKeyButton(text: "Shift", isPressed: $isShiftPressed)
                ModifierKeyButton(text: "Ctrl", isPressed: $isCtrlPressed)
                ModifierKeyButton(text: "Alt", isPressed: $isAltPressed)
                Spacer()
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
    
    private func sendModifiedKey(_ key: String) {
        print("英数字キーボード入力: \(key), Shift: \(isShiftPressed), Ctrl: \(isCtrlPressed), Alt: \(isAltPressed)")
        
        // 文字の送信
        let ascii = (key.first?.asciiValue)!
        if isShiftPressed {
            bleManager.sendASCII(getShiftedASCII(ascii))
        } else if isCtrlPressed {
            bleManager.sendControlSequence(ctrl: true, key: ascii)
        } else {
            bleManager.sendASCII(ascii)
        }
        
        // 修飾キーをリセット（トグル動作）
        if isShiftPressed { isShiftPressed = false }
        if isCtrlPressed { isCtrlPressed = false }
        if isAltPressed { isAltPressed = false }
    }
    
    private func getShiftedASCII(_ ascii: UInt8) -> UInt8 {
        switch ascii {
        case 97...122: // a-z
            return ascii - 32 // A-Z
        case 49...57: // 1-9
            let shiftedNumbers: [UInt8] = [33, 64, 35, 36, 37, 94, 38, 42, 40] // !@#$%^&*(
            return shiftedNumbers[Int(ascii - 49)]
        case 48: // 0
            return 41 // )
        default:
            return ascii
        }
    }
}

// MARK: - Modifier Key Button
struct ModifierKeyButton: View {
    let text: String
    @Binding var isPressed: Bool
    
    var body: some View {
        Button(action: {
            isPressed.toggle()
        }) {
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .frame(width: 60, height: 50)
                .background(isPressed ? Color.blue.opacity(0.3) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                )
                .cornerRadius(6)
                .shadow(
                    color: Color.black.opacity(0.25),
                    radius: 2,
                    x: 0,
                    y: 2
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isPressed ? Color.blue : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
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
                        KeyButton(text: key, width: 35) {
                            bleManager.sendASCII(UInt8(key.unicodeScalars.first!.value))
                        }
                    }
                }
            }
            
            // 機能キー
            HStack(spacing: 8) {
                KeyButton(text: "Space", width: 180) {
                    bleManager.sendASCII(32) // Space
                }
                KeyButton(text: "Del", width: 70) {
                    bleManager.sendASCII(8) // Backspace
                }
                KeyButton(text: "Enter", width: 70) {
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
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.black)
                .frame(width: width, height: 50)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                )
                .cornerRadius(6)
                .shadow(
                    color: Color.black.opacity(0.25),
                    radius: 2,
                    x: 0,
                    y: 2
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView()
}
