function sendMessageToBackend(type, details) {
  this.message = details
  this.message.type = type

  if (window.webkit) {
    window.webkit.messageHandlers.serverSubstitute.postMessage(this.message);
  } else {
    console.error("window.webkit missing. ", this.message);
  }
}
const msgTypes = {
  CONSOLE_LOG: "console log",
  ERROR: "error",
  DOCUMENT_STATUS: "document status",
  COMMAND: "command"
}

window.onerror = (msg, url, line, column, error) => {
  const message = {
    message: msg,
    url: url,
    line: line,
    column: column,
    error: JSON.stringify(error)
  }

  if (window.webkit) {
    sendMessageToBackend(msgTypes.ERROR, message);
  } else {
    console.log("Error:", message);
  }

};

window.onresize = () => {
  sendMessageToBackend(msgTypes.DOCUMENT_STATUS, {
    documentStatus: "onresize",
    innerWidth: window.innerWidth,
    innerHeight: window.innerHeight
  })
}


CallbackManager = {}

CallbackManager.scanStarted = function() {
  scanDeviceList = []
  if (!($('#find-button i').hasClass('fa-spin'))){
    $('#find-button i').addClass('fa-spin');
    $('#findBtnText').text(" "+translationTable["finding_robots"]);
  }
  updateBleStatus(true);
}
CallbackManager.scanEnded = function() {
  if ($('#find-button i').hasClass('fa-spin')) {
    $('#find-button i').removeClass('fa-spin');
    $('#findBtnText').text(" "+translationTable["find_robots"]);
  }
}
CallbackManager.bleDisabled = function() {
  updateBleStatus(false);
  CallbackManager.scanEnded();
  scanDeviceList = []
  $.scanListRefresh();
}
CallbackManager.updateScanDeviceList = function(newList) {
  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "devices available: " + newList
  })
  scanDeviceList = newList

  scanDeviceList.sort(function(a, b) {
    //return (a.address > b.address) - (a.address < b.address);
    return (a.rssi < b.rssi) - (a.rssi > b.rssi);
  });

  $.scanListRefresh();
}
CallbackManager.deviceDidConnect = function(address, name, fancyName, devLetter) {
  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "device did connect: " + address + ", " + name + ", " + fancyName + ", " + devLetter
  })
  connectedDeviceList.push({
    deviceAddress: address,
    deviceFancyName: fancyName,
    deviceName: name,
    devLetter: devLetter,
    batteryStatus: "unknown"
  })
  $.connectedDevListRefresh()
}
CallbackManager.deviceDidDisconnect = function(address) {
  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "device did disconnect: " + address
  })
  connectedDeviceList.forEach( (device, i) => {
    if (device.deviceAddress == address) {
      connectedDeviceList.splice(i, 1)
    }
  })
  $.connectedDevListRefresh()
}
CallbackManager.deviceBatteryUpdate = function(address, batteryStatus) {
  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "device battery update: " + address + " -> " + batteryStatus
  })
  connectedDeviceList.forEach( (device) => {
    if (device.deviceAddress == address) {
      device.batteryStatus = batteryStatus
    }
  })
  $.connectedDevListRefresh()
}
