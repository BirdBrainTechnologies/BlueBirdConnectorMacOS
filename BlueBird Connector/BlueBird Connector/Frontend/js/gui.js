var connectedDeviceList = [];
var scanDeviceList = [];

//Table to use for translations
var translationTable = null;
var language = "en";

//HTML code to string conversion tool:  http://pojo.sodhanalibrary.com/string.html
var connectButton =
      "              <div class=\"col-xs-2 buttons\">"+
      "                 <a class=\"button\" href=\"#\"><span class=\"button-connect fa-stack fa-2x\">"+
      "                   <i class=\"fas fa-circle fa-stack-2x\"></i>"+
      "                   <i class=\"fas fa-plus fa-stack-1x fa-inverse\"></i>"+
      "                 </span></a>"+
//      "               </div>"+
      "             </div>";



/**
 * This function runs as soon as the document is ready. It sends a message to
 * the backend, informing it of that status. It sets the language and checks
 * whether the internet is connected.
 */
$(document).ready(function() {

  sendMessageToBackend(msgTypes.DOCUMENT_STATUS, {
    documentStatus: "READY",
    language: navigator.language,
    languages: navigator.languages
  })

  setLanguage();
  updateInternetStatus();
  setInterval(updateInternetStatus, 2000)

  $.connectedDevListRefresh();

  // Scan button - "find robots"
  $('#find-button').on('click', function(e) {
    $('#robots-found').empty();
    sendMessageToBackend(msgTypes.CONSOLE_LOG, {
      consoleLog: "find-button clicked"
    })
    setConnectingState("Connected");
    var newScanState = null;
    if ($('#find-button i').hasClass("fa-spin"))
      newScanState = 'off';
    else
      newScanState = 'on';

    var data = {
      'command': 'scan',
      'scanState': newScanState,
    }
    sendMessageToBackend(msgTypes.CONSOLE_LOG, {
      consoleLog: "Turning scan " + newScanState
    })
    sendMessageToBackend(msgTypes.COMMAND, data)
    $.scanListRefresh();
  });

  //Set up the snap button
  $('#programming-buttons .launch-snap-btn').on('click', function(e) {
    launchSnap();
  });

  //Set up cloud switch
  $('.switch').on('click', function(e) {
    if (!(internetUp)) {
      $('#cloud-slider').prop('checked', false);
      return false;
    }

    var checked = $('#cloud-slider').prop('checked');
    if (checked) {
      $('#cloud-slider').prop('checked', false);
    } else {
      $('#cloud-slider').prop('checked', true);
    }
  });

  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "SETUP END"
  })

});

/**
 * scanListRefresh - Show the current list of discovered devices
 */
$.scanListRefresh = function() {
  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "scanListRefresh: " + scanDeviceList.map(i => JSON.stringify(i))
  })

  $('#robots-found').empty();
  //Loop through and populate row items
  $.each(scanDeviceList, function(i, item) {
    var name = (item.fancyName == null ? item.name : item.fancyName);
    var deviceImage = getDeviceImage(item.name);
    var btn = (connectedDeviceList.length < 3 ? connectButton : "");

    var el = $(
      "<div class=\"row robot-item\"><a href=\"#\"> " +
      "<div class=\"row robot-item\">" +
      "<div class=\"col-xs-2 img\"><img src=\"" + deviceImage + "\" alt=\"Bit\" /></div>" +
      "<div class=\"col-xs-8 name\">" + name + "</div>" +
      btn + "</a>");

    //the connect button click event
    el.find('a').click(function() {
      //if we already have 3 connections, do not add any more.
      if (connectedDeviceList.length >= 3) {
        sendMessageToBackend(msgTypes.CONSOLE_LOG, {
          consoleLog: "Ignoring click to connect. Max connected devices already reached. device count = " + connectedDeviceList.length
        })
        return;
      }
/*
      // Stop the scanning
      var stopScan = {
        'command': 'scan',
        'scanState': 'off',
      }
      sendMessageToBackend(msgTypes.COMMAND, stopScan)
      sendMessageToBackend(msgTypes.CONSOLE_LOG, {
        consoleLog: "Scan stopped"
      })
*/
      // Show the spinner of a device about to appear connected
      setConnectedDisplay("show");

      setConnectingState("Connecting");

      // Send the actual connect command
      var connect = {
        'command': 'connect',
        'address': item.address
      }

      sendMessageToBackend(msgTypes.CONSOLE_LOG, {
        consoleLog: "Connection address = " + connect.address
      })

      // There appeared to be a conflict between stopping the scan and connecting, so experimentation
      // revealed that a 10ms wait would space the commands out enough.
      // TODO: IS THIS NECESSARY?
//      setTimeout(function() {

        sendMessageToBackend(msgTypes.COMMAND, connect)

        //remove the connecting item from the scan list
/*        removeFromScanList(item.name);

        $.scanListRefresh();

        sendMessageToBackend(msgTypes.CONSOLE_LOG, {
          consoleLog: "removed item from scan list: " + item.name
        })*/

//      }, 10);

      //Connection in progress remove from displayed scan list
      el.remove();

      sendMessageToBackend(msgTypes.CONSOLE_LOG, {
        consoleLog: "Connect button click complete"
      })
    });

    $('#robots-found').append(el);

  });
};

/**
 * connectedDevListRefresh - Populate the list of connected devices
 */
$.connectedDevListRefresh = function() {
  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "connectedDevListRefresh"
  })

  var refreshTable = {};
  $.each(connectedDeviceList, function(i, item) {
    var name = (item.deviceFancyName == null ? item.deviceName : item.deviceFancyName);
    var deviceName = item.deviceName;
    var devLetter = item.devLetter;
    var deviceImage = getDeviceImage(deviceName);


    var el = $(
      "             <div class=\"row robot-item\">" +
      "               <div class=\"col-xs-2 img\">" + devLetter + " <img src=\"" + deviceImage + "\" alt=\"Hummingbird Bit\" /></div>" +
      "               <div class=\"col-xs-6 name\">" + name + "</div>" +
      "               <div class=\"col-xs-4 buttons\">" +

      //Battery for Hummingbits and Finches only
      "                 <div style=\"display:inline-block\">" +
      "                   <span style=\"display:inline-block\" class=\"button button-battery button-battery-" + devLetter + " fa-stack fa-2x\"><i class=\"fas /*fa-battery-full fa-battery-half*/ /*fa-battery-quarter*/ fa-stack-2x\"></i></span> " +

      // Calibration button
      "                   <a class=\"button\" href=\"#\" onclick=\"return launchCalibrate(\'" + devLetter + "\', \'" + deviceName + "\', \'" + item.hasV2 + "\');\"><span class=\"button-calibrate fa-stack fa-2x\">" +
      "                     <i class=\"fas fa-square fa-stack-2x\"></i>" +
      "                     <i class=\"fas fa-compass fa-stack-1x fa-inverse\"></i>" +
      "                   </span></a>" +
      "                  </div>" +

      //Disconnect Button
      "                 <a class=\"button\" href=\"#\"><span class=\"button-disconnect fa-stack fa-2x\">" +
      "                   <i class=\"fas fa-circle fa-stack-2x\"></i>" +
      "                   <i class=\"fas fa-minus fa-stack-1x fa-inverse\"></i>" +
      "                 </span></a>" +
      "               </div>" +
      "             </div>");

    //Add the battery icon, but only if we know the battery status
    let battery = el.find('.button-battery-' + devLetter + ' i')
    switch (item.batteryStatus) {
      case "green":
        battery.addClass("fa-battery-full");
        break;
      case "yellow":
        battery.addClass("fa-battery-half");
        break;
      case "red":
        battery.addClass("fa-battery-quarter");
      break
    }

    //Set up disconnect button
    el.find('.button-disconnect').click(function() {
      var data = {
        'command': 'disconnect',
        'address': item.deviceAddress
      }
      sendMessageToBackend(msgTypes.COMMAND, data)
    });

    // Hash device entry by its dev letter for sorting
    refreshTable[devLetter] = el;

  });

  //Sort the elements in the refresh table and add to connected robots table
  var keys = [];
  for (var key in refreshTable) {
    if (refreshTable.hasOwnProperty(key)) {
      keys.push(key);
    }
  }
  keys.sort();
  $('#robots-connected').empty();
  for (i in keys) {
    var key = keys[i];
    var devEntry = refreshTable[key];
    $('#robots-connected').append(devEntry);
  }

  //Only show the display if there are connected devices
  if (!(jQuery.isEmptyObject(connectedDeviceList))) {
    setConnectedDisplay("show");
    setConnectingState("Connected");
  } else {
    setConnectedDisplay("hide");
  }
};

/**
 * setConnectedDisplay - Show or hide the list of connected devices
 *
 * @param  {string} state "show" or "hide"
 */
function setConnectedDisplay(state) {
  if (state == "show") {
    $('#connected').css('display', 'block');
  } else if (state == "hide") {
    $('#connected').css('display', 'none');
  }
}

/**
 * setConnectingState - Set the header of the connected robot list. If a robot
 * is in the process of connecting, show the spinner. Otherwise, show
 * "Connected".
 *
 * @param  {string} state "Connected" or "Connecting"
 */
function setConnectingState(state) {
  if (state == "Connecting")
    //$('#connection-state').html("<i class=\"fas fa-sync-alt fa-spin\"></i>" + " " + translationTable["connected"]);  //Do not change "Connected" to "Connecting"
    $('#connection-state').html("<i class=\"fas fa-sync-alt fa-spin\"></i>");
  else if (state == "Connected")
    $('#connection-state').html(translationTable["connected"]);
}

/**
 * getDeviceImage - Get an image file name based on the type of robot (defined
 * by the first two letters of the robot advertised name).
 *
 * @param  {string} deviceName Advertised name beginning with two letter device type code.
 * @return {string}            Image file name
 */
function getDeviceImage(deviceName) {
  var deviceImage = "img-hummingbird-bit.svg" // default hummingbird image
  if (deviceName.startsWith("MB")) deviceImage = "img-bit.svg";
  if (deviceName.startsWith("FN")) deviceImage = "img-finch.svg";
  return deviceImage;
}

/**
 * removeFromScanList - Remove deviceName from the list of available devices.
 * Used when a connection is requested.
 *
 * @param  {string} deviceName Name of the device to remove
 */
/*function removeFromScanList(deviceName) {
  for (var j = scanDeviceList.length - 1; j >= 0; --j) {
    if (scanDeviceList[j].name == deviceName) {
      scanDeviceList.splice(j, 1);
    }
  }
}*/

/**
 * updateInternetStatus - Updates the internet indicator. Called on an interval,
 * starting when the document is ready.
 */
function updateInternetStatus() {
  if (navigator.onLine) {
    $('#indicator-wifi').addClass("indicator-on");
    //$('#cloud-slider').prop('checked', true);
    internetUp = true;
  } else {
    $('#indicator-wifi').removeClass("indicator-on");
    $('#cloud-slider').prop('checked', false);
    internetUp = false;
  }
}

/**
 * updateBleStatus - Updates the ble indicator. Called by a callback from the
 * backend.
 *
 * @param  {boolean} isOn true if ble is enabled.
 */
function updateBleStatus(isOn) {
  if (isOn) {
    $('#indicator-bluetooth').addClass("indicator-on");
    $('#indicators .fa-spin').css("display", "none");
  } else {
    $('#indicator-bluetooth').removeClass("indicator-on");
  }
}

/**
 * launchSnap - Send a message to the backend asking it to open snap, deciding
 * which project to start with and whether to open online or offline based on
 * the user's selection.
 */
function launchSnap() {
  let projectName = ""
  if (connectedDeviceList.length == 1) {
    if (connectedDeviceList[0].deviceName.startsWith("FN")) {
      projectName = "FinchSingleDeviceStarterProject";
    } else {
      projectName = "HummingbirdSingleDeviceStarterProject";
    }
  } else {
    if (allRobotsAreFinches()) {
      projectName = "FinchMultiDeviceStarterProject";
    } else if (noRobotsAreFinches()) {
      projectName = "HummingbirdMultiDeviceStarterProject";
    } else {
      projectName = "MixedMultiDeviceStarterProject";
    }
  }

  const shouldOpenOnline = $('#cloud-slider').prop('checked')

  sendMessageToBackend(msgTypes.COMMAND, {
    command: "openSnap",
    project: projectName,
    online: shouldOpenOnline,
    language: language
  })
}
function allRobotsAreFinches() {
  let onlyFinches = true;
  for (let i = 0; i < connectedDeviceList.length; i++) {
    if (!connectedDeviceList[i].deviceName.startsWith("FN")) {
      onlyFinches = false;
    }
  }
  return onlyFinches;
}
function noRobotsAreFinches() {
  let noFinches = true;
  for (let i = 0; i < connectedDeviceList.length; i++) {
    if (connectedDeviceList[i].deviceName.startsWith("FN")) {
      noFinches = false;
    }
  }
  return noFinches;
}
