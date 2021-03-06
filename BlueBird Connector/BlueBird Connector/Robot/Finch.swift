//
//  Finch.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 8/2/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import os

class Finch: Robot {

    var log: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "Finch")
    
    var manageableRobot: ManageableRobot
    var currentRobotState: RobotState
    var nextRobotState: RobotState
    //var commandPending: Data?
    var commandPending: [UInt8]?
    var setAllTimer: SetAllTimer
    var isConnected: Bool
    let writtenCondition: NSCondition = NSCondition()
    var inProgressPrintID: Int = 0
    
    //Finch specific values
    let buttonShakeIndex: Int = 16
    let accXindex: Int = 13
    let type: RobotType = .Finch
    //let turnOffCommand: Data = Data(bytes: UnsafePointer<UInt8>([0xDF] as [UInt8]), count: 1)
    let turnOffCommand: [UInt8] = [0xDF]
    
    internal var accelerometer: [Double]? {
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        let rawAcc = Array(raw[accXindex...(accXindex + 2)])
        let rawFinchAcc = rawToRawFinchAccelerometer(rawAcc)
        return [rawToAccelerometer(rawFinchAcc[0]), rawToAccelerometer(rawFinchAcc[1]), rawToAccelerometer(rawFinchAcc[2])]
    }
    internal var magnetometer: [Double]? {
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        return rawToFinchMagnetometer(Array(raw[17...19]))
    }
    //Current value of beak led. Used to correct light sensor values.
    private var currentBeak: TriLED? {
        guard currentRobotState.trileds.count > 0 else { return nil }
        return currentRobotState.trileds[0]
    }
    
    
    //MARK: Public calculated values
    
    var V2sound: Int {
        guard let raw = self.manageableRobot.rawInputData else { return 0 }
        return Int(raw[0])
    }
    
    var V2temperature: Int {
        guard let raw = self.manageableRobot.rawInputData else { return 0 }
        return Int(raw[6] >> 2)
    }
    
    var compass: Int {
        if let acc = accelerometer, let mag = magnetometer, let compass = DoubleToCompass(acc: acc, mag: mag) {
            //turn it around so that the finch beak points north at 0
            return (compass + 180) % 360
        } else {
            return 0
        }
    }
    
    var finchDistance: String? {
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        if manageableRobot.hasV2Microbit {
            return String(Int(raw[1]))
        } else {
            let msb = Int(raw[0])
            let lsb = Int(raw[1])
            let raw = (msb << 8) + lsb
            return String(Int((Double(raw) * 0.0919).rounded()))
        }
    }
    
    var isMoving: Bool? {
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        return (raw[4] > 127)
    }
    
    
    //MARK: init
    required init(_ mRobot: ManageableRobot) {
        manageableRobot = mRobot
        isConnected = true
        currentRobotState = RobotState(robotType: .Finch)
        nextRobotState = currentRobotState
        setAllTimer = SetAllTimer()
        setAllTimer.setRobot(self)
        setAllTimer.resume()
    }
    
    
    //MARK: Internal methods
    
    /**
        Get the command to set the led array and motors to their next values.
     */
    //internal func getAdditionalCommand(_ nextCopy: RobotState) -> Data? {
    internal func getAdditionalCommand(_ nextCopy: RobotState) -> [UInt8]? {
        var mode: UInt8 = 0x00
        let setMotors = (nextCopy.motors != currentRobotState.motors)
        let setLedArray = (nextCopy.ledArray != currentRobotState.ledArray && nextCopy.ledArray != RobotState.flashSent)
        var setSymbol = false
        var setFlash = false
        var ledArrayArray:[UInt8] = []
        var motorArray:[UInt8] = []
        
        if setLedArray, let ledCommand = nextCopy.ledArrayCommand() {
            ledArrayArray = Array(ledCommand)
            setSymbol = (ledArrayArray[1] == 0x80)
            setFlash = !setSymbol
            ledArrayArray.removeFirst(2)
            if setFlash {
                os_log("Setting flash sent...", log: log, type: .debug)
                nextRobotState.ledArray = RobotState.flashSent
            }
        }
        
        if setMotors {
            guard nextCopy.motors.count == 2 else {
                os_log("Finch motors not found in output state.", log: log, type: .error)
                return nil
            }
            let motors = nextCopy.motors
            motorArray = motors[0].array() + motors[1].array()
            
            if nextCopy.motors == self.nextRobotState.motors {
                self.nextRobotState.motors = [Motor(), Motor()]
            } else {
                os_log("the motors have already changed", log: log, type: .debug)
            }
        }
        
        if setMotors && setFlash {
            mode = 0x80 + UInt8(ledArrayArray.count)
        } else if setMotors && setSymbol {
            mode = 0x60
        } else if setMotors {
            mode = 0x40
        } else if setFlash {
            mode = UInt8(ledArrayArray.count)
        } else if setSymbol {
            mode = 0x20
        }
        
        if mode != 0 {
            /* 0xD2, symbol/motors/flash--length,
             L_Dir--Speed, L_Ticks_3, L_Ticks_2, L_Ticks_1,
             R_Dir--Speed, R_Ticks_3, R_Ticks_2, R_Ticks_1,
             M_L_4/C1, M_L_3/C2, M_L_2/C3, M_L_1/C4,
             C5, C6, C7, C8, C9, C10 */
            let command: [UInt8] = [0xD2, mode] + motorArray + ledArrayArray
            //let commandData = Data(bytes: UnsafePointer<UInt8>(command), count: command.count)
            
            //return commandData
            return command
        } else {
            return nil
        }
    }
    
    //MARK: - Public Methods
    
    /**
        Get the value of the specified light sensor, corrected based on the current value of the beak led.
     */
    func getFinchLight(onRight getRightLightSensor: Bool) -> Int? {
        guard let rawData = self.manageableRobot.rawInputData else { return nil }
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
        os_log("correcting raw light value %{public}f with %{public}f, %{public}f, %{public}f -> %{public}f", log: log, type: .debug, raw, R, G, B, correction)
        let finalVal = raw - correction
        return Int(finalVal.rounded()).clamped(to: 0 ... 100)
    }
    
    /**
        Get the current line sensor value
     */
    func getFinchLine(onRight getRightLineSensor: Bool) -> Int? {
        guard let rawData = self.manageableRobot.rawInputData else { return nil }
        var raw: UInt8
        if getRightLineSensor {
            raw = rawData[5]
        } else {
            //the value for the left line sensor also contains the move flag
            raw = rawData[4]
            if raw > 127 { raw -= 128 }
        }
        let final = (100 - Int(round(Double(raw - 6) * 100/121)))
        return final.clamped(to: 0 ... 100)
    }
    
    /**
        Get the current encoder value
     */
    func getFinchEncoder(onRight getRightEncoder: Bool) -> Double? {
        guard let rawData = self.manageableRobot.rawInputData else { return nil }
        var i = 7
        if getRightEncoder { i = 10 }
        
        let uNum = (UInt32(rawData[i]) << 24) + (UInt32(rawData[i+1]) << 16) + (UInt32(rawData[i+2]) << 8)
        let num = Int32(bitPattern: uNum) / 256
        return (Double(num) * 1/792)
    }
    
    /**
        Set finch motors. Speed is specified as a percent.
     */
    func setMotors(leftSpeed: Double, leftTicks: Int, rightSpeed: Double, rightTicks: Int) -> Bool {
        return setOutput(ifCheck: (self.nextRobotState.motors.count == 2),
            when: {self.nextRobotState.motors == self.currentRobotState.motors},
            set: { self.nextRobotState.motors[0] = Motor(scaledSpeed(leftSpeed), leftTicks)
                self.nextRobotState.motors[1] = Motor(scaledSpeed(rightSpeed), rightTicks)})
    }
    private func scaledSpeed(_ speed: Double) -> Int8 {
        let speedScaling = 36.0/100.0
        let clampedSpeed = speed.clamped(to: -100.0 ... 100.0)
        return Int8(round(clampedSpeed * speedScaling))
    }
    
    /**
        Set the specified led (Beak at port 0, Tail at ports 1 to 4)
     */
    func setTriLED(port: Int, R: UInt8, G: UInt8, B: UInt8) -> Bool {
        let i = port - 1

        return setOutput(ifCheck: (port > 0 && port <= 5),
            when: {self.nextRobotState.trileds[i] == self.currentRobotState.trileds[i]},
            set: {self.nextRobotState.trileds[i] = TriLED(R, G, B)})
    }
    
    /**
        Set the whole tail to the same color
     */
    func setTail(R: UInt8, G: UInt8, B: UInt8) -> Bool {
        return setOutput(ifCheck: self.nextRobotState.trileds.count == 5,
        when: {self.nextRobotState.trileds[1] == self.currentRobotState.trileds[1] && self.nextRobotState.trileds[2] == self.currentRobotState.trileds[2] && self.nextRobotState.trileds[3] == self.currentRobotState.trileds[3] && self.nextRobotState.trileds[4] == self.currentRobotState.trileds[4]},
        set: {
            for i in 1 ..< 5 {
                self.nextRobotState.trileds[i] = TriLED(R, G, B)
            }
            })
    }
    
    /**
        Reset the finch encoders
     */
    func resetEncoders() -> Bool {
        self.manageableRobot.sendData(FinchConstants.RESET_ENCODERS_COMMAND)
        return true
    }
}

struct FinchConstants {
    static public let FINCH_TICKS_PER_CM = 49.7;
    static public let FINCH_TICKS_PER_DEGREE = 4.335;
    //static public let RESET_ENCODERS_COMMAND = Data(bytes: UnsafePointer<UInt8>([0xD5] as [UInt8]), count: 1)
    static public let RESET_ENCODERS_COMMAND:[UInt8] = [0xD5]
}
