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
import os

class FrontendServer: NSObject, WKScriptMessageHandler {
    
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "FrontendServer")
    
    var webView: WKWebView?
    var documentIsReady: Bool = false
    var callbacksPending: [String] = []
    var availableDevices = [UUID: AvailableDevice]()
    
    
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
    
    func notifyBleDisabled() {
        sendToFrontend("CallbackManager.bleDisabled()")
    }
    
    func notifyDeviceDiscovery(uuid: UUID, advertisementSignature: AdvertisementSignature, rssi: NSNumber) {
        availableDevices[uuid] = AvailableDevice(uuid: uuid, advertisementSignature: advertisementSignature, rssi: rssi)
        
        /*let fancyName = advertisementSignature.memorableName ?? advertisementSignature.advertisedName
        let args = "'" + uuid.uuidString + "', '" + advertisementSignature.advertisedName + "', '" + fancyName + "', " + rssi.stringValue
        let js = "CallbackManager.deviceDiscovered(" + args + ")"
        sendToFrontend(js)*/
        sendAvailableDeviceUpdate()
    }
    
    func notifyDeviceDidDisappear(uuid: UUID) {
        availableDevices[uuid] = nil
        //let args = "'" + uuid.uuidString + "'"
        //let js = "CallbackManager.deviceDidDisappear(" + args + ")"
        //sendToFrontend(js)
        sendAvailableDeviceUpdate()
    }
    
    func notifyDeviceDidConnect(uuid: UUID, name: String, fancyName: String, deviceLetter: DeviceLetter) {
        availableDevices[uuid]?.isConnected = true
        
        let args = "'" + uuid.uuidString + "', '" + name + "', '" + fancyName + "', '" + deviceLetter.toString() + "'"
        let js = "CallbackManager.deviceDidConnect(" + args + ")"
        sendToFrontend(js)
    }
    
    func notifyDeviceDidDisconnect(uuid: UUID) {
        availableDevices[uuid]?.isConnected = false
        
        let args = "'" + uuid.uuidString + "'"
        let js = "CallbackManager.deviceDidDisconnect(" + args + ")"
        sendToFrontend(js)
    }
    
    func notifyDeviceBatteryUpdate(uuid: UUID, newState: BatteryStatus) {
        let args = "'" + uuid.uuidString + "', '" + newState.description + "'"
        let js = "CallbackManager.deviceBatteryUpdate(" + args + ")"
        sendToFrontend(js)
    }
    
    func updateDeviceRSSI(uuid: UUID, rssi: NSNumber) {
        guard let device = availableDevices[uuid] else {
            os_log("Rediscovered unknown device?", log: log, type: .error)
            return
        }
        if (rssi.intValue > (device.rssi.intValue + 20)) || (rssi.intValue < device.rssi.intValue - 20) {
            availableDevices[uuid]?.rssi = rssi
            sendAvailableDeviceUpdate()
        }
    }
    func sendAvailableDeviceUpdate() {
        var args = "[ "
        availableDevices.forEach{(uuid, device) in
            if !(device.isConnected) {
                let fancyName = device.advertisementSignature.memorableName ?? device.advertisementSignature.advertisedName
                args += "{address: '" + device.uuid.uuidString +
                    "', name: '" + device.advertisementSignature.advertisedName +
                    "', fancyName: '" + fancyName +
                    "', rssi: " + device.rssi.stringValue +
                    "},"
            }
        }
        args = args.dropLast() + "]"
        let js = "CallbackManager.updateScanDeviceList(" + args + ")"
        sendToFrontend(js)
    }
    
    private func sendToFrontend(_ javascript: String) {
        if !documentIsReady {
            callbacksPending.append(javascript)
            return
        }
        
        guard let webView = webView else {
            os_log("Cannot send frontend messages until webview is setup", log: log, type: .error)
            return
        }
        
        os_log("eval js on frontend: [%s]", log: log, type: .debug, javascript)
        
        //TODO: Do we need to submit this to a dispatch queue like in birdblox?
        webView.evaluateJavaScript(javascript) { (response, error) in
            if let error = error {
                os_log("Error evaluating javascript: [%s]", log: self.log, type: .error, error.localizedDescription)
            } else if let _ = response {
                os_log("Javascript eval response received", log: self.log, type: .debug)
            }
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        guard let body = message.body as? NSDictionary, let type = body["type"] as? String else {
            os_log("Message received from frontend was not formatted correctly", log: log, type: .error)
            return
        }
        
        switch (type) {
        case "console log" :
            guard let logMsg = body["consoleLog"] as? String else {
                os_log("Console log message missing", log: log, type: .error)
                print(body)
                return
            }
            os_log("WebView console log: [%s]", log: log, type: .debug, logMsg)
        case "document status":
            if let documentStatus = body["documentStatus"] as? String {
                switch(documentStatus) {
                case "READY":
                    os_log("DOCUMENT READY", log: log, type: .debug)
                    documentIsReady = true
                    callbacksPending.forEach { callback in
                        sendToFrontend(callback)
                    }
                case "onresize":
                    os_log("webview has resized", log: log, type: .debug)
                default:
                    os_log("unrecognized document status [%s]", log: log, type: .error, documentStatus)
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
                case "openSnap":
                    handleOpenSnapCommand(body)
                default:
                    os_log("Command not found [%s]", log: log, type: .error, command)
                }
            }
        case "error":
            os_log("A javascript error occurred", log: log, type: .error)
            print(body)
        default:
            os_log("Unrecognized frontend message", log: log, type: .error)
            print(body)
        }
        
    }
    
    func handleScanCommand(_ fullCommand: NSDictionary) {
        guard let scanState = fullCommand["scanState"] as? String else {
            os_log("Scan state not specified", log: log, type: .error)
            return
        }
        
        switch scanState {
        case "on":
            startScan()
        case "off":
            if Shared.robotManager.stopScanning() {
                notifiyScanState(isOn: false)
            } else {
                os_log("Failed to stop scanning!", log: log, type: .error)
            }
            
        default:
            os_log("unknown scan state [%s]", log: log, type: .error, scanState)
            
        }
    }
    
    func startScan() {
        if Shared.robotManager.startScanning() {
            os_log("Scanning...", log: log, type: .debug)
            notifiyScanState(isOn: true)
            /*availableDevices.forEach{(uuid, device) in
                if !(device.isConnected) {
                    notifyDeviceDiscovery(uuid: uuid, advertisementSignature: device.advertisementSignature, rssi: device.rssi)
                }
            }*/
            sendAvailableDeviceUpdate()
        } else {
            os_log("Failed to start scanning!", log: log, type: .error)
        }
    }
    
    func handleConnectCommand(_ fullCommand: NSDictionary) {
        guard let address = fullCommand["address"] as? String,
            let uuid = UUID(uuidString: address) else {
            os_log("Improperly formed connect command", log: log, type: .error)
            print(fullCommand)
            return
        }
        os_log("connect to [%s]", log: log, type: .debug, address)
        let _ = Shared.robotManager.connectToDevice(havingUUID: uuid)
    }
    
    func handleDisconnectCommand(_ fullCommand: NSDictionary) {
        guard let devLetter = fullCommand["devLetter"] as? String,
            let uuidString = fullCommand["address"] as? String,
            let uuid = UUID(uuidString: uuidString) else {
            os_log("Improperly formed disconnect command", log: log, type: .error)
            print(fullCommand)
            return
        }
        
        let _ = Shared.robotManager.disconnectFromDevice(havingUUID: uuid)
    }
    
    func handleOpenSnapCommand(_ fullCommand: NSDictionary) {
        
        guard let projectName = fullCommand["project"] as? String,
            let openOnline = fullCommand["online"] as? Bool,
            let language = fullCommand["language"] as? String else {
                os_log("Poorly formed open snap command", log: log, type: .error)
                print(fullCommand)
                return
        }
        
        var urlString = ""
        if (openOnline) {
            urlString = "https://snap.berkeley.edu/snap/snap.html#present:Username=birdbraintech&ProjectName=" + projectName + "&editMode&lang=" + language;
        } else {
            urlString = "snap/snap.html#open:snapProjects/" + projectName + ".xml&editMode&lang=" + language;
        }
        guard let url = URL(string: urlString) else {
            os_log("Bad url string [%s]", log: log, type: .error, urlString)
            return
        }
        
        //if on 10.15 or later, we can open in chrome specifically, if available
        if #available(OSX 10.15, *), let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
            os_log("Opening snap! at [%s] in chrome at [%s]", log: log, type: .debug, url.absoluteString, chromeURL.absoluteString)
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: chromeURL, configuration: configuration)
        } else {
            if NSWorkspace.shared.open(url) {
                os_log("Opened snap! at [%s]", log: log, type: .debug, url.absoluteString)
            } else {
                os_log("Failed to open snap! at [%s]", log: log, type: .error, url.absoluteString)
            }
        }
        
        
    }
    
}

/* Structure that represents the available Robots. */
struct AvailableDevice {
    let uuid: UUID
    let advertisementSignature: AdvertisementSignature
    var rssi: NSNumber
    var isConnected: Bool
    
    init(uuid: UUID, advertisementSignature: AdvertisementSignature, rssi: NSNumber) {
        self.uuid = uuid
        self.rssi = rssi
        self.advertisementSignature = advertisementSignature
        self.isConnected = false
    }
}
