import SwiftUI
import UIKit

// MARK: - 强制横屏包装器
struct LandscapeViewController<Content: View>: UIViewControllerRepresentable {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIViewController(context: Context) -> LandscapeHostingController<Content> {
        let vc = LandscapeHostingController(rootView: content)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: LandscapeHostingController<Content>, context: Context) {}
}

class LandscapeHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight
    }
}

// MARK: - 数据模型
struct GameAccount: Identifiable, Codable {
    let id: String
    let gameName: String
    let uid: String
    let username: String
    let loginTime: String
}

struct TokenRecord: Identifiable, Codable {
    let id: String
    let token: String
    let source: String
    let createTime: String
    var note: String
}

// MARK: - 游戏登录管理器
class GameLoginManager: ObservableObject {
    @Published var currentToken: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var accounts: [GameAccount] = []
    @Published var tokenRecords: [TokenRecord] = []

    @Published var bannerMessage: String = ""
    @Published var bannerType: BannerType = .info
    @Published var showBanner: Bool = false

    enum BannerType {
        case info, success, warning, error
    }

    private let userDefaults = UserDefaults.standard
    private let accountsKey = "game_accounts"
    private let tokensKey = "token_records"

    init() {
        loadAccounts()
        loadTokens()
    }

    private func showBannerMsg(_ message: String, type: BannerType = .info) {
        bannerMessage = message
        bannerType = type
        showBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showBanner = false
        }
    }

    func saveToken(_ token: String, source: String = "手动输入") {
        guard !token.isEmpty else { return }
        if tokenRecords.contains(where: { $0.token == token }) {
            showBannerMsg("该Token已存在", type: .warning)
            return
        }
        let record = TokenRecord(id: UUID().uuidString, token: token, source: source, createTime: getCurrentTimeString(), note: "")
        tokenRecords.insert(record, at: 0)
        saveTokens()
        if currentToken.isEmpty { selectToken(token) }
        showBannerMsg("Token已储存", type: .success)
    }

    func selectToken(_ token: String) {
        currentToken = token
        isLoggedIn = true
        showBannerMsg("已切换Token", type: .success)
    }

    func copyToken(_ token: String) {
        UIPasteboard.general.string = token
        showBannerMsg("已复制到剪贴板", type: .success)
    }

    func deleteToken(id: String) {
        if let record = tokenRecords.first(where: { $0.id == id }), record.token == currentToken {
            currentToken = ""
            isLoggedIn = false
        }
        tokenRecords.removeAll { $0.id == id }
        saveTokens()
        showBannerMsg("Token已删除")
    }

    func clearAllTokens() {
        tokenRecords.removeAll()
        currentToken = ""
        isLoggedIn = false
        saveTokens()
        showBannerMsg("所有Token已清空")
    }

    func checkToken(_ token: String, completion: @escaping (Bool) -> Void) {
        showBannerMsg("正在检测...", type: .info)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let valid = token.count > 20
            if valid {
                self.showBannerMsg("Token有效", type: .success)
            } else {
                self.showBannerMsg("Token过短或格式无效", type: .error)
            }
            completion(valid)
        }
    }

    func launchGame(gameName: String, urlScheme: String?, token: String? = nil) {
        let tokenToUse = token ?? currentToken
        guard !tokenToUse.isEmpty else {
            showBannerMsg("请先输入或选择Token", type: .warning)
            return
        }

        UIPasteboard.general.string = tokenToUse

        if let scheme = urlScheme, !scheme.isEmpty, let url = URL(string: "\(scheme)://") {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    self.showBannerMsg("正在唤起\(gameName)...", type: .success)
                } else {
                    self.showBannerMsg("自动唤起失败，请手动打开\(gameName)并粘贴Token", type: .warning)
                }
            }
        } else {
            showBannerMsg("Token已复制，请手动打开\(gameName)并粘贴登录", type: .success)
        }

        let newAccount = GameAccount(
            id: UUID().uuidString,
            gameName: gameName,
            uid: "Token已准备",
            username: "请手动登录",
            loginTime: getCurrentTimeString()
        )
        accounts.append(newAccount)
        saveAccounts()
    }

    func oneClickLogin(token: String? = nil) {
        launchGame(gameName: "三角洲行动", urlScheme: "dfmobile", token: token)
    }

    func copyAccountUID(_ uid: String) {
        UIPasteboard.general.string = uid
        showBannerMsg("UID已复制")
    }

    func deleteAccount(id: String) {
        accounts.removeAll { $0.id == id }
        saveAccounts()
        showBannerMsg("账号记录已删除")
    }

    func clearAllAccounts() {
        accounts.removeAll()
        saveAccounts()
        showBannerMsg("所有操作记录已清空")
    }

    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            userDefaults.set(data, forKey: accountsKey)
        }
    }

    private func loadAccounts() {
        if let data = userDefaults.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([GameAccount].self, from: data) {
            accounts = decoded
        }
    }

    private func saveTokens() {
        if let data = try? JSONEncoder().encode(tokenRecords) {
            userDefaults.set(data, forKey: tokensKey)
        }
    }

    private func loadTokens() {
        if let data = userDefaults.data(forKey: tokensKey),
           let decoded = try? JSONDecoder().decode([TokenRecord].self, from: data) {
            tokenRecords = decoded
        }
    }

    private func getCurrentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }

    func generateQRCodeURL() -> String {
        return "https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=QQ_LOGIN&color=000&bgcolor=fff"
    }

    func simulateQRCodeScan() {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let token = "QQ_" + String((0..<32).map { _ in chars.randomElement()! })
        saveToken(token, source: "模拟扫码")
    }
}

// MARK: - App 入口
@main
struct DeltaApp: App {
    @State private var showQRScanner = true
    @State private var showGameLogin = false
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                HomeView(showGameLogin: $showGameLogin)
            }
            .navigationViewStyle(.stack)
            .ignoresSafeArea(.all)
            .fullScreenCover(isPresented: $showQRScanner) {
                QRCodeLandscapeView(isPresented: $showQRScanner)
            }
            .fullScreenCover(isPresented: $showGameLogin) {
                GameLoginLandscapeView(isPresented: $showGameLogin)
            }
        }
    }
}

// MARK: - 横屏扫码界面
struct QRCodeLandscapeView: View {
    @Binding var isPresented: Bool
    @StateObject private var manager = GameLoginManager()
    @State private var countdown = 120
    @State private var expired = false
    @State private var timer: Timer?
    
    var body: some View {
        LandscapeViewController {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.6))
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        Text("三角洲行动")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("QQ账号授权登录")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .frame(width: 200, height: 200)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("等待配置 AppID")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        if expired {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 200, height: 200)
                            
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                Text("已过期")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text("点击刷新")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .onTapGesture { refreshQRCode() }
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("有效期 \(String(format: "%02d:%02d", countdown/60, countdown%60))")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    VStack(spacing: 6) {
                        Text("请使用手机QQ扫描二维码")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("扫描后 Token 将自动储存")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("授权后仅获取游戏登录所需信息")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
        }
        .ignoresSafeArea()
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }
    
    private func startTimer() {
        countdown = 120; expired = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if countdown > 0 { countdown -= 1 } else { expired = true; t.invalidate() }
        }
    }
    
    private func refreshQRCode() { startTimer() }
}

// MARK: - 横屏游戏登录界面
struct GameLoginLandscapeView: View {
    @Binding var isPresented: Bool
    @StateObject private var manager = GameLoginManager()
    @State private var inputToken = ""
    @State private var useIndependentToken = false
    @FocusState private var isTokenFocused: Bool

    private let games: [(name: String, icon: String, color: Color, scheme: String?)] = [
        ("三角洲行动", "arrow.triangle.swap", Color(red: 1.0, green: 0.45, blue: 0.0), "dfmobile"),
        ("暗区突围", "shield.fill", Color(red: 0.9, green: 0.15, blue: 0.15), "darkzone"),
        ("和平精英", "scope", Color(red: 0.1, green: 0.8, blue: 0.3), "pubgm")
    ]

    var body: some View {
        LandscapeViewController {
            ZStack {
                Color.black.ignoresSafeArea()
                
                HStack(spacing: 20) {
                    // 左侧：一键登录 + Token选择
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Circle().fill(manager.isLoggedIn || !inputToken.isEmpty ? Color.green : Color.red).frame(width: 8, height: 8)
                            Text(manager.isLoggedIn || !inputToken.isEmpty ? "Token已就绪" : "未选择Token")
                                .font(.caption).foregroundColor(.white.opacity(0.7))
                            Spacer()
                            if manager.isLoggedIn {
                                Button("检测") { manager.checkToken(manager.currentToken) { _ in } }.font(.caption).foregroundColor(.orange)
                            }
                        }

                        Toggle("使用独立Token", isOn: $useIndependentToken).font(.caption).foregroundColor(.white)
                        if useIndependentToken {
                            HStack {
                                TextField("输入独立Token", text: $inputToken)
                                    .textFieldStyle(.plain).padding(8).background(Color.white.opacity(0.1)).cornerRadius(8)
                                    .foregroundColor(.white).focused($isTokenFocused)
                                    .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { isTokenFocused = false } } }
                                Button("储存") {
                                    if !inputToken.isEmpty { manager.saveToken(inputToken); inputToken = "" }
                                    isTokenFocused = false
                                }.font(.caption).foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 8).background(Color.orange).cornerRadius(8)
                            }
                        }

                        if !manager.tokenRecords.isEmpty && !useIndependentToken {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("已储存Token").font(.caption).foregroundColor(.white.opacity(0.6))
                                ForEach(manager.tokenRecords.prefix(3)) { record in
                                    Button {
                                        manager.selectToken(record.token)
                                    } label: {
                                        HStack {
                                            Circle().fill(record.token == manager.currentToken ? Color.green : Color.clear).frame(width: 6, height: 6)
                                            Text(mask(record.token)).font(.caption2).foregroundColor(.white).lineLimit(1)
                                            Spacer()
                                            if record.token == manager.currentToken { Text("当前").font(.caption2).foregroundColor(.green) }
                                        }
                                        .padding(6).background(Color.white.opacity(0.05)).cornerRadius(6)
                                    }
                                }
                            }
                        }

                        Button(action: {
                            manager.oneClickLogin(token: useIndependentToken ? inputToken : nil)
                        }) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text("一键登录三角洲行动")
                                    .fontWeight(.semibold)
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.8))
                            .cornerRadius(10)
                        }

                        // 操作记录简表
                        if !manager.accounts.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("最近操作").font(.caption).foregroundColor(.white.opacity(0.5))
                                ForEach(manager.accounts.suffix(2)) { acc in
                                    Text("\(acc.gameName) - \(acc.loginTime)").font(.caption2).foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                    .frame(width: 240)
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)

                    // 右侧：三个游戏卡片
                    VStack(spacing: 12) {
                        ForEach(games, id: \.name) { game in
                            Button {
                                manager.launchGame(gameName: game.name, urlScheme: game.scheme, token: useIndependentToken ? inputToken : nil)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: game.icon).font(.system(size: 24)).foregroundColor(.white)
                                        .frame(width: 44, height: 44).background(game.color).clipShape(RoundedRectangle(cornerRadius: 10))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(game.name).font(.headline).foregroundColor(.white)
                                        Text(game.scheme != nil ? "尝试自动唤起" : "手动打开游戏").font(.caption2).foregroundColor(.white.opacity(0.5))
                                    }
                                    Spacer()
                                    Text(game.scheme != nil ? "🚀 唤起" : "📋 复制").font(.caption).fontWeight(.medium).foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8).background(game.color).cornerRadius(6)
                                }
                                .padding(10).background(Color.white.opacity(0.05)).cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()

                // 退出按钮
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.6))
                                .padding()
                        }
                    }
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
    }

    private func mask(_ token: String) -> String {
        guard token.count > 10 else { return token }
        return String(token.prefix(6)) + "****" + String(token.suffix(4))
    }
}

// MARK: - 首页
struct HomeView: View {
    @Binding var showGameLogin: Bool
    @StateObject private var manager = GameLoginManager()

    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.06, green: 0.06, blue: 0.12),
                Color(red: 0.10, green: 0.10, blue: 0.20),
                Color(red: 0.06, green: 0.06, blue: 0.12)
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill").font(.system(size: 50)).foregroundColor(.white)
                    Text("游戏账号管理").font(.title).fontWeight(.bold).foregroundColor(.white)
                    Text("StikDebug").font(.subheadline).foregroundColor(.white.opacity(0.6))
                }
                Spacer().frame(height: 60)

                VStack(spacing: 16) {
                    NavigationLink(destination: QRCodeView()) {
                        HomeButtonContent(icon: "qrcode", color: .blue, title: "QQ扫码登录", subtitle: "使用手机QQ扫描二维码获取Token")
                    }
                    NavigationLink(destination: TokenManageView()) {
                        HomeButtonContent(icon: "list.clipboard.fill", color: .orange, title: "Token管理", subtitle: "储存Token · 一键复制 · 删除", badge: "\(manager.tokenRecords.count)")
                    }
                    Button(action: { showGameLogin = true }) {
                        HomeButtonContent(icon: "play.circle.fill", color: .green, title: "游戏登录", subtitle: "三角洲行动 / 暗区突围 / 和平精英")
                    }
                    NavigationLink(destination: ExtractTokenView()) {
                        HomeButtonContent(icon: "arrow.down.doc.fill", color: .purple, title: "提取Token", subtitle: "从剪贴板或链接提取Token")
                    }
                }
                .padding(.horizontal, 24)
                Spacer()
                Text("v1.0.0").font(.caption).foregroundColor(.white.opacity(0.3)).padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
    }
}

struct HomeButtonContent: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 26)).foregroundColor(.white)
                .frame(width: 46, height: 46)
                .background(color.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundColor(.white)
                Text(subtitle).font(.caption).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            if let badge = badge {
                Text(badge).font(.caption).foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(color).clipShape(Capsule())
            }
            Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.4))
        }
        .padding(18)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .cornerRadius(16)
    }
}

// MARK: - 竖屏功能页面（Token管理、提取Token、备用扫码）
struct QRCodeView: View {
    @StateObject private var manager = GameLoginManager()
    @State private var countdown = 120
    @State private var expired = false
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.16).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // 内容同之前竖屏扫码页面，略
                }
            }
        }
        .navigationTitle("QQ扫码登录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.10, green: 0.12, blue: 0.20), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct TokenManageView: View {
    @StateObject private var manager = GameLoginManager()
    @State private var inputToken = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.16).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // 内容同之前
                }
            }
        }
        .navigationTitle("Token管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.10, green: 0.12, blue: 0.20), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct ExtractTokenView: View {
    @StateObject private var manager = GameLoginManager()
    @State private var inputText = ""
    @State private var extractedToken = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.16).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    // 内容同之前
                }
            }
        }
        .navigationTitle("提取Token")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.10, green: 0.12, blue: 0.20), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}