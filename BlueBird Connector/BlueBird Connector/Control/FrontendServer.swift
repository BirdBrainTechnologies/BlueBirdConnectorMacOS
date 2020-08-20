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
import Cocoa

class FrontendServer: NSObject, WKScriptMessageHandler {
    
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "FrontendServer")
    
    var webView: WKWebView?
    private var documentIsReady: Bool = false
    private var callbacksPending: [String] = []
    var availableDevices = [UUID: AvailableDevice]()
    var userRequestedScan: Bool = false
    var managerIsScanning: Bool = false
    var screenIsSleeping: Bool = false
    
    
    override init() {
        super.init()
        //Sign up for sleep/wake notifications
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: nil, using: screenDidWake(n:))
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: nil, using: screenDidSleep(n:))
    }
    
    /**
        Add the frontend to update
     */
    func setWebView(_ view: WKWebView) {
        webView = view
    }
    
    
    //MARK: Sleep/wake notifications
    
    /**
        When the computer falls asleep, disconnect from all robots and stop a scan if running.
        Robots will automatically reconnect with the next scan (which should start when the
        screen wakes back up).
     */
    private func screenDidSleep(n: Notification) {
        print("screenDidSleep")
        screenIsSleeping = true
        stopScan()
        
        for (_, robot) in Shared.backendServer.connectedRobots {
            let _ = Shared.robotManager.disconnectFromDevice(havingUUID: robot.uuid)
        }
    }
    /**
        When the computer wakes, if there are any robots waiting to reconnect, start a scan.
     */
    private func screenDidWake(n: Notification) {
        print("screenDidWake")
        screenIsSleeping = false
        if getAutoReconnectCount() > 0 && !managerIsScanning{
            managerIsScanning = Shared.robotManager.startScanning()
        }
    }
    
    
    //MARK: Public methods for updating the frontend
    
    /**
        Notify the frontend of a change in scanning
     */
    func notifyScanState(isOn: Bool) {
        if (isOn) {
            sendToFrontend("CallbackManager.scanStarted()")
        } else {
            sendToFrontend("CallbackManager.scanEnded()")
        }
    }
    /**
        Notify the frontend when ble has been disabled on the computer.
        When ble is enabled, a scan is automatically started, and the frontend
        is notified in that way.
     */
    func notifyBleDisabled() {
        if screenIsSleeping { return }
        sendToFrontend("CallbackManager.bleDisabled()")
    }
    /**
        A device was discovered. Update the frontend's list of discovered devices if necessary.
     */
    func notifyDeviceDiscovery(uuid: UUID, advertisementSignature: AdvertisementSignature, rssi: NSNumber) {
        if availableDevices[uuid] == nil {
            availableDevices[uuid] = AvailableDevice(uuid: uuid, advertisementSignature: advertisementSignature, rssi: rssi)
            sendAvailableDeviceUpdate()
        } else {
            updateDeviceInfo(uuid: uuid, adSig: advertisementSignature, rssi: rssi)
        }
    }
    /**
        Notify the frontend that a device that was previously available, has not been seen in a while.
     */
    func notifyDeviceDidDisappear(uuid: UUID) {
        //if !(availableDevices[uuid]?.shouldAutoConnect ?? false) {
        if availableDevices[uuid]?.shouldAutoConnectAs == nil {
            availableDevices[uuid] = nil
        }
        
        sendAvailableDeviceUpdate()
    }
    /**
        Notify the frontend of a new device connection. Flag the device as connected.
     */
    func notifyDeviceDidConnect(uuid: UUID, name: String, fancyName: String, deviceLetter: DeviceLetter) {
        availableDevices[uuid]?.isConnected = true
        availableDevices[uuid]?.shouldAutoConnectAs = deviceLetter
        
        sendAvailableDeviceUpdate()
        if getAutoReconnectCount() == 0 {
            stopScan()
        }
        
        let args = "'" + uuid.uuidString + "', '" + name + "', '" + fancyName + "', '" + deviceLetter.toString() + "'"
        let js = "CallbackManager.deviceDidConnect(" + args + ")"
        sendToFrontend(js)
    }
    /**
        Notify the frontend of a device disconnection. Flag the device as disconnected.
        If the user did not request this disconnection, flag the device for auto reconnect.
     */
    func notifyDeviceDidDisconnect(uuid: UUID) {
        guard let device = availableDevices[uuid] else {
            os_log("Disconnected from unknown device", log: log, type: .error)
            return
        }
        availableDevices[uuid]?.isConnected = false
        
        if (device.shouldAutoConnectAs != nil) {
            os_log("User did not request disconnect. Attempting to reconnect automatically. Screen is sleeping? [%s] Manager is scanning? [%s]", log: log, type: .debug, String(screenIsSleeping), String(managerIsScanning))
            
            
            //if the screen is sleeping, it will start the scan when it wakes.
            if !screenIsSleeping && !managerIsScanning {
                //Do not notify the frontend of this scan, just scan in the background and try to find it
                os_log("Starting scan.", log: log, type: .debug)
                managerIsScanning = Shared.robotManager.startScanning()
            }
        }
        
        let args = "'" + uuid.uuidString + "'"
        let js = "CallbackManager.deviceDidDisconnect(" + args + ")"
        sendToFrontend(js)
    }
    /**
        Notify the frontend of a change in battery state for the given device.
     */
    func notifyDeviceBatteryUpdate(uuid: UUID, newState: BatteryStatus) {
        let args = "'" + uuid.uuidString + "', '" + newState.description + "'"
        let js = "CallbackManager.deviceBatteryUpdate(" + args + ")"
        sendToFrontend(js)
    }
    /**
        Update the device's info if there is a change. Called on device rediscovery.
     */
    func updateDeviceInfo(uuid: UUID, adSig: AdvertisementSignature?, rssi: NSNumber) {
        guard let device = availableDevices[uuid] else {
            os_log("Rediscovered unknown device?", log: log, type: .error)
            return
        }
        
        if device.shouldAutoConnectAs != nil {
            //This device was connected. Disconnect has not been requested by the user
            // so we will automatically reconnect on rediscovery.
            let _ = Shared.robotManager.connectToDevice(havingUUID: uuid)
        } else {
            var sendUpdate = false
            //only update the advertisement signature if the advertised name changes
            if let sig = adSig, availableDevices[uuid]?.advertisementSignature.advertisedName != sig.advertisedName {
                availableDevices[uuid]?.advertisementSignature = sig
                sendUpdate = true
            }
            if (rssi.intValue > (device.rssi.intValue + 30)) ||
                (rssi.intValue < device.rssi.intValue - 30) {
                availableDevices[uuid]?.rssi = rssi
                sendUpdate = true
            }
            if sendUpdate { sendAvailableDeviceUpdate() }
        }
    }
    /**
        Notify the frontend that magnetometer calibration has finished and give the result.
     */
    func notifyCalibrationResult(_ success: Bool) {
        let js = "CallbackManager.showCalibrationResult(" + String(success) + ")"
        sendToFrontend(js)
    }
    
    
    //MARK: Utility methods
    
    /**
        Update frontend's the list of available devices. Called when a device is discovered, disappeared,
        or information is updated. Also called at the start of a scan to refresh the list.
     */
    private func sendAvailableDeviceUpdate() {
        guard userRequestedScan else { return }
        
        var args = "[ "
        availableDevices.forEach{(uuid, device) in
            if !(device.isConnected || (device.shouldAutoConnectAs != nil)) {
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
    /**
        Send update to frontend
     */
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
    /**
        Stop scanning for devices
     */
    func stopScan() {
        userRequestedScan = false
        guard managerIsScanning else {
            os_log("stopScan called when no scan is running", log: log, type: .debug)
            return
        }
        
        if Shared.robotManager.stopScanning() {
            managerIsScanning = false
            notifyScanState(isOn: false)
        } else {
            os_log("Failed to stop scanning!", log: log, type: .error)
        }
    }
    /**
        Start scanning for devices. Called when the user clicks the find robots button, but also
        when ble is enabled (which happens when the app starts up if ble is already on, and
        tends to happen periodically while the computer sleeps).
     */
    func startScan() {
        //Do not scan if screen is asleep
        if screenIsSleeping { return }
        
        //we assume that the user is requesting a scan when they turn on ble
        userRequestedScan = true
        
        if !managerIsScanning {
            managerIsScanning = Shared.robotManager.startScanning()
        } else {
            os_log("startScan called when scan was already running", log: log, type: .debug)
        }
        
        //If a scan was already running, we don't need to start a scan, but we still
        // want to notify the frontend
        if managerIsScanning {
            os_log("Scanning...", log: log, type: .debug)
            notifyScanState(isOn: true)
            sendAvailableDeviceUpdate()
        }
    }
    /**
        Get a count of how many devices would autoreconnect on discovery
     */
    private func getAutoReconnectCount() -> Int {
        var count = 0
        for (_, device) in availableDevices {
            if !device.isConnected && device.shouldAutoConnectAs != nil {
                count += 1
            }
        }
        return count
    }
    
    
    //MARK: WKScriptMessageHandler method
    
    /**
        Receive messages from the frontend.
     */
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
                case "calibrate":
                    handleCalibrateCommand(body)
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
    
    
    //MARK: Handlers for messages coming in from the frontend
    
    /**
        Handle requests to start or stop scanning
     */
    private func handleScanCommand(_ fullCommand: NSDictionary) {
        guard let scanState = fullCommand["scanState"] as? String else {
            os_log("Scan state not specified", log: log, type: .error)
            return
        }
        
        switch scanState {
        case "on":
            startScan()
        case "off":
            stopScan()
        default:
            os_log("unknown scan state [%s]", log: log, type: .error, scanState)
        }
    }
    /**
        Handle requests to connect to a robot
     */
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
    /**
        Handle requests to disconnect from a robot
     */
    func handleDisconnectCommand(_ fullCommand: NSDictionary) {
        guard let uuidString = fullCommand["address"] as? String,
            let uuid = UUID(uuidString: uuidString) else {
            os_log("Improperly formed disconnect command", log: log, type: .error)
            print(fullCommand)
            return
        }
        availableDevices[uuid]?.shouldAutoConnectAs = nil
        
        let _ = Shared.robotManager.disconnectFromDevice(havingUUID: uuid)
    }
    /**
        Handle requests to open snap
     */
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
            urlString = "http://localhost:30061/snap/snap.html#open:snapProjects/" + projectName + ".xml&editMode&lang=" + language;
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
    /**
        Handle requests to calibrate a robot
     */
    func handleCalibrateCommand(_ fullCommand: NSDictionary) {
        guard let devLetter = fullCommand["devLetter"] as? String else {
            os_log("Poorly formed calibrate command", log: log, type: .error)
            print(fullCommand)
            return
        }
        
        Shared.backendServer.calibrateRobot(devLetter: devLetter)
    }
    
}

/* Structure that represents the available Robots. */
struct AvailableDevice {
    let uuid: UUID
    var advertisementSignature: AdvertisementSignature
    var rssi: NSNumber
    var isConnected: Bool
    
    //if not nil, auto reconnect and use this device letter if possible
    var shouldAutoConnectAs: DeviceLetter?
    
    init(uuid: UUID, advertisementSignature: AdvertisementSignature, rssi: NSNumber) {
        self.uuid = uuid
        self.rssi = rssi
        self.advertisementSignature = advertisementSignature
        self.isConnected = false
    }
}
