import SwiftUI

struct WelcomeView: View {
    enum Step {
        case welcome
        case permission
        case tutorial
    }
    
    @State private var currentStep: Step = .welcome
    @State private var hasAccessibilityPermission = AXIsProcessTrusted()
    
    var onFinish: () -> Void
    
    var body: some View {
        Group {
            switch currentStep {
            case .welcome:
                welcomeContent
            case .permission:
                permissionContent
            case .tutorial:
                TutorialView(onFinish: onFinish)
            }
        }
    }
    
    // MARK: - Welcome
    
    private var welcomeContent: some View {
        VStack(spacing: 30) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 12) {
                Text("QuickOCRへようこそ")
                    .font(.largeTitle)
                    .bold()
                
                Text("画面の一部をキャプチャして瞬時にテキスト化。\nクリップボードに自動保存します。")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                Text("デフォルトショートカット")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    KeyView("⌘")
                    KeyView("⇧")
                    KeyView("O")
                }
            }
            
            Button("開始する") {
                checkPermissionAndProceed()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .frame(width: 500, height: 400)
    }
    
    private func checkPermissionAndProceed() {
        if AXIsProcessTrusted() {
            currentStep = .tutorial
        } else {
            currentStep = .permission
        }
    }
    
    // MARK: - Permission
    
    private var permissionContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("権限が必要です")
                    .font(.title)
                    .bold()
                
                Text("ショートカットキーを機能させるために、\nアクセシビリティの権限が必要です。")
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("1.")
                    Text("「システム設定を開く」をクリック")
                }
                HStack {
                    Text("2.")
                    Text("プライバシーとセキュリティ > アクセシビリティ")
                }
                HStack {
                    Text("3.")
                    Text("QuickOCRのスイッチをONにする")
                }
            }
            .font(.callout)
            .foregroundColor(.secondary)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
            HStack(spacing: 20) {
                Button("システム設定を開く") {
                    let url = URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefpane")
                    NSWorkspace.shared.open(url)
                }
                
                Button("許可しました") {
                    if AXIsProcessTrusted() {
                        currentStep = .tutorial
                        hasAccessibilityPermission = true
                    } else {
                        // Polling or just re-check effectively
                        // For UX, maybe show alert if still not trusted
                        let alert = NSAlert()
                        alert.messageText = "権限が確認できません"
                        alert.informativeText = "設定で許可してから再度ボタンを押してください。"
                        alert.runModal()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            
            Text("画面収録の権限は、初回実行時にmacOSから求められます。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(width: 500, height: 400)
    }
}

private struct KeyView: View {
    let char: String
    
    init(_ char: String) {
        self.char = char
    }
    
    var body: some View {
        Text(char)
            .font(.headline)
            .frame(width: 32, height: 32)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
    }
}
