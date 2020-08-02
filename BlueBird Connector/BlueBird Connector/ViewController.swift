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
import os


class ViewController: NSViewController, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate {
    
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "ViewController")
    
    var webView = WKWebView()
    /*
    let robotManager: UARTDeviceManager<Robot>
    let frontendServer: FrontendServer
    let backendServer: BackendServer
    
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        robotManager = UARTDeviceManager<Robot>(scanFilter: Robot.scanFilter)
        frontendServer = FrontendServer(robotManager: robotManager)
        backendServer = BackendServer()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    required init?(coder: NSCoder) {
        robotManager = UARTDeviceManager<Robot>(scanFilter: Robot.scanFilter)
        frontendServer = FrontendServer(robotManager: robotManager)
        backendServer = BackendServer()
        super.init(coder: coder)
    }
    */
    
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("viewdidload", log: log, type: .debug)
        
        //let delegate = RobotManagerDelegate(frontendServer: frontendServer, robotManager: robotManager, backendServer: backendServer)
        let delegate = RobotManagerDelegate()
        Shared.robotManager.delegate = delegate
        
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(Shared.frontendServer, name: "serverSubstitute")
        config.userContentController = contentController
        
        self.webView = WKWebView(frame: self.view.bounds, configuration: config)
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        
        guard let htmlPath = Bundle.main.path(forResource: "index", ofType: "html"), let resourceDir = Bundle.main.resourcePath else {
            os_log("Unable to find frontend resources", log: log, type: .error)
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
        
        self.view.addSubview(self.webView)
        Shared.frontendServer.setWebView(self.webView)
        
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
        os_log("windowDidResize", log: log, type: .debug)
        self.webView.frame = self.view.bounds
    }

    //MARK: WKNavigationDelegate methods
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("did fail provisional navigation %@", error as NSError)
        os_log("did fail provisional navigation: [%s]", log: log, type: .error, error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("did fail navigation %@", error as NSError)
        os_log("did fail navigation: [%s]", log: log, type: .error, error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        os_log("didFinish navigation", log: log, type: .debug)
        self.webView.evaluateJavaScript("alert('Hello from evaluateJavascript()')", completionHandler: nil)
    }

}

