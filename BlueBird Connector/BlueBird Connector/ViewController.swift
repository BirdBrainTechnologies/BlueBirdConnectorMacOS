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
    
    let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "ViewController")
    
    var webView = WKWebView()
    
    let robotManager: UARTDeviceManager<Robot> = UARTDeviceManager<Robot>(scanFilter: Robot.scanFilter)
    let frontendServer = FrontendServer()
    let backendServer = BackendServer()
    
    var connectedRobots = [DeviceLetter: Robot]()
    
    
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
        os_log("viewdidload", log: log, type: .debug)
        
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


extension ViewController: UARTDeviceManagerDelegate {
    func didUpdateState(to state: UARTDeviceManagerState) {
        os_log("UARTDeviceManagerDelegate.didUpdateState to: [%s]", log: log, type: .debug, state.rawValue)
        switch state {
        case .enabled:
            if robotManager.startScanning() {
                os_log("Scanning...", log: log, type: .debug)
                frontendServer.notifiyScanState(isOn: true)
            } else {
                os_log("Failed to start scanning!", log: log, type: .error)
            }
        case .disabled:
            os_log("manager disabled", log: log, type: .debug)
        case .error:
            os_log("manager error", log: log, type: .error)
        }
    }

    func didDiscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {
        
        os_log("DID DISCOVER [%s]", log: log, type: .debug, advertisementSignature?.advertisedName ?? "unknown")
        guard let advertisementSignature = advertisementSignature else {
            os_log("Ignoring device [%s] because it is missing advertisement info.", log: log, type: .debug, uuid.uuidString)
            return
        }
        
        frontendServer.notifyDeviceDiscovery(uuid: uuid, advertisementSignature: advertisementSignature, rssi: rssi)
        
    }

    func didRediscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {
        os_log("DID REDISCOVER [%s]", log: log, type: .debug, advertisementSignature?.advertisedName ?? "unknown")
    }

    func didDisappear(uuid: UUID) {
        os_log("DID DISAPPEAR [%s]", log: log, type: .debug, uuid.uuidString)
        frontendServer.notifyDeviceDidDisappear(uuid: uuid)
    }

    func didConnectTo(uuid: UUID) {
        os_log("DID CONNECT TO [%s]", log: log, type: .debug, uuid.uuidString)
        guard let robot = robotManager.getDevice(uuid: uuid), let adSig = frontendServer.availableDevices[uuid]?.advertisementSignature else {
            os_log("Connected robot not found with uuid [%s]", log: log, type: .error, uuid.uuidString)
            return
        }
        robot.setAdvertisementSignature(adSig)
        
        let fancyName = adSig.memorableName ?? adSig.advertisedName
        var letterAssigned = false
        for devLetter in DeviceLetter.allCases {
            if !letterAssigned && connectedRobots[devLetter] == nil {
                connectedRobots[devLetter] = robot
                letterAssigned = true
                frontendServer.notifyDeviceDidConnect(uuid: uuid, name: adSig.advertisedName, fancyName: fancyName, deviceLetter: devLetter)
            }
        }
        
        if !letterAssigned {
            os_log("Too many connections", log: log, type: .error)
            let _ = robotManager.disconnectFromDevice(havingUUID: uuid)
        }
    }

    func didDisconnectFrom(uuid: UUID, error: Error?) {
        os_log("DID DISCONNECT FROM [%s]", log: log, type: .debug, uuid.uuidString)
        if let error = error {
            os_log("Error: [%s]", log: log, type: .error, error.localizedDescription)
        }
        
        for (letter, robot) in connectedRobots {
            if robot.uuid == uuid {
                connectedRobots[letter] = nil
                frontendServer.notifyDeviceDidDisconnect(uuid: uuid)
            }
        }
    }

    func didFailToConnectTo(uuid: UUID, error: Error?) {
        os_log("DID FAIL TO CONNECT TO [%s] with error [%s]", log: log, type: .error, uuid.uuidString, error?.localizedDescription ?? "no error")
    }
}

enum DeviceLetter: CaseIterable {
    case A, B, C
    
    func toString() -> String {
        switch self{
        case .A: return "A"
        case .B: return "B"
        case .C: return "C"
        }
    }
}
