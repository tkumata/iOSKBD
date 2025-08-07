//
//  BLEManager.swift
//  BLEUSBKBD
//
//  Created by Tomokatsu Kumata on 2025/08/07.
//

import Foundation
import CoreBluetooth
import SwiftUI

/// BLE接続状態を表すプロトコル
protocol BLEConnectionDelegate: AnyObject {
    func didUpdateConnectionStatus(_ status: String)
    func didConnect()
    func didDisconnect()
}

/// BLE通信管理クラス
/// Arduino Nano ESP32との通信を管理する
class BLEManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var connectionStatus = "未接続"
    @Published var discoveredDevices: [String] = []
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var isScanning = false
    
    // MARK: - Constants
    private struct Constants {
        static let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
        static let characteristicUUID = CBUUID(string: "87654321-4321-4321-4321-CBA987654321")
        static let genericServiceUUID = CBUUID(string: "FFE0") // よく使われるUUID
        static let scanTimeout: Double = 30.0
        static let reconnectDelay: Double = 2.0
        static let sendDelay: useconds_t = 50000 // 50ms
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    /// スキャンを開始
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth not ready")
            return
        }
        
        stopScanningIfNeeded()
        updateConnectionStatus("全デバイススキャン中...")
        clearDiscoveredDevices()
        
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        isScanning = true
        
        scheduleStopScanning()
        print("Started scanning for all BLE devices")
    }
    
    /// スキャンを停止
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        updateConnectionStatus(connectionStatus + " (スキャン停止)")
    }
    
    /// 指定名のデバイスに接続を試行
    func connectToDevice(named deviceName: String) {
        // 発見済みデバイスから接続を試行
        // 実際の実装では、発見したペリフェラルを保存しておく必要があります
        print("接続試行: \(deviceName)")
    }
    
    /// ASCII文字を送信
    func sendASCII(_ ascii: UInt8) {
        guard let characteristic = characteristic,
              let peripheral = peripheral else {
            print("送信エラー: 特性またはペリフェラルが無効")
            return
        }
        
        let data = Data([ascii])
        print("送信データ: \(ascii) (文字: \(Character(UnicodeScalar(ascii))))")
        
        sendData(data, to: characteristic, via: peripheral)
    }
    
    /// 文字列を送信
    func sendString(_ string: String) {
        guard isConnected else {
            print("送信エラー: 未接続")
            return
        }
        
        print("文字列送信: \(string)")
        for char in string {
            if let ascii = char.asciiValue {
                sendASCII(ascii)
                usleep(Constants.sendDelay)
            }
        }
    }
    
    /// 制御シーケンスを送信
    func sendControlSequence(ctrl: Bool, key: UInt8) {
        guard isConnected else {
            print("送信エラー: 未接続")
            return
        }
        
        print("制御シーケンス送信 - Ctrl: \(ctrl), Key: \(key)")
        
        if ctrl {
            let ctrlKey = key >= 96 ? key - 96 : key
            sendASCII(ctrlKey)
        } else {
            sendASCII(key)
        }
    }
    
    /// テストメッセージを送信
    func sendTestMessage() {
        print("テストメッセージを送信します")
        sendASCII(65) // 'A'
    }
}

// MARK: - Private Methods
private extension BLEManager {
    
    /// スキャンが実行中の場合は停止
    func stopScanningIfNeeded() {
        if isScanning {
            centralManager.stopScan()
        }
    }
    
    /// 接続状態を更新（メインスレッド）
    func updateConnectionStatus(_ status: String) {
        DispatchQueue.main.async {
            self.connectionStatus = status
        }
    }
    
    /// 発見済みデバイスリストをクリア
    func clearDiscoveredDevices() {
        DispatchQueue.main.async {
            self.discoveredDevices.removeAll()
        }
    }
    
    /// スキャン自動停止をスケジュール
    func scheduleStopScanning() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.scanTimeout) {
            if self.isScanning {
                self.stopScanning()
            }
        }
    }
    
    /// データ送信の実行
    func sendData(_ data: Data, to characteristic: CBCharacteristic, via peripheral: CBPeripheral) {
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
    
    /// Arduino ESP32らしいデバイスかどうかを判定
    func isArduinoDevice(_ deviceName: String) -> Bool {
        let lowercaseName = deviceName.lowercased()
        return lowercaseName.contains("arduino") ||
               lowercaseName.contains("esp32") ||
               lowercaseName.contains("nano")
    }
    
    /// デバイス情報文字列を生成
    func createDeviceInfo(name: String, rssi: NSNumber) -> String {
        return "\(name) (\(rssi)dBm)"
    }
    
    /// 自動再接続を開始
    func scheduleReconnection() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.reconnectDelay) {
            self.startScanning()
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    
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
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "名前なし"
        let identifier = peripheral.identifier.uuidString
        
        print("発見したデバイス: \(deviceName), RSSI: \(RSSI), ID: \(identifier)")
        
        // 発見したデバイスをリストに追加
        DispatchQueue.main.async {
            let deviceInfo = self.createDeviceInfo(name: deviceName, rssi: RSSI)
            if !self.discoveredDevices.contains(deviceInfo) {
                self.discoveredDevices.append(deviceInfo)
            }
        }
        
        // Arduino ESP32らしいデバイスで自動接続を試行
        if isArduinoDevice(deviceName) {
            print("Arduino ESP32らしいデバイスを発見: \(deviceName)")
            attemptConnection(to: peripheral, named: deviceName)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("デバイスに接続成功: \(peripheral.name ?? "Unknown")")
        updateConnectionStatus("サービス検索中...")
        
        // 全てのサービスを検索（デバッグ用）
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "切断されました"
        }
        
        // 自動再接続
        scheduleReconnection()
    }
    
    /// デバイスへの接続を試行
    private func attemptConnection(to peripheral: CBPeripheral, named deviceName: String) {
        self.peripheral = peripheral
        peripheral.delegate = self
        centralManager.stopScan()
        isScanning = false
        
        updateConnectionStatus("接続中: \(deviceName)")
        centralManager.connect(peripheral, options: nil)
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    
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
                handleWritableCharacteristic(characteristic)
                return
            }
        }
        
        // 書き込み可能な特性が見つからない場合
        if self.characteristic == nil {
            print("書き込み可能な特性が見つかりません")
            updateConnectionStatus("特性エラー: 書き込み不可")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("書き込みエラー: \(error)")
        } else {
            print("書き込み成功: \(characteristic.uuid)")
        }
    }
    
    /// 書き込み可能な特性が見つかった時の処理
    private func handleWritableCharacteristic(_ characteristic: CBCharacteristic) {
        print("書き込み可能な特性を発見: \(characteristic.uuid)")
        self.characteristic = characteristic
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "接続済み (特性: \(characteristic.uuid.uuidString.prefix(8)))"
        }
    }
}