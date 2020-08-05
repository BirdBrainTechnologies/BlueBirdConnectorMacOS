//
//  SetAllTimer.swift
//  BlueBird Connector
//  see https://medium.com/over-engineering/a-background-repeating-timer-in-swift-412cecfd2ef9
//
//  Created by Kristina Lauwers on 8/4/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import os

class SetAllTimer {
    let timeInterval: TimeInterval = 0.03
    var robot: Robot?
    var eventHandler: (() -> Void)?
    
    init() {
        eventHandler = {
            self.robot?.setAll()
        }
    }
    func setRobot(_ robot: Robot) {
        self.robot = robot
    }

    private lazy var timer: DispatchSourceTimer = {
        let t = DispatchSource.makeTimerSource()
        t.schedule(deadline: .now() + self.timeInterval, repeating: self.timeInterval)
        t.setEventHandler(handler: { [weak self] in
            self?.eventHandler?()
        })
        return t
    }()

    

    private enum State {
        case suspended
        case resumed
    }

    private var state: State = .suspended

    deinit {
        timer.setEventHandler {}
        timer.cancel()
        /*
         If the timer is suspended, calling cancel without resuming
         triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
         */
        resume()
        eventHandler = nil
    }

    func resume() {
        if state == .resumed {
            return
        }
        state = .resumed
        timer.resume()
    }

    func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        timer.suspend()
    }
}
