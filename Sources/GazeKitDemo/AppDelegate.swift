import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("AppDelegate: didFinishLaunchingWithOptions called")
        
        // ウィンドウを作成
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // GazeTrackingViewControllerを直接起動
        let gazeTrackingViewController = GazeTrackingViewController()
        window?.rootViewController = gazeTrackingViewController
        
        // ウィンドウを表示
        window?.makeKeyAndVisible()
        
        print("AppDelegate: Window created and made visible")
        return true
    }
}