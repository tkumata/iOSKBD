//
//  KeyboardComponents.swift
//  BLEUSBKBD
//
//  Created by Tomokatsu Kumata on 2025/08/07.
//

import SwiftUI

// MARK: - 基本的なキーボタン
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

// MARK: - 修飾キーボタン（Shift、Ctrl、Alt等）
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
                .frame(width: 100, height: 50)
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

// MARK: - 修飾文字ボタン（濁音・半濁音・小書き文字）
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

// MARK: - フリック候補表示オーバーレイ
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
                createCandidateIfAvailable(at: 2)
                
                HStack(spacing: 12) {
                    // 左（え）
                    createCandidateIfAvailable(at: 3)
                    
                    // 中央（あ）
                    CandidateCharView(
                        char: candidates[0],
                        isSelected: selectedChar == candidates[0],
                        isCenter: true
                    )
                    
                    // 右（い）
                    createCandidateIfAvailable(at: 1)
                }
                
                // 下（お）
                createCandidateIfAvailable(at: 4)
            }
        }
        .offset(y: -80) // キーの上に表示
    }
    
    /// 指定されたインデックスの候補文字があれば表示、なければスペーサーを表示
    @ViewBuilder
    private func createCandidateIfAvailable(at index: Int) -> some View {
        if candidates.count > index {
            CandidateCharView(
                char: candidates[index],
                isSelected: selectedChar == candidates[index]
            )
        } else {
            Spacer().frame(width: 24, height: 24)
        }
    }
}

// MARK: - 候補文字表示ビュー
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

// MARK: - iOSスタイルのフリックキーボタン（かなキーボード専用）
struct IOSFlickKeyButton: View {
    let key: String
    let flickChars: [String]
    let onTap: (String) -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var selectedChar = ""
    @State private var isDragging = false
    @State private var hasTriggered = false
    @State private var isPressed = false
    
    /// 特殊キーかどうかを判定
    private var isSpecialKey: Bool {
        return !["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ", "ん", "、", "。"].contains(key)
    }
    
    /// キーの幅を取得
    private var keyWidth: CGFloat {
        switch key {
        case "Space", "Del", "123", "Aあ", "Enter":
            return 70
        default:
            return 70
        }
    }
    
    var body: some View {
        ZStack {
            // キーの背景
            createKeyBackground()
            
            // キーのテキスト
            createKeyText()
            
            // フリック候補表示オーバーレイ
            if shouldShowCandidates {
                FlickCandidatesOverlay(
                    candidates: flickChars,
                    selectedChar: selectedChar
                )
            }
        }
        .scaleEffect(isPressed ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .gesture(createDragGesture())
    }
    
    /// フリック候補を表示すべきかどうか
    private var shouldShowCandidates: Bool {
        return !selectedChar.isEmpty && flickChars.count > 1 && isDragging
    }
}

// MARK: - IOSFlickKeyButton Private Methods
private extension IOSFlickKeyButton {
    
    /// キーの背景を作成
    @ViewBuilder
    func createKeyBackground() -> some View {
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
    }
    
    /// キーのテキストを作成
    @ViewBuilder
    func createKeyText() -> some View {
        Text(selectedChar.isEmpty ? getDisplayText(key) : selectedChar)
            .font(.system(size: getFontSize(key), weight: .medium))
            .foregroundColor(isSpecialKey ? Color(UIColor.systemGray) : Color.black)
    }
    
    /// ドラッグジェスチャーを作成
    func createDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { value in
                handleDragEnded(value)
            }
    }
    
    /// ドラッグ変化時の処理
    func handleDragChanged(_ value: DragGesture.Value) {
        guard !hasTriggered else { return }
        
        if !isPressed {
            isPressed = true
            // タプティックフィードバック
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        dragOffset = value.translation
        let distance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
        
        if distance > 15 && flickChars.count > 1 {
            // フリック入力として処理
            isDragging = true
            let newSelectedChar = getFlickChar(for: dragOffset)
            if selectedChar != newSelectedChar {
                selectedChar = newSelectedChar
                // フリック時のフィードバック
                let selectionFeedback = UISelectionFeedbackGenerator()
                selectionFeedback.selectionChanged()
            }
        } else {
            // 短い距離の場合は中央文字を選択
            if selectedChar != flickChars[0] {
                selectedChar = flickChars[0]
            }
        }
    }
    
    /// ドラッグ終了時の処理
    func handleDragEnded(_ value: DragGesture.Value) {
        guard !hasTriggered else { return }
        
        hasTriggered = true
        isPressed = false
        
        let distance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
        
        if distance <= 15 {
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
        resetState()
    }
    
    /// 状態をリセット
    func resetState() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            selectedChar = ""
            dragOffset = .zero
            isDragging = false
            hasTriggered = false
        }
    }
    
    /// 表示テキストを取得
    func getDisplayText(_ key: String) -> String {
        switch key {
        case "Space": return "空白"
        case "Del": return "削除"
        case "Enter": return "改行"
        case "Aあ": return "英/あ"
        case "123": return "123"
        default: return key
        }
    }
    
    /// フォントサイズを取得
    func getFontSize(_ key: String) -> CGFloat {
        switch key {
        case "Space", "Del", "Enter", "Aあ", "123":
            return 16
        default:
            return 22
        }
    }
    
    /// フリック方向から文字を取得
    func getFlickChar(for offset: CGSize) -> String {
        guard flickChars.count > 1 else { return key }
        
        let threshold: CGFloat = 15
        
        // 優先度による方向判定
        let absWidth = abs(offset.width)
        let absHeight = abs(offset.height)
        
        // 中央判定（閾値未満）
        if absWidth < threshold && absHeight < threshold {
            return flickChars[0] // 中央
        }
        
        // 方向判定（より大きな移動量を優先）
        if absHeight > absWidth {
            // 縦方向が優勢
            if offset.height < 0 {
                return flickChars.count > 2 ? flickChars[2] : flickChars[0] // 上
            } else {
                return flickChars.count > 4 ? flickChars[4] : flickChars[0] // 下
            }
        } else {
            // 横方向が優勢
            if offset.width > 0 {
                return flickChars.count > 1 ? flickChars[1] : flickChars[0] // 右
            } else {
                return flickChars.count > 3 ? flickChars[3] : flickChars[0] // 左
            }
        }
    }
}