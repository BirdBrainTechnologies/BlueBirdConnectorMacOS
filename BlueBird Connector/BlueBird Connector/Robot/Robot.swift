//
//  Robot.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 7/3/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import BirdbrainBLE
import os

open class Robot: ManageableUARTDevice {
    
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "Robot")
    
    static public let scanFilter: UARTDeviceScanFilter = AdvertisedNamePrefixesScanFilter(prefixes: ["FN", "BB", "MB"])
    static public let FINCH_TICKS_PER_CM = 49.7;
    static public let FINCH_TICKS_PER_DEGREE = 4.335;
    
    private var uartDevice: UARTDevice      // Required by the Bluetooth package
    public var uuid: UUID {         // Used by the Bluetooth package
        uartDevice.uuid
    }
    
    let type: RobotType
    let name: String
    let fancyName: String
    var notificationsRunning: Bool
    private var rawInputState: RawInputState?
    
    public required init (blePeripheral: BLEPeripheral) {
        self.uartDevice = BaseUARTDevice(blePeripheral: blePeripheral)
        
        if let adSig = self.uartDevice.advertisementSignature {
            self.name = adSig.advertisedName
            self.fancyName = adSig.memorableName ?? adSig.advertisedName
            self.type = RobotType.getTypeFromPrefix(self.name.prefix(2))
        } else {
            self.name = ""
            self.fancyName = ""
            self.type = .Unknown
        }
        
        self.notificationsRunning = self.uartDevice.startStateChangeNotifications()
        self.uartDevice.delegate = self
    }
    
 
    
    //MARK: - Public Methods
    /*  These are the functions that you will usually use to control the Robot. Most of these call a Bluetooth command that sets up the array that is sent over Bluetooth.
     */
    
    func setMotors(leftSpeed: Double, leftTicks: Int, rightSpeed: Double, rightTicks: Int) {
        
    }
    
    func setTriLED(port: Int, R: Int, G: Int, B: Int) {
        
    }
    
}



extension Robot: UARTDeviceDelegate {
    
    /* This function determines what happens when the Bluetooth device changes whether or not it is sending notifications. */
    public func uartDevice(_ device: UARTDevice, isSendingStateChangeNotifications: Bool) {
        os_log("uartDevice isSendingChangeNotifications [%s]", log: log, type: .debug, String(describing: isSendingStateChangeNotifications))
        self.notificationsRunning = isSendingStateChangeNotifications
    }
    
    /* This function determines what happens when the Bluetooth device has new data. */
    public func uartDevice(_ device: UARTDevice, newState stateData: Data) {
        guard let rawState = RawInputState(data: stateData, type: type) else {
            os_log("uartDevice [%s] state update fail", log: log, type: .error, self.type.stringDescribing)
            self.rawInputState?.isStale = true
            return
        }
        
        self.rawInputState = rawState
    }
    
    /* This function determines what happens when the Bluetooth devices gets an error instead of data. */
    public func uartDevice(_ device: UARTDevice, errorGettingState error: Error) {
        self.rawInputState?.isStale = true
        os_log("uartDevice [%s] error getting state [%s]", log: log, type: .error, device.advertisementSignature?.advertisedName ?? "unknown", error.localizedDescription)
    }
}



/* This structure contains the raw bytes sent by the Robot over Bluetooth, along with a timestamp for the data. */
public struct RawInputState {
    public let timestamp: Date
    public let data: Data
    public fileprivate(set) var isStale: Bool   // is the data old?
    
    init?(data: Data, type: RobotType) {
        if data.count == type.expectedRawStateByteCount {
            self.timestamp = Date()
            self.data = data
            self.isStale = false
        } else {
            return nil
        }
    }
}
