//
//  AppDelegate.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 6/30/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Cocoa
import IOKit.pwr_mgt
import os

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "AppDelegate")

    var noSleepAssertionID: IOPMAssertionID = 0

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        //Keep app awake. See
        //https://stackoverflow.com/questions/37601453/using-swift-to-disable-sleep-screen-saver-for-osx/46519646#46519646
        let noSleepReturn = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep as CFString,
                                                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                        "Stay awake to allow BlueBird Connector to run long programs" as CFString,
                                                        &noSleepAssertionID)
        os_log("Keep awake set? [%s]", log: log, type: .debug, String(noSleepReturn == kIOReturnSuccess))
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    /**
        When someone clicks the x on the BlueBird window, shut down the whole program.
     */
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true;
    }
}

