# BlueBirdConnectorMacOS
Native macOS BlueBirdConnector App

Swifter notes:
As of Aug. 2020, Swifter doesn't serve regular files with app sandboxing turned on. See [issue #344](https://github.com/httpswift/swifter/issues/344). To make this work for now, download the currently linked package release (the release number is listed next to the package name in the Swift Package Dependencies section at the bottom of the navigator area). Change the folder name to exactly match what is listed in the navigator area (without the release number). Drag the package folder just inside the main project in the navigator. You should see the package dependency disappear in the Swift Package Dependencies section. Now, modify the file Swifter/XCode/Sources/Socket+File.swift to include os(macOS) on lines 10 and 43. You should now be able to run snap! offline.

Distributing to Testers:
Distribution to testers is easiest if you archive, notarize, and then wrap as a dmg. To do this:
1. Create an archive in Xcode.
2. Notarize in the Organizer (choose Distribute App, then Developer ID).
3. Once notarized, go through same path in the Organizer to export.
4. Copy the files in this project's 'Packages' folder into the exported folder.
5. In terminal, create the dmg with the command 'appdmg appdmg.json BlueBirdConnector.dmg'

General Debugging Tips:
You can see os_logs in the Console app (see https://stackoverflow.com/questions/40272910/read-logs-using-the-new-swift-os-log-api/40744462#40744462). Make sure to include info and debug messages in the Action menu. You may also need to enable debug messages in terminal with the command 'sudo log config --subsystem com.birdbraintechnologies.BlueBird-Connector --mode level:debug' (see https://stackoverflow.com/questions/46660112/viewing-os-log-messages-in-device-console). Also note that all dynamic information is considered private unless specified otherwise.
