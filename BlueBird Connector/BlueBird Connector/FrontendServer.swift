//
//  FrontendServer.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 6/30/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import WebKit
import BirdbrainBLE

class FrontendServer: NSObject, WKScriptMessageHandler {
    
    var robotManager: UARTDeviceManager<Robot>?
    var webView: WKWebView?
    var documentIsReady: Bool = false
    var callbacksPending: [String] = []
    
    func setRobotManager(_ manager: UARTDeviceManager<Robot>) {
        robotManager = manager
    }
    
    func setWebView(_ view: WKWebView) {
        webView = view
    }
    
    func notifiyScanState(isOn: Bool) {
        if (isOn) {
            sendToFrontend("CallbackManager.scanStarted()")
        } else {
            sendToFrontend("CallbackManager.scanEnded()")
        }
    }
    
    private func sendToFrontend(_ javascript: String) {
        if !documentIsReady {
            callbacksPending.append(javascript)
            return
        }
        
        guard let webView = webView else {
            print("Cannot send frontend messages until webview is setup")
            return
        }
        
        //TODO: Do we need to submit this to a dispatch queue like in birdblox?
        webView.evaluateJavaScript(javascript) { (response, error) in
            if let error = error {
                print(error)
            } else if let response = response {
                print("response: \(response)")
            }
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        guard let body = message.body as? NSDictionary, let type = body["type"] as? String else {
            print("no message body")
            return
        }
        
        switch (type) {
        case "console log" :
            guard let logMsg = body["consoleLog"] else {
                print("Mis-formed console message")
                print(body)
                return
            }
            print("WebView console log: \(logMsg)")
        case "document status":
            if let documentStatus = body["documentStatus"] as? String {
                switch(documentStatus) {
                case "READY":
                    print("DOCUMENT READY")
                    documentIsReady = true
                    callbacksPending.forEach { callback in
                        sendToFrontend(callback)
                    }
                case "onresize":
                    print("webview has resized")
                    print(body)
                default:
                    print("unrecognized document status " + documentStatus)
                }
                
            }
        case "command":
            if let command = body["command"] as? String {
                switch command {
                case "scan":
                    handleScanCommand(body)
                default:
                    print("Command not found \(command)")
                }
            }
        case "error":
            print(body)
        default:
            print("Unrecognized frontend message: ")
            print(body)
        }
        
    }
    
    func handleScanCommand(_ fullCommand: NSDictionary) {
        guard let scanState = fullCommand["scanState"] as? String else {
            print("Scan state not specified")
            return
        }
        guard let robotManager = robotManager else {
            print("cannot update scan state until robot manager has been set")
            return
        }
        
        switch scanState {
        case "on":
            robotManager.startScanning()
            notifiyScanState(isOn: true)
        case "off":
            robotManager.stopScanning()
            notifiyScanState(isOn: false)
        default:
            print("unknown scan state \(scanState)")
        }
    }
    
}
