import SwiftUI

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
    @Published var message: String = ""
    @Published var messageType: MessageType = .info
    
    enum MessageType {
        case info, success, warning, error
    }
    
    private let userDefaults = UserDefaults.standard
    private let accountsKey = "game_accounts"
    private let tokensKey = "token_records"
    
    init() {
        loadAccounts()
        loadTokens()
    }
    
    // ✅ 扫码获取Token后储存
    func saveScannedToken(_ token: String, source: String = "QQ扫码") {
        guard !token.isEmpty else {
            showMessage("Token不能为空", type: .warning)
            return
        }
        
        // 检查是否已存在
        if tokenRecords.contains(where: { $0.token == token }) {
            showMessage("该Token已存在", type: .warning)
            return
        }
        
        let newRecord = TokenRecord(
            id: UUID().uuidString,
            token: token,
            source: source,
            createTime: getCurrentTimeString(),
            note: ""
        )
        
        tokenRecords.insert(newRecord, at: 0)
        saveTokens()
        currentToken = token
        isLoggedIn = true
        showMessage("Token已储存", type: .success)
    }
    
    // 选择Token使用
    func selectToken(_ token: String) {
        currentToken = token
        isLoggedIn = true
        showMessage("已切换到该Token", type: .success)
    }
    
    // 复制Token
    func copyToken(_ token: String) {
        UIPasteboard.general.string = token
        showMessage("Token已复制到剪贴板", type: .success)
    }
    
    // 复制当前Token
    func copyCurrentToken() {
        guard !currentToken.isEmpty else {
            showMessage("请先选择Token", type: .warning)
            return
        }
        UIPasteboard.general.string = currentToken
        showMessage("Token已复制到剪贴板", type: .success)
    }
    
    // 删除Token
    func deleteToken(id: String) {
        let deletedToken = tokenRecords.first { $0.id == id }
        tokenRecords.removeAll { $0.id == id }
        saveTokens()
        
        // 如果删除的是当前使用的Token，清除当前Token
        if deletedToken?.token == currentToken {
            currentToken = ""
            isLoggedIn = false
        }
        showMessage("Token已删除", type: .info)
    }
    
    // 编辑Token备注
    func updateTokenNote(id: String, note: String) {
        if let index = tokenRecords.firstIndex(where: { $0.id == id }) {
            tokenRecords[index].note = note
            saveTokens()
        }
    }
    
    // 清空所有Token
    func clearAllTokens() {
        tokenRecords.removeAll()
        currentToken = ""
        isLoggedIn = false
        saveTokens()
        showMessage("所有Token已清空", type: .info)
    }
    
    // 手动输入Token
    func manualTokenInput(_ token: String) {
        if token.isEmpty {
            showMessage("请输入Token", type: .warning)
            return
        }
        saveScannedToken(token, source: "手动输入")
    }
    
    func loginGame(gameName: String, gameCode: String) {
        guard !currentToken.isEmpty else {
            showMessage("请先选择Token", type: .warning)
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
    
    private func saveTokens() {
        if let encoded = try? JSONEncoder().encode(tokenRecords) {
            userDefaults.set(encoded, forKey: tokensKey)
        }
    }
    
    private func loadTokens() {
        if let data = userDefaults.data(forKey: tokensKey),
           let decoded = try? JSONDecoder().decode([TokenRecord].self, from: data) {
            tokenRecords = decoded
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
    
    // 模拟扫码获取Token（实际应用中由扫码回调触发）
    func simulateQRCodeScan() {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let token = "QQ_" + String((0..<32).map { _ in chars.randomElement()! })
        saveScannedToken(token, source: "QQ扫码")
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

// MARK: - 主页面
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
    @StateObject private var loginManager = GameLoginManager()
    
    var body: some View {
        ZStack {
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
                
                VStack(spacing: 20) {
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
                                Text("使用手机QQ扫描二维码获取Token")
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
                    
                    Button(action: { selectedTab = 2 }) {
                        HStack(spacing: 16) {
                            Image(systemName: "list.clipboard.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.orange.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Token管理")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("储存扫码Token，一键复制和删除")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            // Token数量角标
                            Text("\(loginManager.tokenRecords.count)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .cornerRadius(16)
                    }
                    
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
                
                Text("v1.0.0")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - QQ扫码页面
struct QRCodeView: View {
    @Binding var selectedTab: Int
    @StateObject private var loginManager = GameLoginManager()
    @State private var qrCodeTimer: Timer?
    @State private var countdown = 120
    @State private var qrCodeExpired = false
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.16)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
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
                    
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 16)
                .padding(.top, 50)
                .padding(.bottom, 10)
                .background(Color(red: 0.10, green: 0.12, blue: 0.20))
                
                ScrollView {
                    VStack(spacing: 24) {
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
                        
                        VStack(spacing: 20) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white)
                                    .frame(width: 240, height: 240)
                                
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
                            
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("二维码有效期 \(String(format: "%02d:%02d", countdown / 60, countdown % 60))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            VStack(spacing: 8) {
                                Text("请使用手机QQ扫描二维码")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                
                                Text("扫描后Token将自动储存到Token管理")
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
                        
                        // 模拟扫码按钮
                        Button(action: {
                            loginManager.simulateQRCodeScan()
                        }) {
                            HStack {
                                Image(systemName: "iphone")
                                Text("模拟扫码获取Token")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue.opacity(0.3))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                            )
                        }
                        
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

// MARK: - Token管理页面（储存扫码Token，一键复制和删除）
struct TokenManageView: View {
    @Binding var selectedTab: Int
    @StateObject private var loginManager = GameLoginManager()
    @State private var showDeleteAlert = false
    @State private var tokenToDelete: String?
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.16)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
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
                    
                    if !loginManager.tokenRecords.isEmpty {
                        Button(action: { loginManager.clearAllTokens() }) {
                            Text("清空")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 50)
                .padding(.bottom, 10)
                .background(Color(red: 0.10, green: 0.12, blue: 0.20))
                
                ScrollView {
                    VStack(spacing: 16) {
                        // 当前使用的Token
                        if loginManager.isLoggedIn {
                            VStack(spacing: 8) {
                                HStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("当前使用")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text(loginManager.currentToken)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Spacer()
                                    Button(action: { loginManager.copyCurrentToken() }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // 手动输入Token
                        VStack(spacing: 12) {
                            Text("手动输入Token")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 8) {
                                TextField("输入或粘贴Token...", text: Binding(
                                    get: { "" },
                                    set: { newValue in
                                        if !newValue.isEmpty {
                                            loginManager.manualTokenInput(newValue)
                                        }
                                    }
                                ))
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                
                                Button(action: {}) {
                                    Text("储存")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(Color.orange)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        
                        // Token列表
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("已储存的Token")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Text("\(loginManager.tokenRecords.count)个")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            if loginManager.tokenRecords.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "tray")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.3))
                                    Text("暂无储存的Token")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.4))
                                    Text("扫码后Token将自动储存到这里")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                ForEach(loginManager.tokenRecords) { record in
                                    TokenCardView(
                                        record: record,
                                        isCurrentToken: record.token == loginManager.currentToken,
                                        onSelect: { loginManager.selectToken(record.token) },
                                        onCopy: { loginManager.copyToken(record.token) },
                                        onDelete: { loginManager.deleteToken(id: record.id) }
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                    }
                    .padding(16)
                }
            }
        }
    }
}

// Token卡片
struct TokenCardView: View {
    let record: TokenRecord
    let isCurrentToken: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                // 来源标识
                Text(record.source)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(record.source == "QQ扫码" ? Color.blue.opacity(0.5) : Color.orange.opacity(0.5))
                    .cornerRadius(4)
                
                Spacer()
                
                Text(record.createTime)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            
            // Token显示（脱敏）
            Text(maskToken(record.token))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 操作按钮
            HStack(spacing: 8) {
                if !isCurrentToken {
                    Button(action: onSelect) {
                        Label("使用", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                } else {
                    Label("使用中", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Button(action: onCopy) {
                    Label("复制", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                
                Button(action: onDelete) {
                    Label("删除", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(
            isCurrentToken ? Color.green.opacity(0.08) : Color.white.opacity(0.05)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isCurrentToken ? Color.green.opacity(0.3) : Color.white.opacity(0.1),
                    lineWidth: 1
                )
        )
    }
    
    // Token脱敏显示
    private func maskToken(_ token: String) -> String {
        guard token.count > 10 else { return token }
        let prefix = String(token.prefix(6))
        let suffix = String(token.suffix(4))
        return "\(prefix)****\(suffix)"
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
                .padding(.top, 50)
                .padding(.bottom, 10)
                .background(Color(red: 0.10, green: 0.12, blue: 0.20))
                
                ScrollView {
                    VStack(spacing: 16) {
                        if !loginManager.isLoggedIn {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("请先在Token管理中选择Token")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
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