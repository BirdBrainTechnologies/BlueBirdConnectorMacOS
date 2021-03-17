//
//  ManageableRobot.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 8/2/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import BirdbrainBLE
import os

class ManageableRobot: ManageableUARTDevice {

    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "ManageableRobot")
    
    static public let scanFilter: UARTDeviceScanFilter = AdvertisedNamePrefixesScanFilter(prefixes: ["FN", "BB", "MB"])
    private var getFirmwareVersionCommand: [UInt8] {
        if type == .Finch {
            return [0xD4]
        } else {
            return [0xCF, 0xFF, 0xFF, 0xFF]
        }
    }
    static private let startNotificationsCommand: [UInt8] = [0x62, 0x67]
    static private let startV2NotificationsCommand: [UInt8] = [0x62, 0x70]
    
    private var uartDevice: UARTDevice      // Required by the Bluetooth package
    public var uuid: UUID {         // Used by the Bluetooth package
        uartDevice.uuid
    }
    public var advertisementSignature: AdvertisementSignature? {
        uartDevice.advertisementSignature
    }
    
    var notificationsRunning: Bool
    private var rawInputState: RawInputState?
    public var rawInputData: Data? {
        return rawInputState?.data
    }
    private var batteryStatus: BatteryStatus?
    public var battery: BatteryStatus {
        batteryStatus ?? BatteryStatus.unknown
    }
    private var type: RobotType
    private var isCalibrating: Bool
    private var microbitV2Found: Bool?
    public var hasV2Microbit: Bool {
        microbitV2Found ?? false
    }
    public var microbitVersionDetected: Bool {
        microbitV2Found != nil
    }
    
    public required init (blePeripheral: BLEPeripheral) {
        self.uartDevice = BaseUARTDevice(blePeripheral: blePeripheral)
        self.notificationsRunning = self.uartDevice.startStateChangeNotifications()
        let prefix = self.uartDevice.advertisementSignature?.advertisedName.prefix(2) ?? ""
        self.type = RobotType.getTypeFromPrefix(prefix)
        self.isCalibrating = false
        self.uartDevice.delegate = self
    }
    
    //func sendData(_ data: Data) {
        //uartDevice.writeWithoutResponse(data: data)
    func sendData(_ bytes: [UInt8]) {
        print(bytes)
        uartDevice.writeWithoutResponse(bytes: bytes)
    }
    
    func startCalibration() {
        sendData(RobotConstants.CALIBRATE_COMMAND)
        //Give calibration a chance to start. Otherwise, we will read an
        // old calibration result in the notification data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isCalibrating = true
        }
    }
    
}


extension ManageableRobot: UARTDeviceDelegate {
    
    /* This function determines what happens when the Bluetooth device changes whether or not it is sending notifications. */
    public func uartDevice(_ device: UARTDevice, isSendingStateChangeNotifications: Bool) {
        os_log("uartDevice isSendingChangeNotifications [%{public}s]", log: log, type: .debug, String(describing: isSendingStateChangeNotifications))
        self.notificationsRunning = isSendingStateChangeNotifications
    }
    
    /* This function determines what happens when the Bluetooth device has new data. */
    public func uartDevice(_ device: UARTDevice, newState stateData: Data) {
        
        //Get the firmware version before accepting sensor data. For some reason, the firmware
        // version of V2 microbits cannot be read unless sensor polling is started first.
        guard microbitV2Found != nil else {
            //print(Array(stateData))
            
            if stateData.count > 5 {
                sendData(getFirmwareVersionCommand)
            } else if stateData.count > 3 {
                microbitV2Found = (stateData[3] == 0x22)
            } else {
                microbitV2Found = false
            }
            
            if hasV2Microbit {
                os_log("micro:bit V2 detected for [%{public}s]", log: log, type: .debug, self.advertisementSignature?.advertisedName ?? "unknown")
                sendData(ManageableRobot.startV2NotificationsCommand)
            } else if microbitV2Found != nil {
                os_log("micro:bit for [%{public}s] is not a V2", log: log, type: .debug, self.advertisementSignature?.advertisedName ?? "unknown")
            } else {
                os_log("waiting for [%{public}s] firmware version data", log: log, type: .debug, self.advertisementSignature?.advertisedName ?? "unknown")
            }
            
            return
        }
        
        
        guard let rawState = RawInputState(data: stateData, type: type, hasV2: hasV2Microbit) else {
            os_log("uartDevice [%{public}s] state update fail", log: log, type: .error, self.advertisementSignature?.advertisedName ?? "unknown")
            self.rawInputState?.isStale = true
            return
        }
        
        self.rawInputState = rawState
        
        //Check the state of compass calibration
        if self.isCalibrating {
            var index = 7
            if type == .Finch { index = 16 }
            let byte = rawState.data[index]
            let bits = byteToBits(byte)
            os_log("CALIBRATION VALUES %{public}d %{public}d", log: log, type: .debug, bits[2], bits[3])
            
            if bits[3] == 1 {
                self.isCalibrating = false
                os_log("CALIBRATION FAILED %{public}s", log: log, type: .debug, bits.description)
                Shared.frontendServer.notifyCalibrationResult(false)
            } else if bits[2] == 1 {
                self.isCalibrating = false
                os_log("CALIBRATION SUCCESSFUL %{public}s", log: log, type: .debug, bits.description)
                Shared.frontendServer.notifyCalibrationResult(true)
            } else {
                os_log("CALIBRATION UNKNOWN %{public}s", log: log, type: .debug, bits.description)
            }
        }
        
        //Check battery status.
        if let i = type.batteryVoltageIndex, let greenThreshold = type.batteryGreenThreshold, let yellowThreshold = type.batteryYellowThreshold {
            //let voltage = rawToVoltage( lastSensorUpdate[i] )
            let voltage = (Double(rawState.data[i]) + self.type.batteryConstant) * self.type.rawToBatteryVoltage
            
            
            let newStatus: BatteryStatus
            if hasV2Microbit && self.type == .Finch {
                var val = rawState.data[i] & 0x3
                if val == 3 { val = 2 } //3 is finch full charge - not currently handled
                guard let status = BatteryStatus(rawValue: Int(val)) else {
                    NSLog("Unknown battery status \(val)")
                    return
                }
                newStatus = status
            } else {
                switch self.battery {
                case .green, .full: //TODO: handle a threshold for full charge?
                    if voltage < yellowThreshold {
                        newStatus = .red
                    } else if voltage < greenThreshold - 0.05 {
                        newStatus = .yellow
                    } else {
                        newStatus = .green
                    }
                case .yellow:
                    if voltage > greenThreshold + 0.05 {
                        newStatus = .green
                    } else if voltage < yellowThreshold - 0.05 {
                        newStatus = .red
                    } else {
                        newStatus = .yellow
                    }
                case .red:
                    if voltage > greenThreshold {
                        newStatus = .green
                    } else if voltage > yellowThreshold + 0.05 {
                        newStatus = .yellow
                    } else {
                        newStatus = .red
                    }
                case .unknown:
                    if voltage > greenThreshold {
                        newStatus = .green
                    } else if voltage > yellowThreshold {
                        newStatus = .yellow
                    } else {
                        newStatus = .red
                    }
                }
            }
            
            if self.batteryStatus != newStatus {
                self.batteryStatus = newStatus
                //let _ = FrontendCallbackCenter.shared.robotUpdateBattery(id: self.peripheral.identifier.uuidString, batteryStatus: newStatus.rawValue)
                Shared.frontendServer.notifyDeviceBatteryUpdate(uuid: uuid, newState: newStatus)
            }
        }
    }
    
    /* This function determines what happens when the Bluetooth devices gets an error instead of data. */
    public func uartDevice(_ device: UARTDevice, errorGettingState error: Error) {
        self.rawInputState?.isStale = true
        os_log("uartDevice [%{public}s] error getting state [%{public}s]", log: log, type: .error, device.advertisementSignature?.advertisedName ?? "unknown", error.localizedDescription)
    }
}



/* This structure contains the raw bytes sent by the Robot over Bluetooth, along with a timestamp for the data. */
public struct RawInputState {
    public let timestamp: Date
    public let data: Data
    public fileprivate(set) var isStale: Bool   // is the data old?
    
    init?(data: Data, type: RobotType, hasV2: Bool) {
        if data.count == type.expectedRawStateByteCount(hasV2) {
            self.timestamp = Date()
            self.data = data
            self.isStale = false
        } else {
            return nil
        }
    }
}

