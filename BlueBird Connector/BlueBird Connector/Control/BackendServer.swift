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
    //private let INVALID_DEVICE_LETTER = getRawResponse("Invalid device letter", .badRequest(nil))
    private let INVALID_PARAMETERS = getRawResponse("Invalid parameters", .badRequest(nil))
    private let INVALID_PORT = getRawResponse("Invalid port", .badRequest(nil))
    private let INVALID_AXIS = getRawResponse("Invalid axis", .badRequest(nil))
    
    public init() {
        server = HttpServer()
        server.notFoundHandler = { request in
            os_log("Invalid request [%s]", log: self.log, type: .error, request.path)
            return .notFound
        }
        
        setupPaths()
        
        do {
            try server.start(30061)
            print("Server has started ( port = \(try server.port()) ). Try to connect now...")
        } catch {
            os_log("Server start error: [%s]", log: log, type: .error, error.localizedDescription)
        }
        
    }
    
    private func setupPaths() {
        
        server["/hummingbird/out/move/:robot/:dir/:dist/:speed"] = finchMove(_:)
        server["/hummingbird/out/triled/:port/:R/:G/:B"] = triledRequest(_:)
        
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
        //Finch only
        server["/hummingbird/in/Line/:port"] = sensorRequest(_:)
        server["/hummingbird/in/Line/:port/:robot"] = sensorRequest(_:)
        server["/hummingbird/in/Encoder/:port"] = sensorRequest(_:)
        server["/hummingbird/in/Encoder/:port/:robot"] = sensorRequest(_:)
        
    }
    
    private func sensorRequest (_ request: HttpRequest) -> HttpResponse {
        let params = request.path.split(separator: "/")
        let sensor = params[2]
        let port = String(params[3])
        
        var letter = "A"
        if params.count > 4 {
            letter = String(params[4])
        }
        if sensor == "Compass", params.count > 3 {
            letter = String(params[3])
        }
        guard let robot = getRobot(devLetterString: letter) else {
            return NOT_CONNECTED
        }
        
        switch sensor {
        case "button":
            switch port {
            case "A": return BackendServer.getRawResponse(String(robot.buttonA))
            case "B": return BackendServer.getRawResponse(String(robot.buttonB))
            default: return BackendServer.getRawResponse("Invalid button", .badRequest(nil))
            }
        case "orientation":
            if robot is Finch { return NOT_CONNECTED }
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
                let value = Int(round(Double(rawValue) * (117/100)))
                return BackendServer.getRawResponse(String(value))
            } else {
                guard let robot = robot as? Finch else { return NOT_CONNECTED }
                guard let distance = robot.finchDistance else { return NOT_CONNECTED }
                return BackendServer.getRawResponse(String(distance))
            }
        case "Dial":
            guard let robot = robot as? Hummingbird else { return NOT_CONNECTED }
            guard let port = Int(port) else { return INVALID_PORT }
            guard let rawValue = robot.getHummingbirdSensor(port) else { return NOT_CONNECTED }
            var scaledVal = Int( round(Double(rawValue) * (100 / 230)) )
            if scaledVal > 100 { scaledVal = 100 }
            return BackendServer.getRawResponse(String(scaledVal))
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
                let value = Double(rawValue) / 2.55
                return BackendServer.getRawResponse(String(value))
            default: return INVALID_PORT
            }
        case "Sound":
            guard let robot = robot as? Hummingbird else { return NOT_CONNECTED }
            guard let port = Int(port) else { return INVALID_PORT }
            guard let rawValue = robot.getHummingbirdSensor(port) else { return NOT_CONNECTED }
            let value = Int( round(Double(rawValue) * (200/255)) )
            return BackendServer.getRawResponse(String(value))
        case "Other":
            guard let robot = robot as? Hummingbird else { return NOT_CONNECTED }
            guard let port = Int(port) else { return INVALID_PORT }
            guard let rawValue = robot.getHummingbirdSensor(port) else { return NOT_CONNECTED }
            let value = Double(rawValue) * (3.3/255)
            return BackendServer.getRawResponse(String(value))
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
        default:
            return BackendServer.getRawResponse("Invalid sensor selection", .badRequest(nil))
        }
    }
    
    
    
    private func triledRequest (_ request: HttpRequest) -> HttpResponse {
        os_log("triled request [%s]", log: log, type: .debug, request.path)
        
        let params = request.path.split(separator: "/")
        let port = params[3]
        
        var letter = "A"
        if params.count > 7 {
            letter = String(params[7])
        }
        guard let robot = getRobot(devLetterString: letter) else {
            //return HttpResponse.badRequest(.text("Invalid device letter"))
            return NOT_CONNECTED
        }
        
        guard let R = Int(params[4]), let G = Int(params[5]), let B = Int(params[6]) else {
            os_log("Invalid params in request: R [%s], G [%s], B [%s]", log: log, type: .error, String(params[4]), String(params[5]), String(params[6]))
            //return HttpResponse.badRequest(.text("Invalid params"))
            return INVALID_PARAMETERS
        }
        
        if let robot = robot as? Finch {
            if (port == "all") {
                for i in 1 ..< 4 {
                    robot.setTriLED(port: i, R: R, G: G, B: B)
                }
            } else {
                guard let p = Int(port) else { return INVALID_PORT }
                robot.setTriLED(port: p, R: R, G: G, B: B)
            }
        } else if let robot = robot as? Hummingbird {
            guard let p = Int(port) else { return INVALID_PORT }
            robot.setTriLED(port: p, R: R, G: G, B: B)
        } else {
            return NOT_CONNECTED
        }
        
        //return HttpResponse.ok(.text("triled set"))
        return BackendServer.getRawResponse("triled set")
    }
    
    private static func getRawResponse(_ text: String, _ type: HttpResponse? = nil) -> HttpResponse {
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
    
    private func finchMove (_ request: HttpRequest) -> HttpResponse {
        print ("Got a request \(request.path)")
        
        let params = request.path.split(separator: "/")
        let letter = String(params[3])
        let direction = String(params[4])
        
        guard let devLetter = DeviceLetter.fromString(letter),
            let robot = connectedRobots[devLetter] as? Finch else {
            os_log("Invalid device letter [%s] in request", log: log, type: .error, letter)
            return HttpResponse.badRequest(.text("Invalid device letter"))
        }
        guard let distance = Double(params[5]), let speed = Double(params[6]), (direction == "Forward" || direction == "Backward") else {
            os_log("Invalid params in request: direction [%s], distance [%s], speed [%s]", log: log, type: .error, direction, String(params[5]), String(params[6]))
            return HttpResponse.badRequest(.text("Invalid params"))
        }
        
        let shouldFlip = (distance < 0)
        let shouldGoForward = (direction == "Forward" && !shouldFlip) || (direction == "Backward" && shouldFlip);
        let shouldGoBackward = (direction == "Backward" && !shouldFlip) || (direction == "Forward" && shouldFlip);
        let moveTicks = Int(round(abs(distance * FinchConstants.FINCH_TICKS_PER_CM)))
        
        robot.setMotors(leftSpeed: speed, leftTicks: moveTicks, rightSpeed: speed, rightTicks: moveTicks)
        
        return HttpResponse.ok(.text("move set"))
    }
    
    private func getRobot(devLetterString: String) -> Robot? {
        guard let devLetter = DeviceLetter.fromString(devLetterString) else {
            os_log("Invalid device letter [%s] in request", log: log, type: .error, devLetterString)
            return nil
        }
        guard let robot = connectedRobots[devLetter] else {
            os_log("No robot in position [%s]", log: log, type: .error, devLetterString)
            return nil
        }
        return robot
    }
}
