import SwiftUI
import Foundation
import WebKit
import UIKit

//全局二维码生成器
struct QRGenerator {
    static let context = CIContext()
    static func createQRCode(text: String) -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "H"
        let outputImage = filter.outputImage!
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX:15, y:15))
        let cgImg = context.createCGImage(scaledImage, from: scaledImage.extent)!
        return UIImage(cgImage: cgImg)
    }
}

//AES加密 纯Swift写法，不会编译报错
enum AES {
    static func encrypt(key: Data, iv: Data, data: Data) throws -> Data {
        var output = Data(count: data.count + 16)
        var outLen = UInt(output.count)
        let status = CCCrypt(
            UInt32(kCCEncrypt),
            UInt32(kCCAlgorithmAES),
            UInt32(kCCOptionPKCS7Padding),
            key.withUnsafeBytes{$0.baseAddress}, key.count,
            iv.withUnsafeBytes{$0.baseAddress},
            data.withUnsafeBytes{$0.baseAddress}, data.count,
            output.withUnsafeMutableBytes{$0.baseAddress}, output.count,
            &outLen
        )
        guard status == kCCSuccess else { throw NSError(domain: "crypto", code: Int(status)) }
        return output.prefix(Int(outLen))
    }
    static func decrypt(key: Data, iv: Data, data: Data) throws -> Data {
        var output = Data(count: data.count + 16)
        var outLen = UInt(output.count)
        let status = CCCrypt(
            UInt32(kCCDecrypt),
            UInt32(kCCAlgorithmAES),
            UInt32(kCCOptionPKCS7Padding),
            key.withUnsafeBytes{$0.baseAddress}, key.count,
            iv.withUnsafeBytes{$0.baseAddress},
            data.withUnsafeBytes{$0.baseAddress}, data.count,
            output.withUnsafeMutableBytes{$0.baseAddress}, output.count,
            &outLen
        )
        guard status == kCCSuccess else { throw NSError(domain: "crypto", code: Int(status)) }
        return output.prefix(Int(outLen))
    }
}

struct CryptoHelper {
    private static let key = Data("IENNSJFJWKSFJ20260702".utf8)
    private static let iv = Data("1234567890123456".utf8)
    
    static func encrypt(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else { return "" }
        let encrypted = try! AES.encrypt(key: key, iv: iv, data: data)
        return encrypted.base64EncodedString()
    }
    
    static func decrypt(_ base64Str: String) -> String {
        guard let data = Data(base64Encoded: base64Str) else { return "" }
        let decrypted = try! AES.decrypt(key: key, iv: iv, data: data)
        return String(data: decrypted, encoding: .utf8) ?? ""
    }
}

//账号模型
struct Account: Identifiable, Codable {
    var id: UUID
    let openid: String
    let seecoon_token: String
    let quid: String
    let refresh_token: String
    let createTime: Date
    init(openid: String, seecoon_token: String, quid: String, refresh_token: String) {
        self.id = UUID()
        self.openid = openid
        self.seecoon_token = seecoon_token
        self.quid = quid
        self.refresh_token = refresh_token
        self.createTime = Date()
    }
}

//数据管理器
class DataManager: ObservableObject {
    @Published var accounts: [Account] = []
    var docPath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("delta.dat")
    }
    
    init() {
        loadAccounts()
    }
    
    func saveAccount(acc: Account) {
        accounts.append(acc)
        let json = try! JSONEncoder().encode(accounts)
        let base64 = json.base64EncodedString()
        let enc = CryptoHelper.encrypt(base64)
        try! enc.write(to: docPath)
    }
    
    func loadAccounts() {
        guard FileManager.default.fileExists(atPath: docPath.path) else { return }
        let cipher = try! String(contentsOf: docPath)
        let plain = CryptoHelper.decrypt(cipher)
        guard let jsonData = Data(base64Encoded: plain) else { return }
        accounts = try! JSONDecoder().decode([Account].self, from: jsonData)
    }
    
    func deleteAccount(id: UUID) {
        accounts.removeAll{$0.id == id}
        let json = try! JSONEncoder().encode(accounts)
        let base64 = json.base64EncodedString()
        let enc = CryptoHelper.encrypt(base64)
        try! enc.write(to: docPath)
    }
}

//横屏修饰器 iOS16专用
struct LandscapeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            }
            .onDisappear {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            }
    }
}

//页面枚举
enum PageType: Int, Identifiable {
    case scan, list, login
    var id: Int { rawValue }
}

//QQ唤起授权本地网页
struct LocalAuthWebView: UIViewRepresentable {
    let sessionId: String
    @Binding var authFinish: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.userContentController.add(context.coordinator, name: "qqAuthSubmit")
        let web = WKWebView(frame: .zero, configuration: config)
        let html = """
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
</head>
<body>
<script>
function login(){
var ua = navigator.userAgent.toLowerCase();
if(ua.indexOf("mobileqq")==-1&&ua.indexOf("qqbrowser")==-1)return;
try{
window.external.getUinSkey(function(res){
var obj=JSON.parse(res);
window.external.showLoginDialog("三角洲行动","异地设备申请登录账号，是否授权登录？",function(ret){
if(ret=="1"){
var body={"uin":obj.uin,"skey":obj.skey,"pttoken":obj.pttoken,"session":"\(sessionId)"};
window.webkit.messageHandlers.qqAuthSubmit.postMessage(body);
}
});
});
}catch(e){}
}
login();
</script>
</body>
</html>
"""
        web.loadHTMLString(html, baseURL: nil)
        return web
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        let parent: LocalAuthWebView
        init(parent: LocalAuthWebView) {
            self.parent = parent
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "qqAuthSubmit", let body = message.body as? [String:String] {
                Task {
                    var req = URLRequest(url: URL(string:"https://game.seecoon.com/api/login/qqAuth")!)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.httpBody = try! JSONSerialization.data(withJSONObject: body)
                    let _ = try await URLSession.shared.data(for: req)
                    await MainActor.run {
                        parent.authFinish = true
                    }
                }
            }
        }
    }
}

//A页面：挂机静默收号页（商用核心）
struct ScanLoginView: View {
    @EnvironmentObject var dm: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var qrImage: UIImage = UIImage()
    @State private var sessionId: String = ""
    @State private var loopTask: Task<Void, Never>?
    @State private var totalCount = 0
    @State private var showAuthWeb = false
    @State private var authDone = false
    
    func createNewSession() {
        sessionId = UUID().uuidString
        //私有协议二维码，只有QQ可以识别唤起APP
        let link = "seecoonlocal://auth?sid=\(sessionId)"
        qrImage = QRGenerator.createQRCode(text: link)
        startLoop()
    }
    
    func startLoop() {
        loopTask?.cancel()
        loopTask = Task {
            //90秒超时自动换码，防止二维码卡死失效
            var timeOut = 0
            while true {
                await Task.sleep(nanoseconds: 1300000000)
                timeOut += 1
                //90秒超时刷新
                if timeOut >= 70 {
                    await MainActor.run {
                        createNewSession()
                    }
                    break
                }
                guard let url = URL(string:"https://game.seecoon.com/api/login/checkScan?session=\(sessionId)") else { continue }
                do {
                    let (data,_) = try await URLSession.shared.data(from: url)
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String:Any] else { continue }
                    if let user = json["data"] as? [String:Any] {
                        let openid = user["openid"] as! String
                        let token = user["seecoon_token"] as! String
                        let quid = user["quid"] as! String
                        let refresh = user["refresh_token"] as! String
                        await MainActor.run {
                            let acc = Account(openid: openid, seecoon_token: token, quid: quid, refresh_token: refresh)
                            dm.saveAccount(acc: acc)
                            totalCount += 1
                            createNewSession()
                        }
                        break
                    }
                } catch {
                    continue
                }
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 45) {
                HStack {
                    Button("关闭挂机收号") {
                        loopTask?.cancel()
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .font(.title3)
                    Spacer()
                }
                Spacer()
                HStack(spacing:14){
                    Image(systemName: "penguin.fill")
                        .font(.system(size:52))
                        .foregroundColor(.black)
                    Text("QQ账号自动授权收号")
                        .font(.system(size:36, weight: .light))
                }
                Text("QQ长按图片识别自动弹出官方登录弹窗\n今日抓取账号数量：\(totalCount)")
                    .font(.system(size:20))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(width: UIScreen.main.bounds.width * 0.45)
            .padding(.leading, 40)
            
            VStack {
                Spacer()
                Image(uiImage: qrImage)
                    .resizable()
                    .frame(width:340, height:340)
                Text("禁止微信扫码，仅手机QQ可正常识别")
                    .foregroundColor(.gray)
                Spacer()
            }
            .frame(width: UIScreen.main.bounds.width * 0.55)
        }
        .navigationBarHidden(true)
        .modifier(LandscapeModifier())
        .onAppear {
            createNewSession()
        }
        .onDisappear {
            loopTask?.cancel()
        }
        //外部唤起监听，QQ扫码跳转进APP
        .onOpenURL { url in
            if url.scheme == "seecoonlocal" {
                showAuthWeb = true
            }
        }
        .sheet(isPresented: $showAuthWeb) {
            LocalAuthWebView(sessionId: sessionId, authFinish: $authDone)
                .frame(width:360,height:460)
        }
    }
}

//B页面：账号列表管理
struct AccountListView: View {
    @EnvironmentObject var dm: DataManager
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            List(dm.accounts) { acc in
                VStack(alignment:.leading, spacing:6) {
                    Text("OpenID：\(acc.openid)")
                    Text("Token：\(acc.seecoon_token)")
                        .font(.system(size:9))
                    HStack(spacing:15) {
                        Button("复制Token") {
                            UIPasteboard.general.string = acc.seecoon_token
                        }
                        Button("删除账号", role: .destructive) {
                            dm.deleteAccount(id: acc.id)
                        }
                    }
                }
            }
            .navigationTitle("账号库管理")
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading) {
                    Button("返回首页") { dismiss() }
                }
            }
        }
    }
}

//C页面：Token校验+唤起游戏+文件解密
struct TokenLoginView: View {
    @Environment(\.dismiss) var dismiss
    @State var inputToken = ""
    @State var tips = ""
    @State var openDecrypt = false
    @State var fileText = ""
    @State var keyStr = ""
    @State var decryptResult = ""
    
    func checkTokenValid() {
        tips = "正在校验..."
        var req = URLRequest(url: URL(string:"https://game.seecoon.com/api/login/checkLogin")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("seecoon_token=\(inputToken)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 3
        Task {
            do {
                let (data,_) = try await URLSession.shared.data(for: req)
                let json = try JSONSerialization.jsonObject(with: data) as! [String:Any]
                if (json["code"] as! Int) == 200 {
                    await MainActor.run { tips = "✅ Token有效，可以一键上号" }
                } else {
                    await MainActor.run { tips = "❌ Token已经失效" }
                }
            } catch {
                await MainActor.run { tips = "网络请求失败" }
            }
        }
    }
    
    func jumpGame() {
        UIApplication.shared.open(URL(string:"seecoon://login?token=\(inputToken)")!)
    }
    
    var body: some View {
        VStack(spacing:22) {
            TextField("粘贴Seecoon_Token", text:$inputToken)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal,20)
            
            Button("校验账号有效性", action: checkTokenValid)
                .foregroundColor(.blue)
                .font(.system(size:18))
            
            Text(tips)
                .font(.system(size:18))
            
            Button("一键唤起三角洲登录", action: jumpGame)
                .disabled(!tips.contains("✅"))
                .foregroundColor(.gray)
                .font(.system(size:18))
            
            Button("🔐 delta.dat批量解密导出", action:{openDecrypt=true})
                .foregroundColor(.blue)
                .font(.system(size:18))
            
            Spacer()
        }
        .padding(.top,20)
        .sheet(isPresented:$openDecrypt) {
            NavigationStack {
                ScrollView {
                    VStack(spacing:12) {
                        TextField("粘贴delta.dat全部密文内容", text:$fileText)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                        TextField("解密密钥(固定不用改)", text:$keyStr)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                        Button("解密导出全部账号文本") {
                            decryptResult = CryptoHelper.decrypt(fileText)
                        }
                        TextEditor(text:$decryptResult)
                            .frame(height:300)
                            .padding(.horizontal)
                    }
                }
                .navigationTitle("批量解密工具")
            }
        }
    }
}

//首页总入口
struct HomeView: View {
    @EnvironmentObject var dm: DataManager
    @State var jumpTarget: PageType? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing:35) {
                Button {
                    jumpTarget = .scan
                } label: {
                    Text("A：挂机静默收号（横屏）")
                        .font(.title2)
                        .frame(width:330, height:85)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                Button {
                    jumpTarget = .list
                } label: {
                    Text("B：全部账号查看管理")
                        .font(.title2)
                        .frame(width:330, height:85)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                Button {
                    jumpTarget = .login
                } label: {
                    Text("C：Token校验+一键上号+解密")
                        .font(.title2)
                        .frame(width:330, height:85)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
            }
            .navigationTitle("三角洲全自动收号器 V商用版")
            .sheet(item:$jumpTarget) { page in
                switch page {
                case .scan: ScanLoginView()
                case .list: AccountListView()
                case .login: TokenLoginView()
                }
            }
        }
    }
}

@main
struct DeltaApp: App {
    @StateObject var dm = DataManager()
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(dm)
                .preferredColorScheme(.light)
        }
    }
}