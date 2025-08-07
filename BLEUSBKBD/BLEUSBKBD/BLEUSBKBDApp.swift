//
//  BLEUSBKBDApp.swift
//  BLEUSBKBD
//
//  Created by Tomokatsu Kumata on 2025/08/02.
//  Refactored by Claude Code on 2025/08/07.
//

import SwiftUI

// MARK: - Main App
@main
struct FlickKeyboardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var currentKeyboard: KeyboardType = .kana
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 上部エリア（接続状態とキーボード切り替え）
                createHeaderArea()
                
                Spacer()
                
                // キーボード表示（画面下部固定）
                createKeyboardArea()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    /// ヘッダーエリアを作成
    @ViewBuilder
    private func createHeaderArea() -> some View {
        VStack(spacing: 0) {
            // 接続状態表示
            createConnectionStatusArea()
            
            // キーボード切り替えタブ
            createKeyboardSwitchTabs()
        }
    }
    
    /// 接続状態エリアを作成
    @ViewBuilder
    private func createConnectionStatusArea() -> some View {
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
                createDiscoveredDevicesList()
            }
        }
        .padding()
    }
    
    /// 発見済みデバイス一覧を作成
    @ViewBuilder
    private func createDiscoveredDevicesList() -> some View {
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
    
    /// キーボード切り替えタブを作成
    @ViewBuilder
    private func createKeyboardSwitchTabs() -> some View {
        HStack(spacing: 32) {
            Button("あ") { currentKeyboard = .kana }
                .foregroundColor(currentKeyboard == .kana ? .blue : .gray)
            Button("A") { currentKeyboard = .english }
                .foregroundColor(currentKeyboard == .english ? .blue : .gray)
            Button("#") { currentKeyboard = .symbol }
                .foregroundColor(currentKeyboard == .symbol ? .blue : .gray)
        }
        .padding()
    }
    
    /// キーボードエリアを作成
    @ViewBuilder
    private func createKeyboardArea() -> some View {
        VStack(spacing: 0) {
            switch currentKeyboard {
            case .kana:
                KanaKeyboardView(bleManager: bleManager)
            case .english:
                EnglishKeyboardView(bleManager: bleManager)
            case .symbol:
                SymbolKeyboardView(bleManager: bleManager)
            }
        }
    }
}

#Preview {
    ContentView()
}
