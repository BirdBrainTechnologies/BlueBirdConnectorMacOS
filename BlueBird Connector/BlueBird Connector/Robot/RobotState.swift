//
//  RobotState.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 7/31/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import os


struct RobotState: Equatable {
    
    var log: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "RobotState")
    
    let robotType: RobotType
    
    public var trileds: [TriLED]
    public var servos: [UInt8]
    public var leds: [UInt8]
    public var motors: [Motor]
    public var buzzer: Buzzer?
    public var ledArray: String
    
    public static let flashSent: String = "CommandFlashSent"
    
    private var setAllTimer: Timer = Timer()
    
    init(robotType: RobotType) {
        self.robotType = robotType
        
        switch robotType {
        case .Finch:
            trileds = [TriLED(),TriLED(),TriLED(),TriLED(),TriLED()]
            servos = []
            leds = []
            motors = [Motor(), Motor()]
            buzzer = Buzzer()
        case .HummingbirdBit:
            trileds = [TriLED(), TriLED()]
            servos = [255, 255, 255, 255]
            leds = [0, 0, 0]
            motors = []
            buzzer = Buzzer()
        case .MicroBit, .Unknown:
            trileds = []
            servos = []
            leds = []
            motors = []
        }
        ledArray = "S0000000000000000000000000"
    }
    
    
    //func setAllCommand() -> Data {
    func setAllCommand() -> [UInt8] {
        switch robotType {
        case .HummingbirdBit:
        //Set all: 0xCA LED1 Reserved R1 G1 B1 R2 G2 B2 SS1 SS2 SS3 SS4 LED2 LED3 Time us(MSB) Time us(LSB) Time ms(MSB) Time ms(LSB)
            guard leds.count == 3, trileds.count == 2, servos.count == 4, let buzzer = buzzer else {
                os_log("Missing information in the hummingbird bit output state", log: log, type: .error)
                //return Data()
                return []
            }
            
            let letter: UInt8 = 0xCA
            
            let buzzerArray = buzzer.array()
            
            let array: [UInt8] = [letter, leds[0], 0x00,
                                  trileds[0].red, trileds[0].green, trileds[0].blue,
                                  trileds[1].red, trileds[1].green, trileds[1].blue,
                                  servos[0], servos[1], servos[2], servos[3],
                                  leds[1], leds[2],
                                  buzzerArray[0], buzzerArray[1], buzzerArray[2], buzzerArray[3]]
            assert(array.count == 19)
            
            //NSLog("Set all \(array)")
            //return Data(bytes: UnsafePointer<UInt8>(array), count: array.count)
            return array
        case .Finch:
            // 0xD0, B_R(0-255), B_G(0-255), B_B(0-255), T1_R(0-255), T1_G(0-255), T1_B(0-255), T2_R(0-255),
            // T2_R(0-255), T2_R(0-255), T3_R(0-255), T3_G(0-255), T3_B(0-255), T4_R(0-255), T4_G(0-255), T4_B(0-255),
            // Time_us_MSB, Time_us_LSB, Time_ms_MSB, Time_ms_LSB
            guard trileds.count == 5, let buzzer = buzzer else {
                os_log("Missing information in the finch output state", log: log, type: .error)
                //return Data()
                return []
            }
            
            let letter: UInt8 = 0xD0
        
            let buzzerArray = buzzer.array()
        
            let array: [UInt8] = [letter,
                    trileds[0].red, trileds[0].green, trileds[0].blue,
                    trileds[1].red, trileds[1].green, trileds[1].blue,
                    trileds[2].red, trileds[2].green, trileds[2].blue,
                    trileds[3].red, trileds[3].green, trileds[3].blue,
                    trileds[4].red, trileds[4].green, trileds[4].blue,
                    buzzerArray[0], buzzerArray[1], buzzerArray[2], buzzerArray[3]]
        
            assert(array.count == 20)
            //NSLog("Set all \(array)")
            //return Data(bytes: UnsafePointer<UInt8>(array), count: array.count)
            return array
            
        default:
            //return Data()
            return []
        }
    }
    
    //func ledArrayCommand() -> Data? {
    func ledArrayCommand() -> [UInt8]? {
        let letter: UInt8 = 0xCC
        let ledStatusChars = Array(ledArray)
        
        switch ledStatusChars[0] {
        case "S": //Set a symbol
            let symbol: UInt8 = 0x80
            
            var led8to1String = ""
            for i in 1 ..< 9 {
                led8to1String = String(ledStatusChars[i]) + led8to1String
            }
    
            var led16to9String = ""
            for i in 9 ..< 17 {
                led16to9String = String(ledStatusChars[i]) + led16to9String
            }
            
            var led24to17String = ""
            for i in 17 ..< 25 {
                led24to17String = String(ledStatusChars[i]) + led24to17String
            }
            
            guard let leds8to1 = UInt8(led8to1String, radix: 2),
                let led16to9 = UInt8(led16to9String, radix: 2),
                let led24to17 = UInt8(led24to17String, radix: 2),
                let led25 = UInt8(String(ledStatusChars[25])) else {
                    return nil
            }
            
            //NSLog("Symbol command \([letter, symbol, led25, led24to17, led16to9, leds8to1])")
            //return Data(bytes: UnsafePointer<UInt8>([letter, symbol, led25, led24to17, led16to9, leds8to1] as [UInt8]), count: 6)
            return [letter, symbol, led25, led24to17, led16to9, leds8to1]
            
        case "F": //flash a string
            let length = ledStatusChars.count - 1
            let flash = UInt8(64 + length)
            var commandArray = [letter, flash]
            for i in 1 ... length {
                commandArray.append(getUnicode(ledStatusChars[i]))
            }
            
            //NSLog("Flash command \(commandArray)")
            //return Data(bytes: UnsafePointer<UInt8>(commandArray), count: length + 2)
            return commandArray
            
        default: //return nil
            return nil
        }
    }
    
    static func ==(lhs: RobotState, rhs: RobotState) -> Bool {
        return (lhs.trileds == rhs.trileds) && (lhs.servos == rhs.servos) &&
            (lhs.leds == rhs.leds) && (lhs.motors == rhs.motors) &&
            (lhs.buzzer == rhs.buzzer) && (lhs.ledArray == rhs.ledArray)
    }
}

//Have to make a TriLED struct because Tuples are not Equatable :( –J
struct TriLED: Equatable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    
    init(_ inRed: UInt8 = 0, _ inGreen: UInt8 = 0, _ inBlue: UInt8 = 0) {
        red = inRed
        green = inGreen
        blue = inBlue
    }
    
    static func ==(lhs: TriLED, rhs: TriLED) -> Bool {
        return lhs.red == rhs.red && lhs.green == rhs.green && lhs.blue == rhs.blue
    }
}
struct Buzzer: Equatable {
    
    private var period: UInt16 //the period of the note in us
    private var duration: UInt16 //duration of buzz in ms
    
    init(period: UInt16 = 0, duration: UInt16 = 0) {
        self.duration = duration
        self.period = period
    }
    
    //convert to array used to set the buzzer
    func array() -> [UInt8] {
        
        var buzzerArray: [UInt8] = []
        buzzerArray.append( UInt8(period >> 8) )
        buzzerArray.append( UInt8(period & 0x00ff) )
        buzzerArray.append( UInt8(duration >> 8) )
        buzzerArray.append( UInt8(duration & 0x00ff) )
        
        return buzzerArray
    }
    
    static func ==(lhs: Buzzer, rhs: Buzzer) -> Bool {
        return lhs.period == rhs.period && lhs.duration == rhs.duration
    }
}
struct Motor: Equatable {
    
    public let velocity: Int8
    private let ticksMSB: UInt8
    private let ticksSSB: UInt8 //second significant byte
    private let ticksLSB: UInt8
    
    init(_ speed: Int8 = 0, _ ticks: Int = 1) {//speed=0, ticks=1 is the do nothing state
        //print("creating new Motor state with speed \(speed) and distance \(ticks)")
        velocity = speed
        
        //let ticks = Int(round(distance * 80))
        ticksMSB = UInt8(ticks >> 16)
        ticksSSB = UInt8((ticks & 0x00ff00) >> 8)
        ticksLSB = UInt8(ticks & 0x0000ff)
        //print("motor state created. \(ticks) \(ticksMSB) \(ticksSSB) \(ticksLSB)")
    }
    
    //convert to array used to set the motor
    func array() -> [UInt8] {
        
        let cv:(Int8)->UInt8 = { velocity in
            var v = UInt8(abs(velocity)) //TODO: handle the case where velocity = -128? this will cause an overflow error here
            if (v > 0 && v < 3) { v = 3 } //numbers below 3 don't cause movement
            if velocity > 0 { v += 128 }
            return v
        }
        
        return [cv(velocity), ticksMSB, ticksSSB, ticksLSB]
    }
    
    static func == (lhs: Motor, rhs: Motor) -> Bool {
        return lhs.velocity == rhs.velocity && lhs.ticksLSB == rhs.ticksLSB &&
            lhs.ticksSSB == rhs.ticksSSB && lhs.ticksMSB == rhs.ticksMSB
    }
}




/*protocol RobotState: Equatable {
    
    var ledArray: String { get set }
    
    init()
    func setAllCommand() -> Data

}

extension RobotState {
    func ledArrayCommand() -> Data? {
        let letter: UInt8 = 0xCC
        let ledStatusChars = Array(ledArray)
        
        switch ledStatusChars[0] {
        case "S": //Set a symbol
            let symbol: UInt8 = 0x80
            
            var led8to1String = ""
            for i in 1 ..< 9 {
                led8to1String = String(ledStatusChars[i]) + led8to1String
            }
    
            var led16to9String = ""
            for i in 9 ..< 17 {
                led16to9String = String(ledStatusChars[i]) + led16to9String
            }
            
            var led24to17String = ""
            for i in 17 ..< 25 {
                led24to17String = String(ledStatusChars[i]) + led24to17String
            }
            
            guard let leds8to1 = UInt8(led8to1String, radix: 2),
                let led16to9 = UInt8(led16to9String, radix: 2),
                let led24to17 = UInt8(led24to17String, radix: 2),
                let led25 = UInt8(String(ledStatusChars[25])) else {
                    return nil
            }
            
            //NSLog("Symbol command \([letter, symbol, led25, led24to17, led16to9, leds8to1])")
            return Data(bytes: UnsafePointer<UInt8>([letter, symbol, led25, led24to17, led16to9, leds8to1] as [UInt8]), count: 6)
            
        case "F": //flash a string
            let length = ledStatusChars.count - 1
            let flash = UInt8(64 + length)
            var commandArray = [letter, flash]
            for i in 1 ... length {
                commandArray.append(getUnicode(ledStatusChars[i]))
            }
            
            //NSLog("Flash command \(commandArray)")
            return Data(bytes: UnsafePointer<UInt8>(commandArray), count: length + 2)
        default: return nil
        }
    }
    
}


//MARK: Typed Robot Structs

struct FinchState: RobotState {
    public var trileds: [TriLED]
    public var motors: [Motor]
    public var buzzer: Buzzer
    public var ledArray: String
    
    init() {
        trileds = [TriLED(), TriLED(), TriLED(), TriLED(), TriLED()]
        motors = [Motor(), Motor()]
        buzzer = Buzzer()
        ledArray = "S0000000000000000000000000"
    }
    
    func setAllCommand() -> Data {
        // 0xD0, B_R(0-255), B_G(0-255), B_B(0-255), T1_R(0-255), T1_G(0-255), T1_B(0-255), T2_R(0-255),
        // T2_R(0-255), T2_R(0-255), T3_R(0-255), T3_G(0-255), T3_B(0-255), T4_R(0-255), T4_G(0-255), T4_B(0-255),
        // Time_us_MSB, Time_us_LSB, Time_ms_MSB, Time_ms_LSB
        let letter: UInt8 = 0xD0
        
        let buzzerArray = buzzer.array()
    
        let array: [UInt8] = [letter,
                trileds[0].red, trileds[0].green, trileds[0].blue,
                trileds[1].red, trileds[1].green, trileds[1].blue,
                trileds[2].red, trileds[2].green, trileds[2].blue,
                trileds[3].red, trileds[3].green, trileds[3].blue,
                trileds[4].red, trileds[4].green, trileds[4].blue,
                buzzerArray[0], buzzerArray[1], buzzerArray[2], buzzerArray[3]]
    
        assert(array.count == 20)
        return Data(bytes: UnsafePointer<UInt8>(array), count: array.count)
    }
    
    static func ==(lhs: FinchState, rhs: FinchState) -> Bool {
        return (lhs.trileds == rhs.trileds && lhs.motors == rhs.motors &&
            lhs.buzzer == rhs.buzzer && lhs.ledArray == rhs.ledArray)
    }
}

struct HummingbirdState: RobotState {
    public var trileds: [TriLED]
    public var servos: [UInt8]
    public var leds: [UInt8]
    public var buzzer: Buzzer
    public var ledArray: String
    
    init() {
        trileds = [TriLED(), TriLED()]
        servos = [255, 255, 255, 255]
        leds = [0, 0, 0]
        buzzer = Buzzer()
        ledArray = "S0000000000000000000000000"
    }
    
    func setAllCommand() -> Data {
        //Set all: 0xCA LED1 Reserved R1 G1 B1 R2 G2 B2 SS1 SS2 SS3 SS4 LED2 LED3 Time us(MSB) Time us(LSB) Time ms(MSB) Time ms(LSB)
        let letter: UInt8 = 0xCA
        
        let buzzerArray = buzzer.array()
        
        let array: [UInt8] = [letter, leds[0], 0x00,
                              trileds[0].red, trileds[0].green, trileds[0].blue,
                              trileds[1].red, trileds[1].green, trileds[1].blue,
                              servos[0], servos[1], servos[2], servos[3],
                              leds[1], leds[2],
                              buzzerArray[0], buzzerArray[1], buzzerArray[2], buzzerArray[3]]
        assert(array.count == 19)
        
        return Data(bytes: UnsafePointer<UInt8>(array), count: array.count)
    }
    
    static func ==(lhs: HummingbirdState, rhs: HummingbirdState) -> Bool {
        return (lhs.trileds == rhs.trileds && lhs.servos == rhs.servos &&
            lhs.leds == rhs.leds && lhs.buzzer == rhs.buzzer && lhs.ledArray == rhs.ledArray)
    }
}

struct MicrobitState: RobotState {
    public var ledArray: String
    init() {
        ledArray = "S0000000000000000000000000"
    }
    
    func setAllCommand() -> Data {
        /** Micro:bit I/O :
        * 0x90, FrequencyMSB, FrequencyLSB, Time MSB, Mode, Pad0_value, Pad1_value, Pad2_value
        * Frequency is valid for only pin 0
        *
        * Mode 8 bits:
        * FU, FU, P0_Mode_MSbit, P0_Mode_LSbit, P1_Mode_MSbit, P1_Mode_MSbit, P2_Mode_MSbit, P2_Mode_LSbit
        */
        
        // stand alone microbit set all command is for buzzer and pins, which we will not use in this app
        return Data()
    }
    
    static func ==(lhs: MicrobitState, rhs: MicrobitState) -> Bool {
        return (lhs.ledArray == rhs.ledArray)
    }
}

//MARK: Component Structs
struct TriLED: Equatable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    
    init(_ inRed: UInt8 = 0, _ inGreen: UInt8 = 0, _ inBlue: UInt8 = 0) {
        red = inRed
        green = inGreen
        blue = inBlue
    }
    
    static func ==(lhs: TriLED, rhs: TriLED) -> Bool {
        return lhs.red == rhs.red && lhs.green == rhs.green && lhs.blue == rhs.blue
    }
}
struct Buzzer: Equatable {
    
    private var period: UInt16 //the period of the note in us
    private var duration: UInt16 //duration of buzz in ms
    
    init(period: UInt16 = 0, duration: UInt16 = 0) {
        self.duration = duration
        self.period = period
    }
    
    //convert to array used to set the buzzer
    func array() -> [UInt8] {
        
        var buzzerArray: [UInt8] = []
        buzzerArray.append( UInt8(period >> 8) )
        buzzerArray.append( UInt8(period & 0x00ff) )
        buzzerArray.append( UInt8(duration >> 8) )
        buzzerArray.append( UInt8(duration & 0x00ff) )
        
        return buzzerArray
    }
    
    static func ==(lhs: Buzzer, rhs: Buzzer) -> Bool {
        return lhs.period == rhs.period && lhs.duration == rhs.duration
    }
}
struct Motor: Equatable {
    
    public let velocity: Int8
    private let ticksMSB: UInt8
    private let ticksSSB: UInt8 //second significant byte
    private let ticksLSB: UInt8
    
    init(_ speed: Int8 = 0, _ ticks: Int = 1) {//speed=0, ticks=1 is the do nothing state
        //print("creating new Motor state with speed \(speed) and distance \(ticks)")
        velocity = speed
        
        ticksMSB = UInt8(ticks >> 16)
        ticksSSB = UInt8((ticks & 0x00ff00) >> 8)
        ticksLSB = UInt8(ticks & 0x0000ff)
        //print("motor state created. \(ticks) \(ticksMSB) \(ticksSSB) \(ticksLSB)")
    }
    
    //convert to array used to set the motor
    func array() -> [UInt8] {
        
        let cv:(Int8)->UInt8 = { velocity in
            var v = UInt8(abs(velocity)) //TODO: handle the case where velocity = -128? this will cause an overflow error here
            if velocity > 0 { v += 128 }
            return v
        }
        
        return [cv(velocity), ticksMSB, ticksSSB, ticksLSB]
    }
    
    static func == (lhs: Motor, rhs: Motor) -> Bool {
        return lhs.velocity == rhs.velocity && lhs.ticksLSB == rhs.ticksLSB &&
            lhs.ticksSSB == rhs.ticksSSB && lhs.ticksMSB == rhs.ticksMSB
    }
}*/
