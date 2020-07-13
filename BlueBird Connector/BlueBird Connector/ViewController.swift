//
//  ViewController.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 6/30/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Cocoa
import WebKit
import BirdbrainBLE


class ViewController: NSViewController, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate {
    
    var webView = WKWebView()
    
    let robotManager: UARTDeviceManager<Robot> = UARTDeviceManager<Robot>(scanFilter: Robot.scanFilter)
    let frontendServer = FrontendServer()
    let backendServer = BackendServer()
    
    
    /*override func loadView() {
        //let config = WKWebViewConfiguration()
        //let contentController = WKUserContentController()
        //contentController.add(self.frontendServer, name: "frontendServer")
        //config.userContentController = contentController
        
        //self.webView = WKWebView(frame: self.view.bounds, configuration: config)
        //self.webView = WKWebView()
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        self.webView.navigationDelegate = self
        view = webView
    }*/

    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewdidload")
        
        print(Robot.scanFilter)
        robotManager.delegate = self
        frontendServer.setRobotManager(robotManager)
        
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self.frontendServer, name: "serverSubstitute")
        config.userContentController = contentController
        
        self.webView = WKWebView(frame: self.view.bounds, configuration: config)
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        
        guard let htmlPath = Bundle.main.path(forResource: "index", ofType: "html"), let resourceDir = Bundle.main.resourcePath else {
            NSLog("Unable to find frontend resources")
            return
        }
        
        let html = URL(fileURLWithPath: htmlPath)
        let dir = URL(fileURLWithPath: resourceDir, isDirectory: true)
        self.webView.loadFileURL(html, allowingReadAccessTo: dir)
        
        /*do {
            let htmlString = try String(contentsOfFile: htmlPath, encoding: String.Encoding.utf8)
            self.webView.loadHTMLString(htmlString, baseURL: URL(string: "http://localhost/")!)
        } catch {
            print("problem \(error)")
        }*/
        
        print("add view")
        self.view.addSubview(self.webView)
        frontendServer.setWebView(self.webView)
        
       /* let js = """
            
                window.webkit.messageHandlers.serverSubstitute.postMessage({paramter1 : "value1", parameter2 : "value2"})
            
        """
        self.webView.evaluateJavaScript(js) { (response, error) in
            if let _ = error {
                print("error: \(error)")
            }
            else {
                print("response: \(response)")
            }
        }*/
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    override func viewDidAppear() {
        view.window?.delegate = self
    }
    
    //MARK: NSWindowDelegate methods
    
    func windowDidResize(_ notification: Notification) {
        print("windowDidResize \(notification)")
        self.webView.frame = self.view.bounds
    }

    //MARK: WKNavigationDelegate methods
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("did fail provisional navigation %@", error as NSError)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("did fail navigation %@", error as NSError)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog("didFinish navigation")
        self.webView.evaluateJavaScript("alert('Hello from evaluateJavascript()')", completionHandler: nil)
    }

}


extension ViewController: UARTDeviceManagerDelegate {
    func didUpdateState(to state: UARTDeviceManagerState) {
        print("UARTDeviceManagerDelegate.didUpdateState: \(state)")
        if (state == .enabled) {
            if robotManager.startScanning() {
                print("Scanning...")
                frontendServer.notifiyScanState(isOn: true)
            }
            else {
                print("Failed to start scanning!")
            }
        }
    }

    func didDiscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {
        print("DID DISCOVER \(advertisementData)")
        if let advertisementSignature = advertisementSignature {
            print(advertisementSignature)
            robotManager.stopScanning()
        } else {
            // TODO: do something better
            print("Ignoring device \(uuid) because its advertisement signature is nil")
        }
    }

    func didRediscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {
        print("DID REDISCOVER")
    }

    func didDisappear(uuid: UUID) {
        print("DID DISAPPEAR")
    }

    func didConnectTo(uuid: UUID) {
        print("DID CONNECT TO")
    }

    func didDisconnectFrom(uuid: UUID, error: Error?) {
        print("DID DISCONNECT FROM")
    }

    func didFailToConnectTo(uuid: UUID, error: Error?) {
        print("DID FAIL TO CONNECT TO")
    }
}


