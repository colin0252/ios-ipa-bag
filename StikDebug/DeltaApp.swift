import SwiftUI

// MARK: - 数据模型
struct GameAccount: Identifiable, Codable {
    let id: String
    let gameName: String
    let uid: String
    let username: String
    let loginTime: String
}

// MARK: - 游戏登录管理器
class GameLoginManager: ObservableObject {
    @Published var currentToken: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var accounts: [GameAccount] = []
    @Published var message: String = ""
    @Published var messageType: MessageType = .info
    
    enum MessageType {
        case info, success, warning, error
    }
    
    private let userDefaults = UserDefaults.standard
    private let accountsKey = "game_accounts"
    
    init() {
        loadAccounts()
    }
    
    func setToken(_ token: String) {
        currentToken = token
        isLoggedIn = true
        showMessage("Token已设置", type: .success)
    }
    
    func copyToken() {
        guard !currentToken.isEmpty else {
            showMessage("请先获取Token", type: .warning)
            return
        }
        UIPasteboard.general.string = currentToken
        showMessage("Token已复制到剪贴板", type: .success)
    }
    
    func manualTokenInput(_ token: String) {
        if token.isEmpty {
            showMessage("请输入Token", type: .warning)
            return
        }
        setToken(token)
    }
    
    func loginGame(gameName: String, gameCode: String) {
        guard !currentToken.isEmpty else {
            showMessage("请先获取Token", type: .warning)
            return
        }
        
        showMessage("正在登录\(gameName)...", type: .info)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            let newAccount = GameAccount(
                id: UUID().uuidString,
                gameName: gameName,
                uid: "\(Int.random(in: 100000000...999999999))",
                username: "Player_\(Int.random(in: 1000...9999))",
                loginTime: self.getCurrentTimeString()
            )
            
            self.accounts.append(newAccount)
            self.saveAccounts()
            self.showMessage("\(gameName)登录成功！", type: .success)
        }
    }
    
    func copyAccountUID(_ uid: String) {
        UIPasteboard.general.string = uid
        showMessage("UID已复制到剪贴板", type: .success)
    }
    
    func deleteAccount(id: String) {
        accounts.removeAll { $0.id == id }
        saveAccounts()
        showMessage("账号已删除", type: .info)
    }
    
    func clearAllAccounts() {
        accounts.removeAll()
        saveAccounts()
        showMessage("所有账号已清空", type: .info)
    }
    
    private func saveAccounts() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            userDefaults.set(encoded, forKey: accountsKey)
        }
    }
    
    private func loadAccounts() {
        if let data = userDefaults.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([GameAccount].self, from: data) {
            accounts = decoded
        }
    }
    
    private func showMessage(_ text: String, type: MessageType) {
        message = text
        messageType = type
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.message = ""
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
}

// MARK: - App入口
@main
struct DeltaApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .ignoresSafeArea(.all)
        }
    }
}

// MARK: - 主页面（三个大按钮）
struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            if selectedTab == 0 {
                HomeView(selectedTab: $selectedTab)
            } else if selectedTab == 1 {
                QRCodeView(selectedTab: $selectedTab)
            } else if selectedTab == 2 {
                TokenManageView(selectedTab: $selectedTab)
            } else if selectedTab == 3 {
                GameLoginView(selectedTab: $selectedTab)
            }
        }
    }
}

// MARK: - 首页
struct HomeView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12),
                    Color(red: 0.10, green: 0.10, blue: 0.20),
                    Color(red: 0.06, green: 0.06, blue: 0.12)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo区域
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    
                    Text("游戏账号管理")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("StikDebug")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer().frame(height: 60)
                
                // 三个大按钮
                VStack(spacing: 20) {
                    // QQ二维码
                    Button(action: { selectedTab = 1 }) {
                        HStack(spacing: 16) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.blue.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("QQ扫码登录")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("使用手机QQ扫描二维码授权登录")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .cornerRadius(16)
                    }
                    
                    // Token管理
                    Button(action: { selectedTab = 2 }) {
                        HStack(spacing: 16) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.orange.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Token管理")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("手动输入Token，复制和管理令牌")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .cornerRadius(16)
                    }
                    
                    // 游戏登录
                    Button(action: { selectedTab = 3 }) {
                        HStack(spacing: 16) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.green.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("游戏登录")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("三角洲行动 / 暗区突围 / 和平精英")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // 底部版本信息
                Text("v1.0.0")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - QQ扫码页面（模仿三角洲行动）
struct QRCodeView: View {
    @Binding var selectedTab: Int
    @StateObject private var loginManager = GameLoginManager()
    @State private var qrCodeTimer: Timer?
    @State private var countdown = 120
    @State private var qrCodeExpired = false
    
    var body: some View {
        ZStack {
            // 背景
            Color(red: 0.08, green: 0.10, blue: 0.16)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    Button(action: { selectedTab = 0 }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("QQ扫码登录")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // 占位保持居中
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(Color(red: 0.10, green: 0.12, blue: 0.20))
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 游戏图标
                        VStack(spacing: 12) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            
                            Text("三角洲行动")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("QQ账号授权登录")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.top, 40)
                        
                        // 二维码卡片
                        VStack(spacing: 20) {
                            ZStack {
                                // 白色背景
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white)
                                    .frame(width: 240, height: 240)
                                
                                // 二维码
                                AsyncImage(url: URL(string: loginManager.generateQRCodeURL())) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200, height: 200)
                                } placeholder: {
                                    VStack(spacing: 12) {
                                        Image(systemName: "qrcode")
                                            .font(.system(size: 80))
                                            .foregroundColor(.black)
                                        Text("加载中...")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                // 过期蒙层
                                if qrCodeExpired {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.black.opacity(0.7))
                                        .frame(width: 240, height: 240)
                                    
                                    VStack(spacing: 12) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 40))
                                            .foregroundColor(.white)
                                        Text("二维码已过期")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("点击刷新")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .onTapGesture {
                                        refreshQRCode()
                                    }
                                }
                            }
                            
                            // 倒计时
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("二维码有效期 \(String(format: "%02d:%02d", countdown / 60, countdown % 60))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            // 提示文字
                            VStack(spacing: 8) {
                                Text("请使用手机QQ扫描二维码")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                
                                Text("扫描后请在手机上确认登录")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(24)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        
                        // 底部提示
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("安全登录")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            Text("授权后仅获取游戏登录所需信息")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            qrCodeTimer?.invalidate()
        }
    }
    
    private func startTimer() {
        countdown = 120
        qrCodeExpired = false
        qrCodeTimer?.invalidate()
        qrCodeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                qrCodeExpired = true
                timer.invalidate()
            }
        }
    }
    
    private func refreshQRCode() {
        startTimer()
    }
}

// MARK: - Token管理页面
struct TokenManageView: View {
    @Binding var selectedTab: Int
    @StateObject private var loginManager = GameLoginManager()
    @State private var tokenInput: String = ""
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.16)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    Button(action: { selectedTab = 0 }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Token管理")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(Color(red: 0.10, green: 0.12, blue: 0.20))
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 状态卡片
                        HStack {
                            Circle()
                                .fill(loginManager.isLoggedIn ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(loginManager.isLoggedIn ? "已登录" : "未登录")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        
                        // Token输入区域
                        VStack(spacing: 12) {
                            Text("输入Token")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            SecureField("请输入或粘贴Token...", text: $tokenInput)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    loginManager.manualTokenInput(tokenInput)
                                    tokenInput = ""
                                }) {
                                    Text("确认提交")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.green)
                                        .cornerRadius(10)
                                }
                                
                                Button(action: { loginManager.copyToken() }) {
                                    Text("复制Token")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        
                        // 已保存账号
                        if !loginManager.accounts.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("已保存的账号")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                                
                                ForEach(loginManager.accounts) { account in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(account.gameName)
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                            Text("UID: \(account.uid)")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        Spacer()
                                        Button("复制") {
                                            loginManager.copyAccountUID(account.uid)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(10)
                                }
                                
                                Button("清空所有") {
                                    loginManager.clearAllAccounts()
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

// MARK: - 游戏登录页面
struct GameLoginView: View {
    @Binding var selectedTab: Int
    @StateObject private var loginManager = GameLoginManager()
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.16)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    Button(action: { selectedTab = 0 }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("游戏登录")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(Color(red: 0.10, green: 0.12, blue: 0.20))
                
                ScrollView {
                    VStack(spacing: 16) {
                        // 状态提示
                        if !loginManager.isLoggedIn {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("请先在Token管理中设置Token")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        // 游戏列表
                        VStack(spacing: 12) {
                            gameLoginCard(
                                name: "三角洲行动",
                                icon: "arrow.triangle.swap",
                                color: Color(red: 1.0, green: 0.45, blue: 0.0),
                                code: "delta_force"
                            )
                            
                            gameLoginCard(
                                name: "暗区突围",
                                icon: "shield.fill",
                                color: Color(red: 0.9, green: 0.15, blue: 0.15),
                                code: "dark_zone"
                            )
                            
                            gameLoginCard(
                                name: "和平精英",
                                icon: "scope",
                                color: Color(red: 0.1, green: 0.8, blue: 0.3),
                                code: "peace_elite"
                            )
                        }
                        
                        // 已登录账号
                        if !loginManager.accounts.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("登录记录")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                                
                                ForEach(loginManager.accounts) { account in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(account.gameName)
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                            Text("UID: \(account.uid)")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.5))
                                            Text(account.loginTime)
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                        Spacer()
                                        HStack(spacing: 8) {
                                            Button("复制UID") {
                                                loginManager.copyAccountUID(account.uid)
                                            }
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            
                                            Button("删除") {
                                                loginManager.deleteAccount(id: account.id)
                                            }
                                            .font(.caption)
                                            .foregroundColor(.red)
                                        }
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(10)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(16)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
    
    private func gameLoginCard(name: String, icon: String, color: Color, code: String) -> some View {
        Button(action: {
            loginManager.loginGame(gameName: name, gameCode: code)
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("点击登录")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Text("🚀 登录")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(color)
                    .cornerRadius(8)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}