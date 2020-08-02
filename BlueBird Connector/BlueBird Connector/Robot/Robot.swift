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
    private var batteryStatus: BatteryStatus?
    
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
    
 
    private var buttonShakeBits: [UInt8]? {
        guard let raw = rawInputState else { return nil }
        return byteToBits(raw.data[type.buttonShakeIndex])
    }
    private var accelerometer: [Double]? {
        guard let raw = rawInputState?.data else { return nil }
        let rawAcc = Array(raw[type.accXindex...(type.accXindex + 2)])
        if (type == .Finch) {
            let rawFinchAcc = rawToRawFinchAccelerometer(rawAcc)
            return [rawToAccelerometer(rawFinchAcc[0]), rawToAccelerometer(rawFinchAcc[1]), rawToAccelerometer(rawFinchAcc[2])]
        } else {
            return [rawToAccelerometer(rawAcc[0]), rawToAccelerometer(rawAcc[1]), rawToAccelerometer(rawAcc[2])]
        }
    }
    private var magnetometer: [Double]? {
        guard let raw = rawInputState?.data else { return nil }
        if (type == .Finch) {
            return rawToFinchMagnetometer(Array(raw[17...19]))
        } else {
            return [Double(rawToMagnetometer(raw[8], raw[9])), Double(rawToMagnetometer(raw[10], raw[11])), Double(rawToMagnetometer(raw[12], raw[13]))]
        }
    }
    private var currentBeak: TriLED? { //TODO: this.
        return TriLED(100, 100, 100)
    }
    //MARK: - Public Values
    
    var buttonA: Bool {
        return (buttonShakeBits?[4] == 0)
    }
    var buttonB: Bool {
        return (buttonShakeBits?[5] == 0)
    }
    var shake: Bool {
        return (buttonShakeBits?[0] == 1)
    }
    var accX: Double {
        return accelerometer?[0] ?? 0
    }
    var accY: Double {
        return accelerometer?[1] ?? 0
    }
    var accZ: Double {
        return accelerometer?[2] ?? 0
    }
    var magX: Int {
        return Int(magnetometer?[0].rounded() ?? 0)
    }
    var magY: Int {
        return Int(magnetometer?[1].rounded() ?? 0)
    }
    var magZ: Int {
        return Int(magnetometer?[2].rounded() ?? 0)
    }
    var compass: Int {
        if type == .Finch {
            if let acc = accelerometer, let mag = magnetometer, let compass = DoubleToCompass(acc: acc, mag: mag) {
                //turn it around so that the finch beak points north at 0
                return (compass + 180) % 360
            } else {
                return 0
            }
        } else {
            guard let raw = rawInputState?.data else { return 0 }
            let rawAcc = Array(raw[type.accXindex...(type.accXindex + 2)])
            let rawMag = Array(raw[8...13])
            return rawToCompass(rawAcc: rawAcc, rawMag: rawMag) ?? 0
        }
    }
    var finchDistance: Int? {
        if type != .Finch { return nil }
        guard let raw = rawInputState?.data else { return nil }
        let msb = Int(raw[0])
        let lsb = Int(raw[1])
        return (msb << 8) + lsb
    }
    
    
    //MARK: - Public Methods
    /*  These are the functions that you will usually use to control the Robot. Most of these call a Bluetooth command that sets up the array that is sent over Bluetooth.
     */
    
    func getHummingbirdSensor(_ port: Int) -> UInt8? {
        guard type == .HummingbirdBit else { return nil }
        if (port > 3 || port < 1) { return nil }
        guard let raw = rawInputState?.data else { return nil }
        return raw[port - 1]
    }
    func getFinchLight(onRight getRightLightSensor: Bool) -> Int? {
        guard type == .Finch else { return nil }
        guard let rawData = rawInputState?.data else { return nil }
        //We must add a correction to remove the light cast by the finch beak
        guard let currentBeak = currentBeak else { return nil }
        let R = Double(currentBeak.red) / 2.55
        let G = Double(currentBeak.green) / 2.55
        let B = Double(currentBeak.blue) / 2.55
        
        var correction = 0.0
        var raw = 0.0
        if getRightLightSensor {
            correction = 6.40473070e-03*R + 1.41015162e-02*G + 5.05547817e-02*B + 3.98301391e-04*R*G + 4.41091223e-04*R*B + 6.40756862e-04*G*B + -4.76971242e-06*R*G*B
            raw = Double(rawData[3])
        } else {
            correction = 1.06871493e-02*R + 1.94526614e-02*G + 6.12409825e-02*B + 4.01343475e-04*R*G + 4.25761981e-04*R*B + 6.46091068e-04*G*B + -4.41056971e-06*R*G*B
            raw = Double(rawData[2])
        }
        print("correcting raw light value \(raw) with \(R), \(G), \(B) -> \(correction)")
        let finalVal = raw - correction
        return bound(Int(finalVal.rounded()), min: 0, max: 100)
    }
    func getFinchLine(onRight getRightLineSensor: Bool) -> Int? {
        guard type == .Finch else { return nil }
        guard let rawData = rawInputState?.data else { return nil }
        var raw: UInt8
        if getRightLineSensor {
            raw = rawData[5]
        } else {
            //the value for the left line sensor also contains the move flag
            raw = rawData[4]
            if raw > 127 { raw -= 128 }
        }
        let final = bound(100 - Int(round(Double(raw - 6) * 100/121)), min: 0, max: 100)
        return final
    }
    func getFinchEncoder(onRight getRightEncoder: Bool) -> Double? {
        guard type == .Finch else { return nil }
        guard let rawData = rawInputState?.data else { return nil }
        var i = 7
        if getRightEncoder { i = 10 }
        
        let uNum = (UInt32(rawData[i]) << 24) + (UInt32(rawData[i+1]) << 16) + (UInt32(rawData[i+2]) << 8)
        let num = Int32(bitPattern: uNum) / 256
        return (Double(num) * 1/792)
    }
    
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
        
        //Check battery status.
        if let i = type.batteryVoltageIndex, let greenThreshold = type.batteryGreenThreshold, let yellowThreshold = type.batteryYellowThreshold {
            //let voltage = rawToVoltage( lastSensorUpdate[i] )
            let voltage = (Double(rawState.data[i]) + self.type.batteryConstant) * self.type.rawToBatteryVoltage
            
            
            let newStatus: BatteryStatus
            if let oldStatus = self.batteryStatus {
                switch oldStatus {
                case .green:
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
                }
            } else {
                if voltage > greenThreshold {
                    newStatus = BatteryStatus.green
                } else if voltage > yellowThreshold {
                    newStatus = BatteryStatus.yellow
                } else {
                    newStatus = BatteryStatus.red
                }
            }
            
            if self.batteryStatus != newStatus {
                self.batteryStatus = newStatus
                //let _ = FrontendCallbackCenter.shared.robotUpdateBattery(id: self.peripheral.identifier.uuidString, batteryStatus: newStatus.rawValue)
            }
        }
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
