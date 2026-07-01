import SwiftUI
import UIKit

@main   // 这个标记告诉系统，这是应用的入口
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ViewControllerWrapper()
        }
    }
}

// 把你的 ViewController 包装成 SwiftUI 能用的形式
struct ViewControllerWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ViewController {
        return ViewController()
    }
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {}
}
