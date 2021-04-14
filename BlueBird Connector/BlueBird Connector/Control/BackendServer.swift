//
//  BackendServer.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 7/4/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import Swifter
import os

class BackendServer {
    
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "BackendServer")
    
    private let server: HttpServer
    var connectedRobots = [DeviceLetter: Robot]()
    
    //Standard Responses
    private let NOT_CONNECTED = getRawResponse("Not Connected")
    private let V2_REQUIRED = getRawResponse("micro:bit V2 required")
    private let INVALID_PARAMETERS = getRawResponse("Invalid parameters", .badRequest(nil))
    private let INVALID_PORT = getRawResponse("Invalid port", .badRequest(nil))
    private let INVALID_AXIS = getRawResponse("Invalid axis", .badRequest(nil))
    
    public init() {
        server = HttpServer()
        server.notFoundHandler = { request in
            os_log("Invalid request [%{public}s]", log: self.log, type: .error, request.path)
            return .notFound
        }
        
        setupPaths()
        
        do {
            try server.start(30061)
            let port = try server.port()
            os_log("Server has started on port [%{public}s].", log: log, type: .debug, String(port))
        } catch {
            os_log("Server start error: [%{public}s]", log: log, type: .error, error.localizedDescription)
        }
        
    }
    
    private func setupPaths() {

        //offline snap
        //server["/snap.html"] = handleSnapRequest(_:)
        //server["/snap/(.+)"] = handleSnapRequest(_:)
        
        //These look good
        server["/snap/:filename"] = handleSnapRequest(_:)
        server["/snap/*/:filename"] = handleSnapRequest(_:)
        server["/snap/*/*/:filename"] = handleSnapRequest(_:)
        server["/snap/*/*/*/:filename"] = handleSnapRequest(_:)
        server["/snap/*/*/*/*/:filename"] = handleSnapRequest(_:)
        
        //outputs for any
        server["/hummingbird/out/stopall"] = stopAllRequest(_:)
        server["/hummingbird/out/stopall/:robot"] = stopAllRequest(_:)
        server["/hummingbird/out/print/:printString"] = printRequest(_:)
        server["/hummingbird/out/print/:printString/:robot"] = printRequest(_:)
        server["/hummingbird/out/symbol/:robot/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b/:b"] = symbolRequest(_:)
        //finch and hummingbird outputs
        server["/hummingbird/out/triled/:port/:R/:G/:B"] = triledRequest(_:)
        server["/hummingbird/out/triled/:port/:R/:G/:B/:robot"] = triledRequest(_:)
        server["/hummingbird/out/playnote/:note/:duration"] = playNoteRequest(_:)
        server["/hummingbird/out/playnote/:note/:duration/:robot"] = playNoteRequest(_:)
        //hummingbird only outputs
        server["/hummingbird/out/led/:port/:intensity"] = ledRequest(_:)
        server["/hummingbird/out/led/:port/:intensity/:robot"] = ledRequest(_:)
        server["/hummingbird/out/servo/:port/:value"] = servoRequest(_:)
        server["/hummingbird/out/servo/:port/:value/:robot"] = servoRequest(_:)
        server["/hummingbird/out/rotation/:port/:value"] = servoRequest(_:)
        server["/hummingbird/out/rotation/:port/:value/:robot"] = servoRequest(_:)
        //finch only outputs
        server["/hummingbird/out/move/:robot/:dir/:dist/:speed"] = finchMove(_:)
        server["/hummingbird/out/turn/:robot/:dir/:angle/:speed"] = finchTurn(_:)
        server["/hummingbird/out/wheels/:robot/:leftSpeed/:rightSpeed"] = finchWheels(_:)
        server["/hummingbird/out/stopFinch/:robot"] = stopFinch(_:)
        server["/hummingbird/out/resetEncoders/:robot"] = resetEncoders(_:)
        
        //micro:bit sensor requests
        server["/hummingbird/in/button/:btn"] = sensorRequest(_:)
        server["/hummingbird/in/button/:btn/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/orientation/:n"] = sensorRequest(_:)
        server["/hummingbird/in/orientation/:n/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/finchOrientation/:n"] = sensorRequest(_:)
        server["/hummingbird/in/finchOrientation/:n/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/Accelerometer/:axis"] = sensorRequest(_:)
        server["/hummingbird/in/Accelerometer/:axis/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/finchAccel/:axis"] = sensorRequest(_:)
        server["/hummingbird/in/finchAccel/:axis/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/Magnetometer/:axis"] = sensorRequest(_:)
        server["/hummingbird/in/Magnetometer/:axis/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/finchMag/:axis"] = sensorRequest(_:)
        server["/hummingbird/in/finchMag/:axis/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/Compass"] = sensorRequest(_:)
        server["/hummingbird/in/Compass/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/finchCompass/static"] = sensorRequest(_:)
        server["/hummingbird/in/finchCompass/static/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/V2sensor/:sensor"] = sensorRequest(_:)
        server["/hummingbird/in/V2sensor/:sensor/:robot"] = sensorRequest(_:)
        //Hummingbird sensor port requests
        server["/hummingbird/in/Distance/:port"] = sensorRequest(_:) //also finch
        server["/hummingbird/in/Distance/:port/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/Dial/:port"] = sensorRequest(_:)
        server["/hummingbird/in/Dial/:port/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/Light/:port"] = sensorRequest(_:) //also finch
        server["/hummingbird/in/Light/:port/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/Sound/:port"] = sensorRequest(_:)
        server["/hummingbird/in/Sound/:port/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/Other/:port"] = sensorRequest(_:)
        server["/hummingbird/in/Other/:port/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/sensor/:port/:robot"] = sensorRequest(_:)
        //Finch only sensors
        server["/hummingbird/in/Line/:port"] = sensorRequest(_:)
        server["/hummingbird/in/Line/:port/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/Encoder/:port"] = sensorRequest(_:)
        server["/hummingbird/in/Encoder/:port/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/finchIsMoving/static"] = sensorRequest(_:)
        server["/hummingbird/in/finchIsMoving/static/:robot"] = sensorRequest(_:)
        //java/python only
        server["/hummingbird/in/isHummingbird/static/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/isMicrobit/static/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/isFinch/static/:robot"] = sensorRequest(_:)
        
    }
    
    private func sensorRequest (_ request: HttpRequest) -> HttpResponse {
        os_log("Sensor request [%{public}s]", log: log, type: .debug, request.path)
        let path = request.path.replacingOccurrences(of: "%20", with: " ")
        let params = path.split(separator: "/")
        let sensor = params[2]
        let port = (params.count > 3 ? String(params[3]) : "")
        
        var rIndex = 4
        if sensor == "Compass" { rIndex = 3 }
        guard let robot = getRobot(params: params, robotIndex: rIndex) else {
            return NOT_CONNECTED
        }
        
        switch sensor {
        case "button":
            let port = port.uppercased()
            switch port {
            case "A": return BackendServer.getRawResponse(String(robot.buttonA))
            case "B": return BackendServer.getRawResponse(String(robot.buttonB))
            case "LOGO":
                if robot.manageableRobot.hasV2Microbit {
                    return BackendServer.getRawResponse(String(robot.V2touch))
                } else {
                    return V2_REQUIRED
                }
            default: return BackendServer.getRawResponse("Invalid button", .badRequest(nil))
            }
        case "V2sensor":
            guard robot.manageableRobot.hasV2Microbit else {
                return V2_REQUIRED
            }
            switch port {
            case "Sound":
                return BackendServer.getRawResponse(String(robot.V2sound))
            case "Temperature":
                return BackendServer.getRawResponse(String(robot.V2temperature))
            default:
                return BackendServer.getRawResponse("Invalid V2 sensor", .badRequest(nil))
            }
        case "orientation":
            switch port {
            case "Screen Up": return BackendServer.getRawResponse(String(robot.accZ < -7.848))
            case "Screen Down": return BackendServer.getRawResponse(String(robot.accZ > 7.848))
            case "Tilt Left": return BackendServer.getRawResponse(String(robot.accX > 7.848))
            case "Tilt Right": return BackendServer.getRawResponse(String(robot.accX < -7.848))
            case "Logo Up": return BackendServer.getRawResponse(String(robot.accY < -7.848))
            case "Logo Down": return BackendServer.getRawResponse(String(robot.accY > 7.848))
            case "Shake": return BackendServer.getRawResponse(String(robot.shake))
            default:
                return BackendServer.getRawResponse("Invalid orientation", .badRequest(nil))
            }
        case "finchOrientation":
            guard let robot = robot as? Finch else {
                return NOT_CONNECTED
            }
            switch port {
            case "Beak Up": return BackendServer.getRawResponse(String(robot.accY > 7.848))
            case "Beak Down": return BackendServer.getRawResponse(String(robot.accY < -7.848))
            case "Tilt Left": return BackendServer.getRawResponse(String(robot.accX < -7.848))
            case "Tilt Right": return BackendServer.getRawResponse(String(robot.accX > 7.848))
            case "Level": return BackendServer.getRawResponse(String(robot.accZ < -7.848))
            case "Upside Down": return BackendServer.getRawResponse(String(robot.accZ > 7.848))
            case "Shake": return BackendServer.getRawResponse(String(robot.shake))
            default:
                return BackendServer.getRawResponse("Invalid finch orientation", .badRequest(nil))
            }
        case "Accelerometer", "finchAccel":
            if (sensor == "Accelerometer" && robot is Finch) ||
                (sensor == "finchAccel" && !(robot is Finch)) {
                return NOT_CONNECTED
            }
            switch port {
            case "X": return BackendServer.getRawResponse(String(robot.accX))
            case "Y": return BackendServer.getRawResponse(String(robot.accY))
            case "Z": return BackendServer.getRawResponse(String(robot.accZ))
            default:
                return INVALID_AXIS
            }
        case "Magnetometer", "finchMag":
            if (sensor == "Magnetometer" && robot is Finch) ||
                (sensor == "finchMag" && !(robot is Finch)) {
                return NOT_CONNECTED
            }
            switch port {
            case "X": return BackendServer.getRawResponse(String(robot.magX))
            case "Y": return BackendServer.getRawResponse(String(robot.magY))
            case "Z": return BackendServer.getRawResponse(String(robot.magZ))
            default:
                return INVALID_AXIS
            }
        case "Compass", "finchCompass":
            if (sensor == "Compass" && robot is Finch) ||
                (sensor == "finchCompass" && !(robot is Finch)) {
                return NOT_CONNECTED
            }
            return BackendServer.getRawResponse(String(robot.compass))
        case "Distance":
            // if there is a port number, it is a hummingbird request
            if let port = Int(port) {
                guard let robot = robot as? Hummingbird else { return NOT_CONNECTED }
                guard let rawValue = robot.getHummingbirdSensor(port) else { return NOT_CONNECTED }
                /*let value = Int(round(Double(rawValue) * (117/100)))
                return BackendServer.getRawResponse(String(value))*/
                return BackendServer.getRawResponse(String(rawValue))
            } else {
                guard let robot = robot as? Finch else { return NOT_CONNECTED }
                guard let distance = robot.finchDistance else { return NOT_CONNECTED }
                return BackendServer.getRawResponse(distance)
            }
        case "Dial":
            guard let robot = robot as? Hummingbird else { return NOT_CONNECTED }
            guard let port = Int(port) else { return INVALID_PORT }
            guard let rawValue = robot.getHummingbirdSensor(port) else { return NOT_CONNECTED }
            /*var scaledVal = Int( round(Double(rawValue) * (100 / 230)) )
            if scaledVal > 100 { scaledVal = 100 }
            return BackendServer.getRawResponse(String(scaledVal))*/
            return BackendServer.getRawResponse(String(rawValue))
        case "Light":
            switch params[3] {
            case "Right", "Left":
                guard let robot = robot as? Finch else { return NOT_CONNECTED }
                var onRight = false
                if params[3] == "Right" { onRight = true }
                guard let lightValue = robot.getFinchLight(onRight: onRight) else {
                    return NOT_CONNECTED
                }
                return BackendServer.getRawResponse(String(lightValue))
            case "1", "2", "3":
                guard let robot = robot as? Hummingbird else { return NOT_CONNECTED }
                guard let port = Int(port) else { return INVALID_PORT }
                guard let rawValue = robot.getHummingbirdSensor(port) else { return NOT_CONNECTED }
                /*let value = Double(rawValue) / 2.55
                return BackendServer.getRawResponse(String(value))*/
                return BackendServer.getRawResponse(String(rawValue))
            default: return INVALID_PORT
            }
        case "Sound":
            guard let robot = robot as? Hummingbird else { return NOT_CONNECTED }
            guard let port = Int(port) else { return INVALID_PORT }
            guard let rawValue = robot.getHummingbirdSensor(port) else { return NOT_CONNECTED }
            /*let value = Int( round(Double(rawValue) * (200/255)) )
            return BackendServer.getRawResponse(String(value))*/
            return BackendServer.getRawResponse(String(rawValue))
        case "Other":
            guard let robot = robot as? Hummingbird else { return NOT_CONNECTED }
            guard let port = Int(port) else { return INVALID_PORT }
            guard let rawValue = robot.getHummingbirdSensor(port) else { return NOT_CONNECTED }
            /*let value = Double(rawValue) * (3.3/255)
            return BackendServer.getRawResponse(String(value))*/
            return BackendServer.getRawResponse(String(rawValue))
        case "sensor": //used in java and python libraries
            guard let robot = robot as? Hummingbird else { return NOT_CONNECTED }
            guard let port = Int(port) else { return INVALID_PORT }
            guard let rawValue = robot.getHummingbirdSensor(port) else { return NOT_CONNECTED }
            return BackendServer.getRawResponse(String(rawValue))
        case "Line":
            guard let robot = robot as? Finch else { return NOT_CONNECTED }
            let onRight: Bool
            switch params[3] {
            case "Right": onRight = true
            case "Left": onRight = false
            default: return INVALID_PORT
            }
            guard let lineValue = robot.getFinchLine(onRight: onRight) else {
                return NOT_CONNECTED
            }
            return BackendServer.getRawResponse(String(lineValue))
        case "Encoder":
            guard let robot = robot as? Finch else { return NOT_CONNECTED }
            let onRight: Bool
            switch params[3] {
            case "Right": onRight = true
            case "Left": onRight = false
            default: return INVALID_PORT
            }
            guard let encoderValue = robot.getFinchEncoder(onRight: onRight) else {
                return NOT_CONNECTED
            }
            return BackendServer.getRawResponse(String(format: "%.2f", encoderValue))
        case "finchIsMoving":
            guard let robot = robot as? Finch, let isMoving = robot.isMoving else {
                return NOT_CONNECTED
            }
            return BackendServer.getRawResponse(String(isMoving))
        case "isMicrobit":
            return BackendServer.getRawResponse(String(robot is Microbit))
        case "isHummingbird":
            return BackendServer.getRawResponse(String(robot is Hummingbird))
        case "isFinch":
            return BackendServer.getRawResponse(String(robot is Finch))
        default:
            return BackendServer.getRawResponse("Invalid sensor selection", .badRequest(nil))
        }
    }
    
    
    
    private func triledRequest (_ request: HttpRequest) -> HttpResponse {
        os_log("Output request [%{public}s]", log: log, type: .debug, request.path)
        let params = request.path.split(separator: "/")
        let port = params[3]
        
        guard let robot = getRobot(params: params, robotIndex: 7) else {
            return NOT_CONNECTED
        }
        
        guard let R = UInt8(params[4]), let G = UInt8(params[5]), let B = UInt8(params[6]) else {
            os_log("Invalid params in request: R [%{public}s], G [%{public}s], B [%{public}s]", log: log, type: .error, String(params[4]), String(params[5]), String(params[6]))
            return INVALID_PARAMETERS
        }
        
        var success = false
        if let robot = robot as? Finch {
            if (port == "all") {
                success = robot.setTail(R: R, G: G, B: B)
                /*for i in 2 ..< 6 {
                    success = robot.setTriLED(port: i, R: R, G: G, B: B)
                }*/
            } else {
                guard let p = Int(port) else { return INVALID_PORT }
                success = robot.setTriLED(port: p, R: R, G: G, B: B)
            }
        } else if let robot = robot as? Hummingbird {
            guard let p = Int(port) else { return INVALID_PORT }
            success = robot.setTriLED(port: p, R: R, G: G, B: B)
        }
        
        if !success {
            return NOT_CONNECTED
        }
        
        return BackendServer.getRawResponse("triled set")
    }
    
    private func ledRequest (_ request: HttpRequest) -> HttpResponse {
        os_log("Output request [%{public}s]", log: log, type: .debug, request.path)
        let params = request.path.split(separator: "/")
        
        guard let robot = getRobot(params: params, robotIndex: 5) else {
            return NOT_CONNECTED
        }
        
        guard var intensity = Int(params[4]), let port = Int(params[3]) else {
            os_log("Invalid params in request: intensity [%{public}s], port [%{public}s]", log: log, type: .error, String(params[4]), String(params[3]))
            return INVALID_PARAMETERS
        }
        
        intensity = intensity.clamped(to: 0 ... 255)
        
        var success = false
        if let robot = robot as? Hummingbird {
            success = robot.setLED(port: port, intensity: UInt8(intensity))
        }
        
        if !success {
            return NOT_CONNECTED
        }
        
        return BackendServer.getRawResponse("led set")
    }
    
    private func printRequest (_ request: HttpRequest) -> HttpResponse {
        os_log("Output request [%{public}s]", log: log, type: .debug, request.path)
        let params = request.path.split(separator: "/")
        
        guard let robot = getRobot(params: params, robotIndex: 4) else {
            return NOT_CONNECTED
        }
        
        if robot.setPrint(params[3]) {
            return BackendServer.getRawResponse("print set")
        } else {
            return NOT_CONNECTED
        }
    }
    
    private func symbolRequest (_ request: HttpRequest) -> HttpResponse {
        os_log("Output request [%{public}s]", log: log, type: .debug, request.path)
        let params = request.path.split(separator: "/")

        guard let robot = getRobot(params: params, robotIndex: 3) else {
            return NOT_CONNECTED
        }
        
        var symbol = ""
        for i in 0..<25 {
            symbol += params[4+i] == "true" ? "1" : "0"
        }
        if robot.setSymbol(symbol) {
            return BackendServer.getRawResponse("symbol set")
        } else {
            return NOT_CONNECTED
        }
    }
    
    private func playNoteRequest(_ request: HttpRequest) -> HttpResponse {
        os_log("Output request [%{public}s]", log: log, type: .debug, request.path)
        let params = request.path.split(separator: "/")

        guard let robot = getRobot(params: params, robotIndex: 5) else {
            return NOT_CONNECTED
        }
        guard let note = Int(params[3]), let duration = Int(params[4]) else {
            os_log("Invalid params in request: duration [%{public}s], note [%{public}s]", log: log, type: .error, String(params[4]), String(params[3]))
            return INVALID_PARAMETERS
        }
        
        if robot.setBuzzer(note: note, duration: duration) {
            return BackendServer.getRawResponse("buzzer set")
        } else {
            return NOT_CONNECTED
        }
    }
    
    private func servoRequest(_ request: HttpRequest) -> HttpResponse {
        os_log("Output request [%{public}s]", log: log, type: .debug, request.path)
        let params = request.path.split(separator: "/")

        guard let robot = getRobot(params: params, robotIndex: 5) as? Hummingbird else {
            return NOT_CONNECTED
        }
        
        guard var value = Int(params[4]), let port = Int(params[3]) else {
            os_log("Invalid params in request: value [%{public}s], port [%{public}s]", log: log, type: .error, String(params[4]), String(params[3]))
            return INVALID_PARAMETERS
        }
        //All scaling is done for servos before requests are made.
        value = value.clamped(to: 0 ... 255)
        
        if robot.setServo(port: port, value: UInt8(value)) {
            return BackendServer.getRawResponse("servo set")
        } else {
            return NOT_CONNECTED
        }
    }
    
    private func stopAllRequest(_ request: HttpRequest) -> HttpResponse {
        os_log("Output request [%{public}s]", log: log, type: .debug, request.path)
        let params = request.path.split(separator: "/")
        
        guard let robot = getRobot(params: params, robotIndex: 3) else {
            return NOT_CONNECTED
        }
        
        if robot.stopAll() {
            return BackendServer.getRawResponse("all stopped")
        } else {
            return NOT_CONNECTED
        }
    }
    
    
    private func finchMove (_ request: HttpRequest) -> HttpResponse {
        os_log("Output request [%{public}s]", log: log, type: .debug, request.path)
        let params = request.path.split(separator: "/")
        
        guard let robot = getRobot(params: params, robotIndex: 3) as? Finch else {
            return NOT_CONNECTED
        }
        
        let direction = String(params[4])
        guard let distance = Double(params[5]), let speed = Double(params[6]), (direction == "Forward" || direction == "Backward") else {
            os_log("Invalid params in request: direction [%{public}s], distance [%{public}s], speed [%{public}s]", log: log, type: .error, direction, String(params[5]), String(params[6]))
            return INVALID_PARAMETERS
        }
        
        let shouldFlip = (distance < 0)
        let shouldGoForward = (direction == "Forward" && !shouldFlip) || (direction == "Backward" && shouldFlip)
        let shouldGoBackward = (direction == "Backward" && !shouldFlip) || (direction == "Forward" && shouldFlip)
        let moveTicks = Int(round(abs(distance * FinchConstants.FINCH_TICKS_PER_CM)))
        
        var success = true
        if (moveTicks != 0) { //ticks=0 is the command for continuous motion
            if (shouldGoForward) {
                success = robot.setMotors(leftSpeed: speed, leftTicks: moveTicks, rightSpeed: speed, rightTicks: moveTicks)
            } else if (shouldGoBackward) {
                success = robot.setMotors(leftSpeed: -speed, leftTicks: moveTicks, rightSpeed: -speed, rightTicks: moveTicks)
            }
        }
        if success {
            return BackendServer.getRawResponse("finch moved")
        } else {
            return NOT_CONNECTED
        }
    }
    
    private func finchTurn (_ request: HttpRequest) -> HttpResponse {
        os_log("Output request [%{public}s]", log: log, type: .debug, request.path)
        let params = request.path.split(separator: "/")
        
        guard let robot = getRobot(params: params, robotIndex: 3) as? Finch else {
            return NOT_CONNECTED
        }
        
        let direction = String(params[4])
        guard let angle = Double(params[5]), let speed = Double(params[6]), (direction == "Right" || direction == "Left") else {
            os_log("Invalid params in request: direction [%{public}s], angle [%{public}s], speed [%{public}s]", log: log, type: .error, direction, String(params[5]), String(params[6]))
            return INVALID_PARAMETERS
        }
        
        let shouldFlip = (angle < 0)
        let shouldTurnRight = (direction == "Right" && !shouldFlip) || (direction == "Left" && shouldFlip)
        let shouldTurnLeft = (direction == "Left" && !shouldFlip) || (direction == "Right" && shouldFlip)
        let turnTicks = Int(round(abs(angle * FinchConstants.FINCH_TICKS_PER_DEGREE)))
        
        var success = true
        if (turnTicks != 0) { //ticks=0 is the command for continuous motion
            if (shouldTurnRight) {
                success = robot.setMotors(leftSpeed: speed, leftTicks: turnTicks, rightSpeed: -speed, rightTicks: turnTicks)
            } else if (shouldTurnLeft) {
                success = robot.setMotors(leftSpeed: -speed, leftTicks: turnTicks, rightSpeed: speed, rightTicks: turnTicks);
            }
        }
        if success {
            return BackendServer.getRawResponse("finch turned")
        } else {
            return NOT_CONNECTED
        }
    }
    
    private func finchWheels (_ request: HttpRequest) -> HttpResponse {
        os_log("Output request [%{public}s]", log: log, type: .debug, request.path)
        let params = request.path.split(separator: "/")
        
        guard let robot = getRobot(params: params, robotIndex: 3) as? Finch else {
            return NOT_CONNECTED
        }
        
        guard let leftSpeed = Double(params[4]), let rightSpeed = Double(params[5]) else {
            os_log("Invalid params in request: left speed [%{public}s], right speed [%{public}s]", log: log, type: .error, String(params[4]), String(params[5]))
            return INVALID_PARAMETERS
        }
        
        if robot.setMotors(leftSpeed: leftSpeed, leftTicks: 0, rightSpeed: rightSpeed, rightTicks: 0) {
            return BackendServer.getRawResponse("finch wheels started")
        } else {
            return NOT_CONNECTED
        }
    }
    /**
        Just stop the motors (finch only)
     */
    private func stopFinch (_ request: HttpRequest) -> HttpResponse {
        os_log("Output request [%{public}s]", log: log, type: .debug, request.path)
        let params = request.path.split(separator: "/")
        
        guard let robot = getRobot(params: params, robotIndex: 3) as? Finch else {
            return NOT_CONNECTED
        }
        
        if robot.setMotors(leftSpeed: 0, leftTicks: 0, rightSpeed: 0, rightTicks: 0) {
            return BackendServer.getRawResponse("finch wheels stopped")
        } else {
            return NOT_CONNECTED
        }
    }
    
    private func resetEncoders (_ request: HttpRequest) -> HttpResponse {
        os_log("Output request [%{public}s]", log: log, type: .debug, request.path)
        let params = request.path.split(separator: "/")
        
        guard let robot = getRobot(params: params, robotIndex: 3) as? Finch else {
            return NOT_CONNECTED
        }
        
        if robot.resetEncoders() {
            return BackendServer.getRawResponse("finch encoders reset")
        } else {
            return NOT_CONNECTED
        }
    }
    
    
    //MARK: Requests coming directly from frontend
    
    public func calibrateRobot(devLetter: String) {
        guard let robot = getRobot(params: [devLetter.prefix(1)], robotIndex: 0) else {
            return
        }
        
        robot.startCalibration()
    }
    
    
    
    //MARK: Helper functions
    private static func getRawResponse(_ text: String, _ type: HttpResponse? = nil) -> HttpResponse {
        os_log("Raw response [%{public}s]", log: OSLog.default, type: .debug, text)
        if let type = type {
            return .raw(type.statusCode, type.reasonPhrase, ["Access-Control-Allow-Origin": "*", "Content-Type": "text/plain"], { writer in
                try? writer.write([UInt8](text.utf8))
            })
        } else { //assume .ok if no type specified
            return .raw(200, "OK", ["Access-Control-Allow-Origin": "*", "Content-Type": "text/plain"], { writer in
                try? writer.write([UInt8](text.utf8))
            })
        }
    }
    
    
    
    private func getRobot(params: [Substring], robotIndex: Int) -> Robot? {
        var devLetterString = "A"
        if params.count > robotIndex {
            devLetterString = String(params[robotIndex])
        }
        
        guard let devLetter = DeviceLetter.fromString(devLetterString) else {
            os_log("Invalid device letter [%{public}s] in request", log: log, type: .error, devLetterString)
            return nil
        }
        guard let robot = connectedRobots[devLetter] else {
            os_log("No robot in position [%{public}s]", log: log, type: .error, devLetterString)
            return nil
        }
        return robot
    }
    
    //MARK: Snap!

    private func handleSnapRequest (_ request: HttpRequest) -> HttpResponse {
        
        //let params = request.path.split(separator: "/")
        //print(params)
        
        guard var snapPath = Bundle.main.resourcePath else {
            return .notFound
        }
        snapPath += "/Snap-6.1.4"
        
        let filePath = snapPath + request.path.dropFirst(5)
        os_log("looking for [%{public}s]", log: log, type: .debug, filePath)
        if let file = try? filePath.openForReading() {
            os_log("file path found", log: log, type: .debug)
            let mimeType = filePath.mimeType()
            var responseHeader: [String: String] = ["Content-Type": mimeType]
            
            if let attr = try? FileManager.default.attributesOfItem(atPath: filePath),
                let fileSize = attr[FileAttributeKey.size] as? UInt64 {
                responseHeader["Content-Length"] = String(fileSize)
            }
            //print(responseHeader)
            return .raw(200, "OK", responseHeader, { writer in
                do {
                    try writer.write(file)
                    file.close()
                } catch {
                    os_log("Error writing snap response [%{public}s]", log: self.log, type: .error, error.localizedDescription)
                }
            })
        }
        
        return .notFound
    }
    
    
    
}


