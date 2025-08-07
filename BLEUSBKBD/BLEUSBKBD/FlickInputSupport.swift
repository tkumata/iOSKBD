//
//  FlickInputSupport.swift
//  BLEUSBKBD
//
//  Created by Tomokatsu Kumata on 2025/08/07.
//

import Foundation

/// フリック入力支援クラス
/// ひらがなとローマ字の変換、濁音・半濁音の処理を管理
class FlickInputSupport {
    
    // MARK: - Constants
    
    /// フリック対応の文字マップ（中央, 右, 上, 左, 下の順序）
    static let flickCharacterMap: [String: [String]] = [
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
        "、": ["、", "。", "ー", "？"]
    ]
    
    /// 濁音対応マップ
    static let dakutenMap: [String: String] = [
        "か": "が", "き": "ぎ", "く": "ぐ", "け": "げ", "こ": "ご",
        "さ": "ざ", "し": "じ", "す": "ず", "せ": "ぜ", "そ": "ぞ",
        "た": "だ", "ち": "ぢ", "つ": "づ", "て": "で", "と": "ど",
        "は": "ば", "ひ": "び", "ふ": "ぶ", "へ": "べ", "ほ": "ぼ"
    ]
    
    /// 半濁音対応マップ（は行のみ）
    static let handakutenMap: [String: String] = [
        "は": "ぱ", "ひ": "ぴ", "ふ": "ぷ", "へ": "ぺ", "ほ": "ぽ"
    ]
    
    /// 小書き文字対応マップ
    static let smallCharacterMap: [String: String] = [
        "あ": "ぁ", "い": "ぃ", "う": "ぅ", "え": "ぇ", "お": "ぉ",
        "や": "ゃ", "ゆ": "ゅ", "よ": "ょ",
        "つ": "っ", "わ": "ゎ"
    ]
    
    /// ひらがなからローマ字への変換マップ
    static let hiraganaToRomajiMap: [String: String] = [
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
    
    // MARK: - Public Methods
    
    /// ひらがなをローマ字に変換
    static func convertToRomaji(_ hiragana: String) -> String {
        return hiraganaToRomajiMap[hiragana] ?? hiragana
    }
    
    /// 指定文字の濁音を取得
    static func getDakutenCharacter(for char: String) -> String? {
        return dakutenMap[char]
    }
    
    /// 指定文字の半濁音を取得
    static func getHandakutenCharacter(for char: String) -> String? {
        return handakutenMap[char]
    }
    
    /// 指定文字の小書き文字を取得
    static func getSmallCharacter(for char: String) -> String? {
        return smallCharacterMap[char]
    }
    
    /// 指定文字に対するフリック文字配列を取得
    static func getFlickCharacters(for key: String) -> [String] {
        return flickCharacterMap[key] ?? [key]
    }
    
    /// 濁音・半濁音・小書き文字が可能かどうかを判定
    static func canShowModifierKeys(for char: String) -> Bool {
        return dakutenMap[char] != nil || 
               handakutenMap[char] != nil || 
               smallCharacterMap[char] != nil
    }
    
    /// 利用可能な修飾文字の種類を取得
    static func getAvailableModifiers(for char: String) -> [ModifierType] {
        var modifiers: [ModifierType] = []
        
        if dakutenMap[char] != nil {
            modifiers.append(.dakuten)
        }
        
        if handakutenMap[char] != nil {
            modifiers.append(.handakuten)
        }
        
        if smallCharacterMap[char] != nil {
            modifiers.append(.small)
        }
        
        return modifiers
    }
    
    /// 修飾タイプと文字から修飾後の文字を取得
    static func getModifiedCharacter(for char: String, modifier: ModifierType) -> String? {
        switch modifier {
        case .dakuten:
            return dakutenMap[char]
        case .handakuten:
            return handakutenMap[char]
        case .small:
            return smallCharacterMap[char]
        }
    }
}

// MARK: - ModifierType
/// 修飾文字の種類
enum ModifierType {
    case dakuten    // 濁音（゛）
    case handakuten // 半濁音（゜）
    case small      // 小書き文字
    
    /// 表示用ラベル
    var displayLabel: String {
        switch self {
        case .dakuten: return "゛"
        case .handakuten: return "゜"
        case .small: return "小"
        }
    }
}

// MARK: - Kana Keyboard Layout Helper
/// かなキーボードレイアウト支援クラス
class KanaKeyboardLayout {
    
    /// かなキーボードの行配列
    static let kanaRows = [
        ["あ", "か", "さ", "Del"],
        ["た", "な", "は", "Space"],
        ["ま", "や", "ら", "Enter"],
        ["わ", "、", "Aあ", "Enter"]
    ]
    
    /// 指定した文字がかなキーかどうかを判定
    static func isKanaKey(_ key: String) -> Bool {
        return FlickInputSupport.flickCharacterMap.keys.contains(key)
    }
    
    /// 指定した文字が特殊機能キーかどうかを判定
    static func isSpecialKey(_ key: String) -> Bool {
        let specialKeys = ["Del", "Space", "Enter", "Aあ", "123"]
        return specialKeys.contains(key)
    }
}