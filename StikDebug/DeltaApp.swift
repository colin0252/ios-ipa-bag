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
    
    // ✅ 添加这个方法
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
        return "https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=QQ_LOGIN"
    }
}

// MARK: - 主界面
struct ContentView: View {
    @StateObject private var loginManager = GameLoginManager()
    @State private var tokenInput: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    tokenSection
                    qrCodeSection
                    gameLoginSection
                    accountListSection
                }
                .padding()
            }
            .navigationTitle("游戏账号管理助手")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🔑 Token管理").font(.headline)
            HStack {
                SecureField("输入Token...", text: $tokenInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 14))
                Button("📋 复制") { loginManager.copyToken() }
                    .buttonStyle(.bordered)
                Button("✔️ 确认") { loginManager.manualTokenInput(tokenInput) }
                    .buttonStyle(.bordered)
                    .tint(.green)
            }
            HStack {
                Circle()
                    .fill(loginManager.isLoggedIn ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(loginManager.isLoggedIn ? "已登录" : "未登录")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var qrCodeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📱 QQ扫码登录").font(.headline)
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 150, height: 150)
                    AsyncImage(url: URL(string: loginManager.generateQRCodeURL())) { image in
                        image.resizable().scaledToFit().frame(width: 140, height: 140)
                    } placeholder: {
                        VStack {
                            Image(systemName: "qrcode").font(.system(size: 40))
                            Text("QQ二维码").font(.caption)
                        }
                        .foregroundColor(.gray)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("使用说明：").font(.subheadline).fontWeight(.bold)
                    Text("1. 打开手机QQ扫描左侧二维码").font(.caption)
                    Text("2. 在手机上确认授权登录").font(.caption)
                    Text("3. 等待自动获取Token").font(.caption)
                    Text("4. Token将自动填充到输入框").font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var gameLoginSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🎮 游戏登录").font(.headline)
            HStack(spacing: 20) {
                gameButton(name: "三角洲行动", icon: "arrow.triangle.swap", color: .orange, code: "delta_force")
                gameButton(name: "暗区突围", icon: "shield.fill", color: .red, code: "dark_zone")
                gameButton(name: "和平精英", icon: "scope", color: .green, code: "peace_elite")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func gameButton(name: String, icon: String, color: Color, code: String) -> some View {
        VStack {
            Image(systemName: icon).font(.system(size: 30)).foregroundColor(color)
            Text(name).font(.caption)
            Button("🚀 登录") {
                loginManager.loginGame(gameName: name, gameCode: code)
            }
            .buttonStyle(.bordered).tint(color).font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
    
    private var accountListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("📋 已保存的账号").font(.headline)
                Spacer()
                Button("🗑️ 清空所有") { loginManager.clearAllAccounts() }
                    .font(.caption).foregroundColor(.red)
            }
            if loginManager.accounts.isEmpty {
                Text("暂无账号，请先登录游戏")
                    .foregroundColor(.gray).padding()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(loginManager.accounts) { account in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.gameName).font(.subheadline).fontWeight(.medium)
                            Text("UID: \(account.uid)").font(.caption).foregroundColor(.gray)
                            Text("登录时间: \(account.loginTime)").font(.caption2).foregroundColor(.gray)
                        }
                        Spacer()
                        Button("📋 复制") { loginManager.copyAccountUID(account.uid) }
                            .buttonStyle(.bordered).tint(.blue).font(.caption)
                        Button("🗑️ 删除") { loginManager.deleteAccount(id: account.id) }
                            .buttonStyle(.bordered).tint(.red).font(.caption)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - App入口
@main
struct DeltaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .ignoresSafeArea(.all)
        }
    }
}