import SwiftUI
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @State private var inputText = "https://www.apple.com"
    @State private var qrImage: UIImage? = nil
    
    // 二维码生成器
    private let qrFilter = CIFilter.qrCodeGenerator()
    // 用于将 CIImage 渲染为位图
    private let context = CIContext()
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("输入文本或网址", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button("生成二维码") {
                generateQRCode(from: inputText)
            }
            .buttonStyle(.borderedProminent)
            
            if let qrImage = qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)   // 防止模糊，保持像素清晰
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(radius: 4)
            } else {
                Text("请输入内容并生成二维码")
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.top, 40)
    }
    
    func generateQRCode(from string: String) {
        // 1. 将输入转换为 Data，使用 UTF-8 编码以支持中文等字符
        let data = Data(string.utf8)
        
        // 2. 设置二维码参数
        qrFilter.message = data
        qrFilter.correctionLevel = "H"   // 高纠错率（L M Q H），便于 QQ 扫描
        
        // 3. 获取生成的 CIImage，并放大到合适尺寸
        guard let ciImage = qrFilter.outputImage else {
            qrImage = nil
            return
        }
        
        // 原生图像只有 27x27 左右，需要放大
        let scaleX = 250.0 / ciImage.extent.size.width
        let scaleY = 250.0 / ciImage.extent.size.height
        let transformedImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // 4. 将 CIImage 渲染为 CGImage，再生成 UIImage
        if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
            qrImage = UIImage(cgImage: cgImage)
        } else {
            qrImage = nil
        }
    }
}

@main
struct QRCodeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}