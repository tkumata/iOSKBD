//
//  KeyboardViews.swift
//  BLEUSBKBD
//
//  Created by Tomokatsu Kumata on 2025/08/07.
//

import SwiftUI

// MARK: - Kana Keyboard View
struct KanaKeyboardView: View {
    let bleManager: BLEManager
    @State private var showModifierKeys = false
    @State private var lastInputChar = ""
    @State private var modifierKeyTimer: Timer?
    
    var body: some View {
        ZStack(alignment: .top) {
            // 通常のキーボード（常に同じ位置に固定）
            VStack(spacing: 12) {
                ForEach(KanaKeyboardLayout.kanaRows, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.self) { key in
                            IOSFlickKeyButton(
                                key: key,
                                flickChars: FlickInputSupport.getFlickCharacters(for: key),
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
            .padding(.top, showModifierKeys ? 60 : 0) // 修飾キーのスペースを確保
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemGray6))
            )
            .padding(.horizontal, 4)
            
            // 修飾キー行（絶対配置でオーバーレイ）
            if showModifierKeys {
                createModifierKeysRow()
            }
        }
    }
    
    /// 修飾キー行を作成
    @ViewBuilder
    private func createModifierKeysRow() -> some View {
        HStack(spacing: 8) {
            ForEach(FlickInputSupport.getAvailableModifiers(for: lastInputChar), id: \.self) { modifier in
                if let modifiedChar = FlickInputSupport.getModifiedCharacter(for: lastInputChar, modifier: modifier) {
                    ModifierCharButton(
                        char: modifiedChar,
                        label: modifier.displayLabel,
                        onTap: { char in
                            handleModifierKeyTap(char)
                        }
                    )
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Kana Keyboard View Private Methods
private extension KanaKeyboardView {
    
    /// キータップ処理
    func handleKeyTap(_ char: String) {
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
            print("数字キーボード切り替え")
        case "Aあ":
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
            let romaji = FlickInputSupport.convertToRomaji(char)
            if !romaji.isEmpty {
                bleManager.sendString(romaji)
                
                // 濁音・半濁音・小書き文字が可能な文字の場合、修飾キーを表示
                if FlickInputSupport.canShowModifierKeys(for: char) {
                    showModifierKeysFor(char)
                }
            }
        }
    }
    
    /// 修飾キータップ処理
    func handleModifierKeyTap(_ char: String) {
        print("修飾キー入力: \(char)")
        
        // 前の文字を削除（Backspace）
        bleManager.sendASCII(8)
        usleep(30000) // 30ms待機
        
        // 修飾後の文字を送信
        let romaji = FlickInputSupport.convertToRomaji(char)
        if !romaji.isEmpty {
            bleManager.sendString(romaji)
        }
        
        // 修飾キーを非表示
        hideModifierKeys()
    }
    
    /// 修飾キーを表示
    func showModifierKeysFor(_ char: String) {
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
    
    /// 修飾キーを非表示
    func hideModifierKeys() {
        modifierKeyTimer?.invalidate()
        withAnimation(.easeInOut(duration: 0.2)) {
            showModifierKeys = false
        }
        lastInputChar = ""
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
            createNumberRow()
            
            // アルファベット行
            ForEach(alphabetRows, id: \.self) { row in
                createAlphabetRow(row)
            }
            
            // 修飾キー行
            createModifierKeyRow()
            
            // 機能キー行
            createFunctionKeyRow()
        }
        .padding()
    }
    
    /// 数字行を作成
    @ViewBuilder
    private func createNumberRow() -> some View {
        HStack(spacing: 4) {
            ForEach(numberRow, id: \.self) { key in
                KeyButton(text: key, width: 32) {
                    sendModifiedKey(key)
                }
            }
        }
    }
    
    /// アルファベット行を作成
    @ViewBuilder
    private func createAlphabetRow(_ row: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(row, id: \.self) { key in
                KeyButton(text: key, width: 32) {
                    sendModifiedKey(key)
                }
            }
        }
    }
    
    /// 修飾キー行を作成
    @ViewBuilder
    private func createModifierKeyRow() -> some View {
        HStack(spacing: 8) {
            Spacer()
            ModifierKeyButton(text: "⇧ Shift", isPressed: $isShiftPressed)
            ModifierKeyButton(text: "^ Ctrl", isPressed: $isCtrlPressed)
            ModifierKeyButton(text: "⌥ ALT", isPressed: $isAltPressed)
            Spacer()
        }
    }
    
    /// 機能キー行を作成
    @ViewBuilder
    private func createFunctionKeyRow() -> some View {
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
}

// MARK: - English Keyboard View Private Methods
private extension EnglishKeyboardView {
    
    /// 修飾キーを適用してキーを送信
    func sendModifiedKey(_ key: String) {
        print("英数字キーボード入力: \(key), Shift: \(isShiftPressed), Ctrl: \(isCtrlPressed), Alt: \(isAltPressed)")
        
        // 文字の送信
        guard let ascii = key.first?.asciiValue else { return }
        
        if isShiftPressed {
            bleManager.sendASCII(getShiftedASCII(ascii))
        } else if isCtrlPressed {
            bleManager.sendControlSequence(ctrl: true, key: ascii)
        } else {
            bleManager.sendASCII(ascii)
        }
        
        // 修飾キーをリセット（トグル動作）
        resetModifierKeys()
    }
    
    /// 修飾キーをリセット
    func resetModifierKeys() {
        if isShiftPressed { isShiftPressed = false }
        if isCtrlPressed { isCtrlPressed = false }
        if isAltPressed { isAltPressed = false }
    }
    
    /// Shiftが押された時のASCII文字を取得
    func getShiftedASCII(_ ascii: UInt8) -> UInt8 {
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
            // 記号行
            ForEach(symbolRows, id: \.self) { row in
                createSymbolRow(row)
            }
            
            // 機能キー
            createFunctionKeys()
        }
        .padding()
    }
    
    /// 記号行を作成
    @ViewBuilder
    private func createSymbolRow(_ row: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(row, id: \.self) { key in
                KeyButton(text: key, width: 32) {
                    sendSymbol(key)
                }
            }
        }
    }
    
    /// 機能キーを作成
    @ViewBuilder
    private func createFunctionKeys() -> some View {
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
    
    /// 記号を送信
    private func sendSymbol(_ symbol: String) {
        guard let ascii = symbol.unicodeScalars.first?.value,
              ascii <= UInt8.max else { return }
        bleManager.sendASCII(UInt8(ascii))
    }
}