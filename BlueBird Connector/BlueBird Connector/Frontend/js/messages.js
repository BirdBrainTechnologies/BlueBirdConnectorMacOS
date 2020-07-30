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
CallbackManager.deviceDiscovered = function(address, name, fancyName, rssi) {
  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "device discovered: " + address + ", " + name + ", " + fancyName + ", " + rssi
  })
  scanDeviceList.push({
    address: address,
    name: name,
    fancyName: fancyName,
    rssi: rssi
  })

  scanDeviceList.sort(function(a, b) {
    //return (a.address > b.address) - (a.address < b.address);
    return (a.rssi < b.rssi) - (a.rssi > b.rssi);
  });

  $.scanListRefresh();
}
CallbackManager.deviceDidDisappear = function(address) {
  scanDeviceList.forEach( (device, i) => {
    if (device.address == address) {
      scanDeviceList.splice(i, 1)
    }
  })

  $.scanListRefresh()
}
CallbackManager.deviceDidConnect = function(address, name, fancyName, devLetter) {
  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "device did connect: " + address + ", " + name + ", " + fancyName + ", " + devLetter
  })
  connectedDeviceList.push({
    deviceAddress: address,
    deviceFancyName: fancyName,
    deviceName: name,
    devLetter: devLetter
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
