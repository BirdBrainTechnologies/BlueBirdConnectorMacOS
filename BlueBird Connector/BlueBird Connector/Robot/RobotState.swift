//
//  RobotState.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 7/31/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation

struct RobotState: Equatable {
    
    private let robotType: RobotType
    
    init(robotType: RobotType) {
        self.robotType = robotType
    }

}

struct TriLED: Equatable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    
    init(_ inRed: UInt8, _ inGreen: UInt8, _ inBlue: UInt8) {
        red = inRed
        green = inGreen
        blue = inBlue
    }
    
    static func ==(lhs: TriLED, rhs: TriLED) -> Bool {
        return lhs.red == rhs.red && lhs.green == rhs.green && lhs.blue == rhs.blue
    }
}
