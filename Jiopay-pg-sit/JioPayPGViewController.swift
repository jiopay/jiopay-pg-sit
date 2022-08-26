import Foundation
import WebKit
import UIKit

let SCREEN_WIDTH = UIScreen.main.bounds.width
let SCREEN_HEIGHT = UIScreen.main.bounds.height

enum env {
    static let PP = "https://pp-checkout.jiopay.com:8443/"
    static let SIT = "https://psp-mandate-merchant-sit.jiomoney.com:3003/pg"
    static let PROD = "https://checkout.jiopay.com"
}

enum jsEvents {
    static let initReturnUrl = "INIT_RET_URL"
    static let closeChildWindow = "CLOSE_CHILD_WINDOW"
    static let sendError = "SEND_ERROR"
    static let billPayInterface = "JioPaymentWebViewInterface"

//UPI EVENTS
    static let getInstalledUpiApps = "GET_INSTALLED_UPI_APPS"
    static let makeUpiPayment = "MAKE_UPI_PAYMENT"
}

@objc public protocol JioPayDelegate {
    func onPaymentSuccess(tid: String, intentId: String)
    func onPaymentError(code: String, error: String)
}

@objcMembers public class JioPayPGViewController: UIViewController {
    var webView: WKWebView!
    var popupWebView: WKWebView?
    var childPopupWebView: WKWebView?
    //weak var delegate: PGWebViewDelegate?
    var delegate: JioPayDelegate?
    @IBOutlet weak var containerView: UIView!
    
    var appAccessToken: String = ""
    var appIdToken: String = ""
    var intentId: String = ""
    public var urlParams: String = ""
    var brandColor: String = ""
    var bodyBgColor: String = ""
    var bodyTextColor: String = ""
    var headingText: String = ""
    
    var parentReturnURL: String = ""
    var childReturnURL: String = ""
    var errorLabel: UILabel?

    //Package Names
    let paytmPackageName = "net.one97.paytm"
    let googlePayPackage = "com.tez.nbu.paisa.user"
    let phonePayPackage = "com.phonepe.app"
    let WhatsappPackageName = "net.whatsapp.WhatsApp"
    let myJioPackageName = "com.jio.myjio"

    let app = UIApplication.shared
    

    //App DeepLinks

     let PAYTM = "paytmmp://pay?pa=dummy@yblpn=dummy&tn=UPIPayment&am=1.0&cu=INR"

     let PHONEPAY = "phonepe:pay?pa=dummy@yblpn=dummy&tn=UPIPayment&am=1.0&cu=INR"

     let GOOGLEPAY = "tez://upi/pay?pa=dummy@ybl&pn=dummy&tn=UPIPayment&am=1.0&cu=INR"

     let WHATSAPP = "upi://pay?pa=dummy@ybl&pn=dummy&tn=UPIPayment&am=1.0&cu=INR"
    
     let MYJIO = "myjio://pay?pa=dummy@yblpn=dummy&tn=UPIPayment&am=1.0&cu=INR"
    
    var rootController: UIViewController?
    //    var parentAppController: UIViewController?
    @IBOutlet weak var popupWebViewContainer: UIView!
    @IBOutlet weak var ChildPopupContainer: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
//    func showPgView() -> UIViewController {
//        let pgBundle = Bundle(for: PGWebViewController.self)
//        let pgView = PGWebViewController(nibName: "PGWebViewController", bundle: pgBundle)
//        pgView.modalPresentationStyle = .fullScreen
//        return pgView
//
//    }
    
    
    public init() {
        let pgBundle = Bundle(for: JioPayPGViewController.self)
        super.init(nibName: "JioPayPGViewController", bundle: pgBundle)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        configureWebView()
        
        errorLabel = UILabel(frame: self.view.frame)
        errorLabel?.center = self.view.center
        errorLabel?.sizeToFit()
        errorLabel?.frame = CGRect(x: SCREEN_WIDTH/2 - (errorLabel?.frame.size.width)!/2, y: SCREEN_HEIGHT/2 - 15, width: 180, height: 30)
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

        popupWebViewContainer.isHidden = true
        ChildPopupContainer.isHidden = true
    }
    
    // remove the observer
    deinit {
        print("Receiver teardown")
        NotificationCenter.default.removeObserver(self)
    }

    @objc func applicationDidBecomeActive(notification: NSNotification) {
          // Application is back in the foreground
        print("applicationDidBecomeActive Called")
        self.sendCallBackToJS(response:[] , methodName: "onResult")
        NotificationCenter.default.removeObserver(self)
          print("applicationDidBecomeActive END")
      }
    
    
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        activityIndicator.isHidden = false
        activityIndicator.color = UIColor(brandColor)
        self.popupWebViewContainer.backgroundColor = UIColor(bodyBgColor)
        self.ChildPopupContainer.backgroundColor = UIColor(bodyBgColor)
        self.view.addSubview(activityIndicator)
        
        hideNavigationBar(animated: animated)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showNavigationBar(animated: animated)
    }
    
    // @objc public func open(_ viewController: UIViewController, child:UIViewController, withData jioPayData:[AnyHashable:Any], url:String){
    //     rootController = viewController
    //     child.modalPresentationStyle = .fullScreen
    //     rootController?.present(child, animated: true, completion: nil)
    //     parseData(data: jioPayData, url: url)
    // }
    
    @objc public func open(_ viewController: UIViewController, withData pgData:[AnyHashable:Any], delegate:JioPayDelegate, url: String){
       print("Inside Open function")
       rootController = viewController
       rootController?.present(self, animated: true, completion: nil)
       parseData(data: pgData, url: url)
   }
    
    func parseData(data:[AnyHashable:Any], url: String) {
        
        if let dict = data as NSDictionary? as! [String: Any]?  {
            intentId = dict["intentid"] as! String
            let theme  = dict["theme"] as? [String:Any]
            appAccessToken = dict["appaccesstoken"] as! String
            appIdToken = dict["appidtoken"] as! String
            
            bodyBgColor = theme?["bodyBgColor"] as! String
            bodyTextColor = theme?["bodyTextColor"] as! String
            brandColor = theme?["brandColor"] as! String
            headingText = theme?["headingText"] as! String
            
            loadWebView(envUrl:url)
            
        }
    }
}

extension JioPayPGViewController : WKScriptMessageHandler, WKUIDelegate, UIScrollViewDelegate, UINavigationControllerDelegate {
    
    func configureWebView() {
        //  Initial configuration required for WKWebView
        
        let contentController = WKUserContentController()
        contentController.add(self, name: jsEvents.billPayInterface)
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController = contentController
        
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: SCREEN_WIDTH, height: SCREEN_HEIGHT), configuration: webConfiguration)
        webView.configuration.preferences.javaScriptEnabled = true
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView.allowsBackForwardNavigationGestures = true
        webView.uiDelegate = self
        webView.navigationDelegate = self
        view.addSubview(webView)
        self.view.layoutSubviews()
    }
    
    func loadWebView(envUrl:String) {
       let url = URL (string: envUrl)
       let request = NSMutableURLRequest(url: url!)
       request.httpMethod = "POST"
       request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
       var post: String = "appaccesstoken=\(appAccessToken)&appidtoken=\(appIdToken)&intentid=\(intentId)&brandColor=\(brandColor)&bodyBgColor=\(bodyBgColor)&bodyTextColor=\(bodyTextColor)&headingText=\(headingText)"
       post = post.replacingOccurrences(of: "+", with: "%2b")
       request.httpBody = post.data(using: .utf8)
       showActivityIndicator(show: true)
       webView.load(request as URLRequest)
    }
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("start loading")
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == jsEvents.billPayInterface {
            do {
                let messageBody = message.body as! String
                let eventData = Data(messageBody.utf8)
                if let eventJson = try JSONSerialization.jsonObject(with: eventData, options: []) as? [String: AnyObject] {
                    self.processInput(eventData: eventJson)
                }
            }
            catch{
                
            }
        }
    }
    
    func getAppDeepLinkFirstName(appBundle:String) ->String{
        if(appBundle.contains(googlePayPackage)){
            return "tez"
        }
        else if(appBundle.contains(phonePayPackage)){
            return "phonepe"
        }
        else if(appBundle.contains(paytmPackageName)){
            return "paytmmp"
        }
        else if(appBundle.contains(myJioPackageName)){
            return "myjio"
        }
        else {
            return "upi"
        }
    }
    
    public func processInput(eventData:[String: Any])->[[String : String]]{
        if let eventName = eventData["event"] as? String {
            print("eventName",eventName)
            print("eventData",eventData)
            let data = eventData["data"]
            let appBundleName = eventData["package"] as? String
            let passedDeepLinkUrl = eventData["uri"] as? String
            print("appBundleName",appBundleName)
            print("passedDeepLinkUrl",passedDeepLinkUrl)
            switch eventName {
            case jsEvents.initReturnUrl:
                handleReturnUrlEvent(data: data as! [String : Any])
                break
            case jsEvents.closeChildWindow:
                handleCloseChildWindowEvent()
                break
            case jsEvents.sendError:
                handleSendErrorEvent(data: data as! [String : Any])
                break
            case jsEvents.getInstalledUpiApps:
                let availableApps = isUpiAppAvailable()
                self.sendCallBackToJS(response: availableApps, methodName: "onUpiAppsListRecived")
            case jsEvents.makeUpiPayment:
                let appPrefix = getAppDeepLinkFirstName(appBundle: appBundleName!)
                let replacedStringWithConcernedApp = replaceOccurencesOfString(url: passedDeepLinkUrl!, replaceWith: appPrefix)
                openDeeplinkApp(appScheme: replacedStringWithConcernedApp)
            break;
                
            default:
                break
            }
        }
        return []
    }
    
    
    func sendCallBackToJS(response:Any, methodName:String){
                   let jsonData = try! JSONSerialization.data(withJSONObject: response, options: [])
                   let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)!
                   
                   webView.evaluateJavaScript("\(methodName)('\(jsonString)');") { result, error in
                       guard error == nil else {
                           print(error?.localizedDescription as Any)
                           return
                       }
                   }
               }

public func isUpiAppAvailable() -> [[String : String]] {
let arrOfDict = [PAYTM, PHONEPAY, GOOGLEPAY, WHATSAPP,MYJIO]
var availableApps: [[String : String]] = []
    
    for appName in arrOfDict {
         if app.canOpenURL(URL(string: appName)!) {
            if(appName.contains("paytm")){
                let imageBase64Data = convertImageToBase64(base64AppIcon: "Paytm.png")
                availableApps.append(["appName" : "Paytm" , "base64AppIcon" : imageBase64Data, "packageName" : paytmPackageName  ])
            }
            else if(appName.contains("tez")){
                let imageBase64Data = convertImageToBase64(base64AppIcon: "Googlepay.png")
                availableApps.append(["appName" : "GooglePay" , "base64AppIcon" : imageBase64Data, "packageName" : googlePayPackage  ])
            }
           else if(appName.contains("phonepe")){
               let imageBase64Data = convertImageToBase64(base64AppIcon: "PhonePay.png")
               availableApps.append(["appName" : "PhonePay" , "base64AppIcon" :imageBase64Data, "packageName" : phonePayPackage  ])
            }
             else if(appName.contains("myjio")){
                 let imageBase64Data = convertImageToBase64(base64AppIcon: "myjio.png")
                 availableApps.append(["appName" : "MyJio" , "base64AppIcon" :imageBase64Data, "packageName" : myJioPackageName  ])
              }
            else if(appName.contains("upi://")){
                let imageBase64Data = convertImageToBase64(base64AppIcon: "Whatsapp.png")
                availableApps.append(["appName" : "WhatsApp" , "base64AppIcon" : imageBase64Data, "packageName" : WhatsappPackageName  ])
             }
    }
}
    print("Available Apps", availableApps)
    return availableApps
}


func openDeeplinkApp(appScheme:String) {
     if app.canOpenURL(URL(string: appScheme)!) {
         print("App is installed and can be opened")
         let url = URL(string:appScheme)!
         if #available(iOS 10.0, *) {
             UIApplication.shared.open(url, options: [:], completionHandler: {
                 (success) in
                    print("Open \(appScheme): \(success)")
             })
         } else {
             UIApplication.shared.openURL(url)
         }
     } else {
         //This case will not come into picture!
         print("App in not installed. Go to Jio Pay")
     }
}
    
    //This will replace the passed deeplink url!
    func replaceOccurencesOfString(url:String, replaceWith:String) -> String{
        //Check whehter it is not a default App opening option
        if(replaceWith != "upi"){
        if let range = url.range(of:"upi") {
            return url.replacingCharacters(in: range, with:replaceWith)
         }
        return url
    }
        //If it is not a default App opening option then -
        else{
            if let range = url.range(of:"upi://upi/") {
                return url.replacingCharacters(in: range, with:"upi://")
             }
            print("url",url)
            return url
        }
    }

func convertImageToBase64(base64AppIcon:String) -> String{
    let bundle = Bundle(for: type(of: self))
    let base64AppIcon = UIImage(named: base64AppIcon,in: bundle, compatibleWith: nil)
    let imageData = base64AppIcon?.pngData()
    let imageBase64String = imageData?.base64EncodedString() ?? ""
    return imageBase64String
}

    
    func handleSendErrorEvent(data: [String: Any]) {
        let errorCode = data["status_code"] as! String
        let errorMessgae = data["error_msg"] as! String
        self.webViewDidClose(webView)
//        self.delegate?.onPaymentError(code: errorCode, error: errorMessgae)
        NotificationCenter.default.post(name: .paymentFail, object: "paymentFailObject", userInfo: ["code":errorCode, "error":errorMessgae])
        
    }
    
    func handleReturnUrlEvent(data: [String: Any]) {
        let urlString = (data["ret_url"] as? String)!
        var urlComponents = (URLComponents(string: urlString))
        urlComponents?.query = nil
        if popupWebView == nil {
            self.parentReturnURL = (urlComponents?.url!.absoluteString)!
        }else {
            self.childReturnURL = (urlComponents?.url!.absoluteString)!
        }
    }
    
    func showActivityIndicator(show: Bool) {
        if show {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }
    
    func handleCloseChildWindowEvent() {
        let jsMethod = "jiopayCloseChildWindow();"
        if childPopupWebView != nil {
            self.popupWebView!.evaluateJavaScript(jsMethod, completionHandler: { result, error in
                guard error == nil else {
                    print(error as Any)
                    return
                }
            })
        }else if popupWebView != nil{
            self.webView!.evaluateJavaScript(jsMethod, completionHandler: { result, error in
                guard error == nil else {
                    print(error as Any)
                    return
                }
            })
        }
    }
    
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust  else {
            completionHandler(.useCredential, nil)
            return
        }
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: ((WKNavigationActionPolicy) -> Void)) {
        
        let redirectUrlStr = navigationAction.request.url?.absoluteString
        if self.webView != nil {
            if !self.parentReturnURL.isEmpty && redirectUrlStr!.hasPrefix(self.parentReturnURL) {
                let txnId = navigationAction.request.url?.queryParameters?["tid"]
                let intentId = navigationAction.request.url?.queryParameters?["intentid"]
                webView.stopLoading()
                decisionHandler(.cancel)
                webViewDidClose(webView)
                if(delegate == nil) {
                  NotificationCenter.default.post(name: .paymentSuccess, object: "paymentSuccessObject", userInfo: ["tid":txnId! as Any, "intentId":intentId as Any])
                } else {
                  self.delegate?.onPaymentSuccess(tid: txnId!, intentId: intentId!)
                }
            }else{
                decisionHandler(.allow)
            }
        }
        else  {
            decisionHandler(.allow)
        }
    }
    
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if popupWebView != nil {
            childPopupWebView = WKWebView(frame: ChildPopupContainer.bounds, configuration: configuration)
            ChildPopupContainer.isHidden = false
            childPopupWebView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            childPopupWebView!.navigationDelegate = self
            childPopupWebView!.uiDelegate = self
            ChildPopupContainer.addSubview(childPopupWebView!)
            popupWebViewContainer.addSubview(ChildPopupContainer)
            return childPopupWebView!
        }else {
            popupWebView = WKWebView(frame: popupWebViewContainer.bounds, configuration: configuration)
            popupWebViewContainer.isHidden = false
            popupWebView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            popupWebView!.navigationDelegate = self
            popupWebView!.uiDelegate = self
            popupWebViewContainer.addSubview(popupWebView!)
            view.addSubview(popupWebViewContainer)
            return popupWebView!
        }
    }
    
    public func webViewDidClose(_ webView: WKWebView) {
        if webView == childPopupWebView {
            childPopupWebView = nil
            ChildPopupContainer.isHidden = true
        }else if webView == popupWebView{
            popupWebView = nil
            popupWebViewContainer.isHidden = true
        }else{
            self.webView = nil
            rootController?.dismiss(animated: true, completion: nil)
            //            webView.removeFromSuperview()
        }
    }
}

extension JioPayPGViewController: WKNavigationDelegate {
    open func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        //        showActivityIndicator(show: true)
        activityIndicator.isHidden = false
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        showActivityIndicator(show: false)
        activityIndicator.isHidden = true
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            if response.statusCode == 401 {
                errorLabel?.text = "Something went wrong, Please try again."
                view.addSubview(errorLabel!)
            }
        }
        decisionHandler(.allow)
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if error._code == NSURLErrorNotConnectedToInternet {
            
            errorLabel?.text = "No Internet connection"
            view.addSubview(errorLabel!)
        }
        showActivityIndicator(show: false)
        activityIndicator.isHidden = true
    }
    
    public func webView(_ webView: WKWebView, didFail navigation:WKNavigation!, withError error: Error) {
        if error._code == NSURLErrorNotConnectedToInternet {
            print("No Internet Error ===>", error)
        }
        showActivityIndicator(show: false)
        activityIndicator.isHidden = true
    }
}

extension Optional where Wrapped: Collection {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}

extension URL {
    public var queryParameters: [String: String]? {
        guard
            let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
            let queryItems = components.queryItems else { return nil }
        return queryItems.reduce(into: [String: String]()) { (result, item) in
            result[item.name] = item.value
        }
    }
}

extension UIColor {
    convenience init(_ hex: String, alpha: CGFloat = 1.0) {
        var cString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if cString.hasPrefix("#") { cString.removeFirst() }
        
        if cString.count != 6 {
            self.init("ff0000") // return red color for wrong hex input
            return
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        
        self.init(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                  green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                  blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                  alpha: alpha)
    }
    
}

extension Notification.Name {
    static let paymentSuccess = Notification.Name("paymentSuccess")
    static let paymentFail = Notification.Name("paymentFail")
}

extension UIViewController {
    func hideNavigationBar(animated: Bool){
        // Hide the navigation bar on the this view controller
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        
    }
    
    func showNavigationBar(animated: Bool) {
        // Show the navigation bar on other view controllers
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
}

