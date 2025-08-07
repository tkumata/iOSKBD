//
//  KeyboardTypes.swift
//  BLEUSBKBD
//
//  Created by Tomokatsu Kumata on 2025/08/07.
//

import Foundation

/// キーボードの種類を表す列挙型
enum KeyboardType {
    case kana      // かなキーボード
    case english   // 英数字キーボード
    case symbol    // 記号キーボード
}

/// キーボード入力プロトコル
/// 各キーボードが実装すべき共通インターフェース
protocol KeyboardInputProtocol {
    func handleKeyInput(_ input: String)
    func handleSpecialKey(_ key: SpecialKey)
}

/// 特殊キーの種類
enum SpecialKey: String, CaseIterable {
    case space = "Space"
    case delete = "Del"
    case enter = "Enter"
    case shift = "Shift"
    case ctrl = "Ctrl"
    case alt = "Alt"
    case escape = "ESC"
    case tab = "Tab"
    case switchToEnglish = "Aあ"
    case numbers = "123"
    
    /// 表示用テキストを取得
    var displayText: String {
        switch self {
        case .space: return "空白"
        case .delete: return "削除"
        case .enter: return "改行"
        case .shift: return "⇧ Shift"
        case .ctrl: return "^ Ctrl"
        case .alt: return "⌥ ALT"
        case .escape: return "ESC"
        case .tab: return "Tab"
        case .switchToEnglish: return "英/あ"
        case .numbers: return "123"
        }
    }
    
    /// ASCII コードを取得（該当する場合）
    var asciiCode: UInt8? {
        switch self {
        case .space: return 32
        case .delete: return 8
        case .enter: return 13
        case .escape: return 27
        case .tab: return 9
        default: return nil
        }
    }
}

/// フリック方向を表す列挙型
enum FlickDirection: Int, CaseIterable {
    case center = 0  // 中央（タップ）
    case right = 1   // 右フリック
    case up = 2      // 上フリック
    case left = 3    // 左フリック
    case down = 4    // 下フリック
    
    /// 方向の説明
    var description: String {
        switch self {
        case .center: return "中央"
        case .right: return "右"
        case .up: return "上"
        case .left: return "左"
        case .down: return "下"
        }
    }
}