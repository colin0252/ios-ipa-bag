import SwiftUI
import CoreImage
import CryptoKit

// MARK: - 强制横屏
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.landscapeRight
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

// MARK: - 二维码生成器
struct QRGenerator {
    static let context = CIContext()
    static func createQRCode(text: String) -> UIImage {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return UIImage() }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return UIImage() }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 15, y: 15))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return UIImage() }
        return UIImage(cgImage: cg)
    }
}

// MARK: - 加密工具（保留）
struct CryptoHelper {
    private static let keyRaw = Data("IENNSJFJWKSFJ20260702".utf8)
    private static let nonceRaw = Data("1234567890123456".utf8)
    static func encrypt(_ text: String) -> String {
        let key = SymmetricKey(data: keyRaw)
        let nonce = try! AES.GCM.Nonce(data: nonceRaw)
        let box = try! AES.GCM.seal(Data(text.utf8), using: key, nonce: nonce)
        return box.combined!.base64EncodedString()
    }
    static func decrypt(_ base64Str: String) -> String {
        guard let combined = Data(base64Encoded: base64Str) else { return "" }
        let key = SymmetricKey(data: keyRaw)
        guard let box = try? AES.GCM.SealedBox(combined: combined),
              let data = try? AES.GCM.open(box, using: key) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - 账号模型（保留）
struct Account: Identifiable, Codable {
    let id: UUID
    let openid: String
    let seecoon_token: String
    let quid: String
    let refresh_token: String
    let createTime: Date
    init(openid: String, seecoon_token: String, quid: String, refresh_token: String) {
        self.id = UUID(); self.openid = openid; self.seecoon_token = seecoon_token
        self.quid = quid; self.refresh_token = refresh_token; self.createTime = Date()
    }
    enum CodingKeys: CodingKey { case id, openid, seecoon_token, quid, refresh_token, createTime }
}

// MARK: - 数据管理器（保留）
class DataManager: ObservableObject {
    @Published var accounts: [Account] = []
    var filePath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("delta.dat")
    }
    init() { loadAllAccounts() }
    func saveNewAccount(_ acc: Account) { accounts.append(acc); syncToDisk() }
    func deleteAccount(uuid: UUID) { accounts.removeAll { $0.id == uuid }; syncToDisk() }
    private func syncToDisk() {
        let json = try! JSONEncoder().encode(accounts)
        let enc = CryptoHelper.encrypt(json.base64EncodedString())
        try! enc.write(to: filePath, atomically: true, encoding: .utf8)
    }
    private func loadAllAccounts() {
        guard FileManager.default.fileExists(atPath: filePath.path) else { return }
        let cipher = try! String(contentsOf: filePath)
        let plain = CryptoHelper.decrypt(cipher)
        guard let data = Data(base64Encoded: plain) else { return }
        accounts = try! JSONDecoder().decode([Account].self, from: data)
    }
}

// MARK: - 页面路由
enum AppPage { case home, qrCodePage, accountList, tokenCheck }

// MARK: - 扫码获取 Token 页面（显示固定二维码）
struct QRCodePage: View {
    @EnvironmentObject var manager: DataManager
    @Binding var currentPage: AppPage
    @State private var qrImage: UIImage? = nil
    
    // 三角洲游戏官方登录页 URL（如果 seecoon 有这个页面，请换成正确的地址）
    let loginURL = "https://game.seecoon.com/login"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 30) {
                HStack {
                    Button("返回") { currentPage = .home }.foregroundColor(.blue)
                    Spacer()
                }.padding()
                
                if let qrImage = qrImage {
                    Image(uiImage: qrImage)
                        .resizable().scaledToFit().frame(width: 250, height: 250)
                    Text("用 QQ 扫此二维码，登录后复制页面显示的 token")
                        .foregroundColor(.white).multilineTextAlignment(.center)
                } else {
                    ProgressView("生成二维码中...")
                }
                
                // 输入框：用户粘贴 token
                TextField("在这里粘贴获取到的 token", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .disabled(true)  // 仅展示，实际使用请改为 @State var
                
                // 由于需要状态管理，完整功能请复制下方“改进版”
            }
        }
        .onAppear {
            qrImage = QRGenerator.createQRCode(text: loginURL)
        }
    }
}

// 实际使用时，请将 QRCodePage 替换为下面的完整可用版本（包含粘贴保存功能）

// MARK: - 完整扫码页（包含输入框和保存按钮）
struct QRCodePageFinal: View {
    @EnvironmentObject var manager: DataManager
    @Binding var currentPage: AppPage
    @State private var qrImage: UIImage? = nil
    @State private var tokenInput = ""
    @State private var savedMessage = ""
    
    let loginURL = "https://game.seecoon.com/login"  // ← 如果知道准确地址，请替换
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 25) {
                HStack {
                    Button("返回") { currentPage = .home }.foregroundColor(.blue)
                    Spacer()
                }.padding()
                
                if let qrImage = qrImage {
                    Image(uiImage: qrImage)
                        .resizable().scaledToFit().frame(width: 250, height: 250)
                    Text("用 QQ 扫此二维码，登录后复制页面上显示的 token")
                        .foregroundColor(.white).multilineTextAlignment(.center)
                }
                
                TextField("在此粘贴 token", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                Button("保存 token 到账号库存") {
                    if !tokenInput.isEmpty {
                        // 此处仅保存 token，openid、quid 等需要实际解析或手动输入
                        // 简化：只保存 token 作为 seecoon_token，其他为空
                        let acc = Account(openid: "手动导入", seecoon_token: tokenInput, quid: "", refresh_token: "")
                        manager.saveNewAccount(acc)
                        savedMessage = "已保存！"
                        tokenInput = ""
                    }
                }
                .font(.title2).padding().background(Color.green).foregroundColor(.white).cornerRadius(14)
                
                if !savedMessage.isEmpty {
                    Text(savedMessage).foregroundColor(.green)
                }
            }
        }
        .onAppear {
            qrImage = QRGenerator.createQRCode(text: loginURL)
        }
    }
}

// 其他页面（账号库存、Token校验与上号）与之前相同，为节省篇幅此处省略，但你需要保留它们。

// 程序入口
@main
struct DeltaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var manager = DataManager()
    @State var currentPage: AppPage = .home
    
    var body: some Scene {
        WindowGroup {
            if #available(iOS 16.4, *) {
                switch currentPage {
                case .home:
                    // 简单首页
                    ZStack {
                        Color.black.ignoresSafeArea()
                        VStack(spacing: 35) {
                            Button("获取 token（扫二维码）") { currentPage = .qrCodePage }
                                .font(.title2).padding().background(Color.orange).foregroundColor(.white).cornerRadius(14)
                            Button("账号库存") { currentPage = .accountList }
                                .font(.title2).padding().background(Color.green).foregroundColor(.white).cornerRadius(14)
                            Button("Token 校验 + 上号") { currentPage = .tokenCheck }
                                .font(.title2).padding().background(Color.blue).foregroundColor(.white).cornerRadius(14)
                        }
                    }
                case .qrCodePage:
                    QRCodePageFinal(currentPage: $currentPage).environmentObject(manager)
                case .accountList:
                    // 账号库存页（需实现，可复用之前 PageB）
                    Text("账号库存") // 临时
                case .tokenCheck:
                    // Token 校验页（需实现，可复用之前 PageC）
                    Text("Token 校验") // 临时
                }
            }
        }
    }
}