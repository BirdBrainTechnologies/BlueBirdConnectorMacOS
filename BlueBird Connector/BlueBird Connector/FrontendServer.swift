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
    var availableDevices = [UUID: AvailableDevice]()
    
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
    
    func notifyDeviceDiscovery(uuid: UUID, advertisementSignature: AdvertisementSignature, rssi: NSNumber) {
        availableDevices[uuid] = AvailableDevice(uuid: uuid, advertisementSignature: advertisementSignature, rssi: rssi)
        
        let fancyName = advertisementSignature.memorableName ?? advertisementSignature.advertisedName
        let args = "'" + uuid.uuidString + "', '" + advertisementSignature.advertisedName + "', '" + fancyName + "', " + rssi.stringValue
        let js = "CallbackManager.deviceDiscovered(" + args + ")"
        sendToFrontend(js)
    }
    
    func notifyDeviceDidDisappear(uuid: UUID) {
        availableDevices[uuid] = nil
        let args = "'" + uuid.uuidString + "'"
        let js = "CallbackManager.deviceDidDisappear(" + args + ")"
        sendToFrontend(js)
    }
    
    func notifyDeviceDidConnect(uuid: UUID, name: String, fancyName: String, deviceLetter: DeviceLetter) {
        let args = "'" + uuid.uuidString + "', '" + name + "', '" + fancyName + "', '" + deviceLetter.toString() + "'"
        let js = "CallbackManager.deviceDidConnect(" + args + ")"
        sendToFrontend(js)
    }
    
    func notifyDeviceDidDisconnect(uuid: UUID) {
        let args = "'" + uuid.uuidString + "'"
        let js = "CallbackManager.deviceDidDisconnect(" + args + ")"
        sendToFrontend(js)
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
        
        print("eval js on frontend: " + javascript)
        
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
                case "connect":
                    handleConnectCommand(body)
                case "disconnect":
                    handleDisconnectCommand(body)
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
            availableDevices.forEach{(uuid, device) in
                notifyDeviceDiscovery(uuid: uuid, advertisementSignature: device.advertisementSignature, rssi: device.rssi)
            }
            notifiyScanState(isOn: true)
        case "off":
            robotManager.stopScanning()
            notifiyScanState(isOn: false)
        default:
            print("unknown scan state \(scanState)")
        }
    }
    
    func handleConnectCommand(_ fullCommand: NSDictionary) {
        guard let robotManager = robotManager else {
            print("cannot connect to robots until robot manager has been set")
            return
        }
        guard let address = fullCommand["address"] as? String,
            let devLetter = fullCommand["devLetter"] as? String,
            let uuid = UUID(uuidString: address) else {
            print("Improperly formed connect command ", fullCommand)
            return
        }
        print("connect to ", address)
        let _ = robotManager.connectToDevice(havingUUID: uuid)
    }
    
    func handleDisconnectCommand(_ fullCommand: NSDictionary) {
        guard let robotManager = robotManager else {
            print("cannot connect to robots until robot manager has been set")
            return
        }
        guard let devLetter = fullCommand["devLetter"] as? String,
            let uuidString = fullCommand["address"] as? String,
            let uuid = UUID(uuidString: uuidString) else {
            print("Improperly formed disconnect command ", fullCommand)
            return
        }
        
        let _ = robotManager.disconnectFromDevice(havingUUID: uuid)
    }
    
}

/* Structure that represents the available Robots. */
struct AvailableDevice {
    let uuid: UUID
    let advertisementSignature: AdvertisementSignature
    let rssi: NSNumber
    
    init(uuid: UUID, advertisementSignature: AdvertisementSignature, rssi: NSNumber) {
        self.uuid = uuid
        self.rssi = rssi
        self.advertisementSignature = advertisementSignature
    }
}
