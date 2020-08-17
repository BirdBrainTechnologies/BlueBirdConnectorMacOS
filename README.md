# BlueBirdConnectorMacOS
Native macOS BlueBirdConnector App

Swifter notes:
As of Aug. 2020, Swifter doesn't serve regular files with app sandboxing turned on. See [issue #344](https://github.com/httpswift/swifter/issues/344). To make this work for now, download the currently linked package release (the release number is listed next to the package name in the Swift Package Dependencies section at the bottom of the navigator area). Change the folder name to exactly match what is listed in the navigator area (without the release number). Drag the package folder just inside the main project in the navigator. You should see the package dependency disappear in the Swift Package Dependencies section. Now, modify the file Swifter/XCode/Sources/Socket+File.swift to include os(macOS) on lines 10 and 43. You should now be able to run snap! offline.
