//
//  Robot.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 7/3/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import BirdbrainBLE

open class Robot: ManageableUARTDevice {
    public var uuid: UUID {         // Used by the Bluetooth package
        uartDevice.uuid
    }
    
  
    static public let scanFilter: UARTDeviceScanFilter = AdvertisedNamePrefixScanFilter(prefix: "FN")
    
    let type: RobotType?
    
    private var uartDevice: UARTDevice      // Required by the Bluetooth package
    
    
    public required init (blePeripheral: BLEPeripheral) {
        self.type = RobotType.getTypeFromPrefix("FN")
        self.uartDevice = BaseUARTDevice(blePeripheral: blePeripheral)
        self.uartDevice.delegate = self
        
    }
    
}



extension Robot: UARTDeviceDelegate {
    
    /* This function determines what happens when the Bluetooth device changes whether or not it is sending notifications. */
    public func uartDevice(_ device: UARTDevice, isSendingStateChangeNotifications: Bool) {
        //delegate?.finch(self, isSendingStateChangeNotifications: isSendingStateChangeNotifications)
    }
    
    /* This function determines what happens when the Bluetooth device has new data. */
    public func uartDevice(_ device: UARTDevice, newState stateData: Data) {
        /*if let rawState = RawInputState(data: stateData) {
            self.rawInputState = rawState
            
            /* Every time we get a new Bluetooth notification with sensor data, we create a new value of InputState() and pass it to the Finch delegate. */
            if let delegate = delegate {
                delegate.finch(self, sensorState: SensorState(rawState: rawState))
                
            }
        } else {
            /* If we have an error, pass that to the Finch delegate. */
            self.rawInputState?.isStale = true
            delegate?.finch(self, errorGettingState: "invalid raw state" as! Error)
        }*/
        
        
    }
    
    /* This function determines what happens when the Bluetooth devices gets an error instead of data. */
    public func uartDevice(_ device: UARTDevice, errorGettingState error: Error) {
        //self.rawInputState?.isStale = true
        //delegate?.finch(self, errorGettingState: error)
    }
}

enum RobotType {
    case Finch
    case Hummingbird
    case Microbit
    
    static func getTypeFromPrefix(_ prefix: String) -> RobotType? {
        switch prefix {
        case "FN": return .Finch
        case "BB": return .Hummingbird
        case "MB": return .Microbit
        default: return nil
        }
    }
}
