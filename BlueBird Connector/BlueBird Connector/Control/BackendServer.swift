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
    
    let server: HttpServer
    var connectedRobots = [DeviceLetter: Robot]()
    
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
        server["/hummingbird/in/button/:btn"] = sensorRequest(_:)
        
    }
    
    private func sensorRequest (_ request: HttpRequest) -> HttpResponse {
        return getRawResponse(text: "true")
    }
    
    
    private func triledRequest (_ request: HttpRequest) -> HttpResponse {
        os_log("triled request [%s]", log: log, type: .debug, request.path)
        
        let params = request.path.split(separator: "/")
        let port = params[3]
        
        var letter = "A"
        if params.count > 7 {
            letter = String(params[7])
        }
        guard let robot = getRobot(devLetterString: letter, acceptedTypes: [.Finch, .Hummingbird]) else {
            return HttpResponse.badRequest(.text("Invalid device letter"))
        }
        
        guard let R = Int(params[4]), let G = Int(params[5]), let B = Int(params[6]) else {
            os_log("Invalid params in request: R [%s], G [%s], B [%s]", log: log, type: .error, String(params[4]), String(params[5]), String(params[6]))
            return HttpResponse.badRequest(.text("Invalid params"))
        }
        
        if (port == "all") {
            for i in 1 ..< 4 {
                robot.setTriLED(port: i, R: R, G: G, B: B)
            }
        } else if let p = Int(port) {
            robot.setTriLED(port: p, R: R, G: G, B: B)
        } else {
            return HttpResponse.badRequest(.text("Invalid port"))
        }
        
        //return HttpResponse.ok(.text("triled set"))
        return getRawResponse(text: "triled set")
    }
    
    private func getRawResponse(text: String) -> HttpResponse {
        return .raw(200, "OK", ["Access-Control-Allow-Origin": "*"], { writer in
            try? writer.write([UInt8](text.utf8))
        })
    }
    
    private func finchMove (_ request: HttpRequest) -> HttpResponse {
        print ("Got a request \(request.path)")
        
        let params = request.path.split(separator: "/")
        let letter = String(params[3])
        let direction = String(params[4])
        
        guard let devLetter = DeviceLetter.fromString(letter),
            let robot = connectedRobots[devLetter] else {
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
        let moveTicks = Int(round(abs(distance * Robot.FINCH_TICKS_PER_CM)))
        
        robot.setMotors(leftSpeed: speed, leftTicks: moveTicks, rightSpeed: speed, rightTicks: moveTicks)
        
        return HttpResponse.ok(.text("move set"))
    }
    
    private func getRobot(devLetterString: String, acceptedTypes: [RobotType]) -> Robot? {
        guard let devLetter = DeviceLetter.fromString(devLetterString),
            let robot = connectedRobots[devLetter] else {
            os_log("Invalid device letter [%s] in request", log: log, type: .error, devLetterString)
            return nil
        }
        guard acceptedTypes.contains(robot.type) else {
            os_log("Robot requested is of incompatable type", log: log, type: .error)
            return nil
        }
        
        return robot
    }
}
