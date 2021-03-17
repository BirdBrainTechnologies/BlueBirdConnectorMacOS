
/**
 * sendMessageToBackend - Send a message of a given type to backend
 *
 * @param  {msgTypes} type    The type of message
 * @param  {Object} details   Object containing all message details
 */
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

/**
 * Send javascript errors to the backend.
 */
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

/**
 * Let the backend know that the document has resized.
 */
window.onresize = () => {
  sendMessageToBackend(msgTypes.DOCUMENT_STATUS, {
    documentStatus: "onresize",
    innerWidth: window.innerWidth,
    innerHeight: window.innerHeight
  })
}


/**
 * Object to hold all possible callbacks from the backend.
 */
CallbackManager = {}

/**
 * CallbackManager.scanStarted - Ble scanning has started. Update display.
 */
CallbackManager.scanStarted = function() {
  scanDeviceList = []
  if (!($('#find-button i').hasClass('fa-spin'))){
    $('#find-button i').addClass('fa-spin');
    $('#findBtnText').text(" "+translationTable["finding_robots"]);
  }
  updateBleStatus(true);
  closeModal();
}

/**
 * CallbackManager.scanEnded - Ble scanning has ended. Update display.
 */
CallbackManager.scanEnded = function() {
  if ($('#find-button i').hasClass('fa-spin')) {
    $('#find-button i').removeClass('fa-spin');
    $('#findBtnText').text(" "+translationTable["find_robots"]);
  }
}

/**
 * CallbackManager.bleDisabled - Computer's ble has been disabled. Update
 * display and show instructions to enable.
 */
CallbackManager.bleDisabled = function() {
  updateBleStatus(false);
  CallbackManager.scanEnded();
  scanDeviceList = []
  connectedDeviceList = []
  $.scanListRefresh();
  $.connectedDevListRefresh();
  launchNativeMacOSBLEvideo();
}

/**
 * CallbackManager.updateScanDeviceList - Update displayed list of available
 * devices.
 *
 * @param  {array} newList list of currently available devices.
 */
CallbackManager.updateScanDeviceList = function(newList) {
  /*sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "devices available: " + newList.map(i => JSON.stringify(i))
  })*/
  scanDeviceList = newList

  scanDeviceList.sort(function(a, b) {
    return (a.rssi < b.rssi) - (a.rssi > b.rssi);
  });

  $.scanListRefresh();
}

/**
 * CallbackManager.deviceDidConnect - A connection has been established to the
 * given device. Update lists.
 *
 * @param  {string} address   device uuid
 * @param  {string} name      device advertised name
 * @param  {string} fancyName device memorable name
 * @param  {string} devLetter letter assigned to device
 */
CallbackManager.deviceDidConnect = function(address, name, fancyName, devLetter, hasV2) {
  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "device did connect: " + address + ", " + name + ", " + fancyName + ", " + devLetter + ", " + hasV2
  })
  connectedDeviceList.push({
    deviceAddress: address,
    deviceFancyName: fancyName,
    deviceName: name,
    devLetter: devLetter,
    hasV2: hasV2,
    batteryStatus: "unknown"
  })
  $.connectedDevListRefresh()
  scanDeviceList.forEach((device, i) => {
    if (device.address == address) {
      scanDeviceList.splice(i, 1)
    }
  });
  $.scanListRefresh();
}

/**
 * CallbackManager.deviceDidDisconnect - Connection to specified device lost.
 * Update lists.
 *
 * @param  {type} address description
 * @return {type}         description
 */
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
  $.scanListRefresh();
}

/**
 * CallbackManager.deviceBatteryUpdate - New battery status information received
 * from device. Update display.
 *
 * @param  {string} address       uuid of updated device
 * @param  {string} batteryStatus new status
 */
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

/**
 * CallbackManager.showCalibrationResult - Calibration completed with given
 * result. Display result to calibration modal.
 *
 * @param  {boolean} success true if calibraton succeeded
 */
CallbackManager.showCalibrationResult = function(success) {
  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "calibration result " + success + " is a " + (typeof success)
  })
  var ha = $('#calibrate-modal .animation').height();
  var hi = $('#calibrate-modal .animation i').height();
  $('#calibrate-modal .animation i').css('marginTop', ((ha-hi)/2)+'px');
  if (success) {
    $('#calibrate-modal .status').addClass('status-success');
    setTimeout(function() { closeModal(); }, 3000);
  } else {
    $('#calibrate-modal .status').addClass('status-fail');
  }
}
