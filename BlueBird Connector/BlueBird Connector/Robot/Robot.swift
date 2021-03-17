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

protocol Robot: AnyObject {
    
    var log: OSLog { get }
    
    var manageableRobot: ManageableRobot { get }
    var currentRobotState: RobotState { set get }
    var nextRobotState: RobotState { set get }
    //var commandPending: Data? { set get }
    var commandPending: [UInt8]? { set get }
    var setAllTimer: SetAllTimer { get }
    var isConnected: Bool { set get }
    var writtenCondition: NSCondition { get }
    var inProgressPrintID: Int { set get }
    
    //Robot specific
    var buttonShakeIndex: Int { get }
    var accXindex: Int { get }
    var type: RobotType { get }
    //var turnOffCommand: Data { get }
    var turnOffCommand: [UInt8] { get }
    
    //calculated values
    var accelerometer: [Double]? { get }
    var magnetometer: [Double]? { get }
    var compass: Int { get }
    var V2sound: Int { get }
    var V2temperature: Int { get }
    
    init(_ mRobot: ManageableRobot)
    
    //func getAdditionalCommand(_ nextCopy: RobotState) -> Data?
    func getAdditionalCommand(_ nextCopy: RobotState) -> [UInt8]?
}

extension Robot {
    
    
    var name: String {
        return manageableRobot.advertisementSignature?.advertisedName ?? ""
    }
    var fancyName: String {
        return manageableRobot.advertisementSignature?.memorableName ?? manageableRobot.advertisementSignature?.advertisedName ?? ""
    }
    var uuid: UUID {
        return manageableRobot.uuid
    }
    //calculated private values
    private var buttonShakeBits: [UInt8]? {
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        return byteToBits(raw[buttonShakeIndex])
    }
    
    
    var buttonA: Bool {
        return (buttonShakeBits?[4] == 0)
    }
    var buttonB: Bool {
        return (buttonShakeBits?[5] == 0)
    }
    var V2touch: Bool {
        return (buttonShakeBits?[1] == 0)
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
    
    func setAll() {

        if let command = self.commandPending {
            /*var commandArray: [UInt8] = []
            commandArray = Array(command)
            os_log("sending a pending command: %{public}s", log: log, type: .debug, commandArray.description)*/
            os_log("sending a pending command: %{public}s", log: log, type: .debug, command.description)
            self.manageableRobot.sendData(command)
            self.commandPending = nil
            return
        }
        
        self.writtenCondition.lock()
        let nextCopy = self.nextRobotState
        self.writtenCondition.signal()
        self.writtenCondition.unlock()
        
        let changeOccurred = !(nextCopy == self.currentRobotState)

        guard changeOccurred else { return }
        //print(nextCopy.trileds)
        let command = nextCopy.setAllCommand()
        let oldCommand = currentRobotState.setAllCommand()
        
        //reset the buzzer state so a buzzer command is only sent once
        if (nextCopy.buzzer != nil) && (nextCopy.buzzer == self.nextRobotState.buzzer) {
            self.nextRobotState.buzzer = Buzzer()
        }
        
        var sentSetAll = false
        if command != oldCommand {
            var commandArray: [UInt8] = []
            commandArray = Array(command)
            os_log("sending set all: %{public}s", log: log, type: .debug, commandArray.description)
            self.manageableRobot.sendData(command)
            sentSetAll = true
        }
        
        if let additionalCommand = getAdditionalCommand(nextCopy) {
            if sentSetAll {
                commandPending = additionalCommand
            } else {
                var commandArray: [UInt8] = []
                commandArray = Array(additionalCommand)
                os_log("sending additional command: %{public}s", log: log, type: .debug, commandArray.description)
                self.manageableRobot.sendData(additionalCommand)
            }
        }
        
        currentRobotState = nextCopy
        
    }
    
    /**
     * Set a specific output to be set next time setAll is sent.
     * Returns false if this output cannot be set
     */
    func setOutput(ifCheck isValid: Bool, when predicate: (() -> Bool), set work: (() -> ())) -> Bool {
        
        guard isConnected else {
            os_log("Tried to set output on disconnected device [%{public}s]", log: log, type: .error, self.name)
            return false
        }
        if !isValid {
            os_log("Tried to set output on device [%{public}s] with invalid check", log: log, type: .error, self.name)
            return false
        }
        
        writtenCondition.lock()
        
        while !predicate() && isConnected {
            os_log("waiting...", log: log, type: .debug)
            writtenCondition.wait(until: Date(timeIntervalSinceNow: 0.05))
        }
        
        work()
        
        writtenCondition.signal()
        writtenCondition.unlock()
        
        return true
    }
    
    
    //MARK: Public set functions available for all Robots.
    
    /**
        Set a string to print to the led array. Print no more than 10 characters at a time.
        Each character takes 600ms to print.
     */
    func setPrint(_ printString: Substring) -> Bool {
        inProgressPrintID = inProgressPrintID + 1
        return printStringParts(printString, id: inProgressPrintID)
    }
    private func printStringParts(_ printString: Substring, id: Int) -> Bool {
        guard inProgressPrintID == id else { return false }
        
        if printString.count > 10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                let _ = self.printStringParts(printString.dropFirst(10), id: id)
            }
        }
        
        let arrayString = "F" + printString.prefix(10)
        //succeeds if first part of string succeeds
        return setOutput(ifCheck: (arrayString.count <= 11),
            when: {self.nextRobotState.ledArray == self.currentRobotState.ledArray},
            set: {self.nextRobotState.ledArray = arrayString})
    }
    
    /**
        Set a symbol to show on the led array.
     */
    func setSymbol(_ symbolString: String) -> Bool {
        let sString = "S" + symbolString
        
        return setOutput(ifCheck: (sString.count == 26),
            when: {self.nextRobotState.ledArray == self.currentRobotState.ledArray},
            set: {self.nextRobotState.ledArray = sString})
    }
    
    /**
        Set the buzzer to sound a given note (defined by midi note number) for a given duration.
     */
    func setBuzzer(note: Int, duration: Int) -> Bool {
        guard (note > 0 && note < 256 && duration > 0 && duration < 65536),
            let period = noteToPeriod(UInt8(note)) else {
                return false
        }
        
        return setOutput(ifCheck: (self.currentRobotState.buzzer != nil),
        when: {self.nextRobotState.buzzer == self.currentRobotState.buzzer},
        set: {self.nextRobotState.buzzer = Buzzer(period: period, duration: UInt16(duration))})
    }
    
    /**
        Reset the robot to initial off state.
     */
    func stopAll() -> Bool {
        let success = setOutput(ifCheck: (true), when: {self.nextRobotState == self.currentRobotState},
                  set: {self.nextRobotState = RobotState(robotType: self.type)})
        self.commandPending = nil
        
        //So that an in progress print will not continue
        self.inProgressPrintID = self.inProgressPrintID + 1
        
        self.manageableRobot.sendData(turnOffCommand)
        return success
    }
    
    /**
        Start magnetometer calibration
     */
    func startCalibration() {
        self.manageableRobot.startCalibration()
    }
}

struct RobotConstants {
    //static public let CALIBRATE_COMMAND = Data(bytes: UnsafePointer<UInt8>([0xCE, 0xFF, 0xFF, 0xFF] as [UInt8]), count: 4)
    static public let CALIBRATE_COMMAND:[UInt8] = [0xCE, 0xFF, 0xFF, 0xFF]
}


