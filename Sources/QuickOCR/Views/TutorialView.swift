import SwiftUI

struct TutorialView: View {
    @State private var currentPage = 0
    var onFinish: () -> Void
    
    var body: some View {
        VStack {
            Group {
                if currentPage == 0 {
                    tutorialPage(
                        image: "keyboard",
                        title: "ショートカットキー",
                        message: "⌘ + ⇧ + O を押して\nOCRモードを開始します"
                    )
                    .transition(.opacity)
                } else if currentPage == 1 {
                    tutorialPage(
                        image: "viewfinder",
                        title: "範囲を選択",
                        message: "画面上の文字を認識したい範囲を\nマウスドラッグで囲みます"
                    )
                    .transition(.opacity)
                } else {
                    tutorialPage(
                        image: "doc.on.clipboard",
                        title: "自動コピー",
                        message: "認識されたテキストが\nクリップボードに自動でコピーされます"
                    )
                    .transition(.opacity)
                }
            }

            HStack {
                if currentPage < 2 {
                    Button("次へ") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                } else {
                    Button("完了") {
                        onFinish()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.bottom, 20)
        }
        .frame(width: 500, height: 400)
    }
    
    private func tutorialPage(image: String, title: String, message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: image)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .padding()
            
            Text(title)
                .font(.title)
                .bold()
            
            Text(message)
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
