var connectedDeviceList = [];
var scanDeviceList = [];
//var devLetterList = ['A', 'B', 'C'];
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
      "               </div>"+
      "             </div>";


//Row Selection Logic
$(document).ready(function() {

  sendMessageToBackend(msgTypes.DOCUMENT_STATUS, {
    documentStatus: "READY",
    language: navigator.language,
    languages: navigator.languages
  })
  console.log("DOCUMENT READY");
  setLanguage();
  updateInternetStatus();
  setInterval(updateInternetStatus, 2000)

  $.connectedDevListRefresh();

  // Scan button - "find robots"
  $('#find-button').on('click', function(e) {
    $('#robots-found').empty();
    console.log("find-button clicked");
    sendMessageToBackend(msgTypes.CONSOLE_LOG, {
      consoleLog: "find-button clicked"
    })
    setConnectingState("Connected");
    var newScanState = null;
    if ($('#find-button i').hasClass("fa-spin"))
      newScanState = 'off';
    else
      newScanState = 'on';
    console.log("Turning scan " + newScanState);
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

  $('#programming-buttons .launch-snap-btn').on('click', function(e) {
    launchSnap();
  });

  $('.switch').on('click', function(e) {
    console.log("Internet Up: " + internetUp);
    if (!(internetUp)) {
      $('#cloud-slider').prop('checked', false);
      return false;
    }

    console.log("Slider state: " + $('#cloud-slider').prop('checked'));

    var checked = $('#cloud-slider').prop('checked');
    if (checked) {
      $('#cloud-slider').prop('checked', false);
      console.log("Unchecking slider new state: " + $('#cloud-slider').prop('checked'));
    } else {
      $('#cloud-slider').prop('checked', true);
      console.log("Checking slider new state : " + $('#cloud-slider').prop('checked'));
    }
  });

  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "END"
  })
  //toggleConnected();
});

// scanListRefresh
// Populate the list of advertising devices
//
$.scanListRefresh = function() {
  console.log("scanListRefresh:");
  console.log(scanDeviceList);
  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "scanListRefresh: " + scanDeviceList
  })
  $('.connect').prop('disabled', true);
  $('#robots-found').empty();
  //Loop through and populate row items
  $.each(scanDeviceList, function(i, item) {
    var name = (item.fancyName == null ? item.name : item.fancyName);
    var deviceName = getDeviceName(item.name);
    var deviceImage = getDeviceImage(deviceName);

    console.log("Scan List Item:");
    console.log(item);

    var el = $(
      //"<div class=\"address\" style=\"display:none\">" + item.address + "</div>" +
      //"<div class=\"devLetter\" style=\"display:none\">" + devLetterList[0] + "</div>" +
      "<div class=\"row robot-item\"><a href=\"#\"> " +
      "<div class=\"row robot-item\">" +
      "<div class=\"col-xs-2 img\"><img src=\"" + deviceImage + "\" alt=\"Bit\" /></div>" +
      "<div class=\"col-xs-8 name\">" + name + "</div>" +
      connectButton + "</a>");

    //the connect button click event
    el.find('a').click(function() {
      // Stop the scanning
      var stopScan = {
        'command': 'scan',
        'scanState': 'off',
      }
      sendMessageToBackend(msgTypes.COMMAND, stopScan)
      sendMessageToBackend(msgTypes.CONSOLE_LOG, {
        consoleLog: "Scan stopped"
      })

      // Show the spinner of a device about to appear connected
      setConnectedDisplay("show");
      sendMessageToBackend(msgTypes.CONSOLE_LOG, {
        consoleLog: "Connected display set to show"
      })
      setConnectingState("Connecting");
      sendMessageToBackend(msgTypes.CONSOLE_LOG, {
        consoleLog: "Connecting state set to connecting"
      })

      // Send the actual connect command
      var connect = {
        'command': 'connect',
        'address': item.address
      }

      sendMessageToBackend(msgTypes.CONSOLE_LOG, {
        consoleLog: "Connection address = " + connect.address + "; devLetter = " + connect.devLetter
      })

      // There appeared to be a conflict between stopping the scan and connecting, so experimentation
      // revealed that a 10ms wait would space the commands out enough.
      // TODO: IS THIS NECESSARY?
      setTimeout(function() {

        sendMessageToBackend(msgTypes.COMMAND, connect)

        // Clear the scan list and remove the devLetter from subsequent use on the connect button click event
        //console.log("Removing from scan list on connect button click event: " + deviceName + "  " + name);
        removeFromScanList(item.name);
        sendMessageToBackend(msgTypes.CONSOLE_LOG, {
          consoleLog: "removed item from scan list: " + item.name
        })

        $.scanListRefresh();
        sendMessageToBackend(msgTypes.CONSOLE_LOG, {
          consoleLog: "done with send message timeout"
        })
      }, 10);

      //Connection in progress remove from scan list
      el.remove();
      // Put up modal to say connection in progress...
      $('#scanning').css({
        "display": "block"
      });
      //Just in case something goes wrong. Do not let the connection progress modal get stuck on
      connectTimer = setTimeout(function() {
        $('#scanning').css({
          "display": "none"
        });
      }, 3000);
      sendMessageToBackend(msgTypes.CONSOLE_LOG, {
        consoleLog: "Connect button click complete"
      })
    });

    $('#robots-found').append(el);

    if (connectedDeviceList.length < 3)
      $('.connect').prop('disabled', false);
    else
      $('.connect').prop('disabled', true);

  });
};

//
// connectedDevListRefresh
// Populate the list of connected devices
//
$.connectedDevListRefresh = function() {
  console.log("connectedDevListRefresh");
  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "connectedDevListRefresh"
  })

  var refreshTable = {};
  $.each(connectedDeviceList, function(i, item) {
    var name = (item.deviceFancyName == null ? item.deviceName : item.deviceFancyName);
    var deviceName = getDeviceName(item.deviceName);
    var devLetter = item.devLetter;
    var deviceImage = getDeviceImage(deviceName);
    var devDisplay = getDeviceDisplay(deviceName);

    var el = $(
      //"             <div class=\"address\" style=\"display:none\">" + item.deviceAddress + "</div>" +
      //"             <div class=\"devLetter\" style=\"display:none\">" + devLetter + "</div>" +
      "             <div class=\"row robot-item\">" +
      "               <div class=\"col-xs-2 img\">" + devLetter + " <img src=\"" + deviceImage + "\" alt=\"Hummingbird Bit\" /></div>" +
      "               <div class=\"col-xs-6 name\">" + name + "</div>" +
      "               <div class=\"col-xs-4 buttons\">" +

      //Battery for Hummingbits and Finches only
      "                 <div style=\"display:inline-block\">" +
      "                   <span " + devDisplay + " class=\"button button-battery button-battery-" + devLetter + " fa-stack fa-2x\"><i class=\"fas /*fa-battery-full fa-battery-half*/ /*fa-battery-quarter*/ fa-stack-2x\"></i></span> " +

      // Calibration button
      "                   <a class=\"button\" href=\"#\" onclick=\"return launchCalibrate(\'" + devLetter + "\', \'" + deviceName + "\');\"><span class=\"button-calibrate fa-stack fa-2x\">" +
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

    el.find('.button-disconnect').click(function() {
      var data = {
        'command': 'disconnect',
        'devLetter': item.devLetter,
        'address': item.deviceAddress
      }
      sendMessageToBackend(msgTypes.COMMAND, data)

    });

    // Hash device entry by its dev letter for sorting
    refreshTable[devLetter] = el;

  });

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

  if (!(jQuery.isEmptyObject(connectedDeviceList))) {
    setConnectedDisplay("show");
    setConnectingState("Connected");
  } else {
    setConnectedDisplay("hide");
  }
};

function setConnectedDisplay(state) {
  if (state == "show") {
    $('#connected').css('display', 'block');
    //setConnectingState("Connecting");
    $('body').css('backgroundColor', '#881199'); // redundant, doesn't change?
  } else if (state == "hide") {
    $('#connected').css('display', 'none');
    $('body').css('backgroundColor', '#881199'); // redundant, doesn't change?
  }
}

function setConnectingState(state) {
  if (state == "Connecting")
    //$('#connection-state').html("<i class=\"fas fa-sync-alt fa-spin\"></i>" + " " + translationTable["connected"]);  //Do not change "Connected" to "Connecting"
    $('#connection-state').html("<i class=\"fas fa-sync-alt fa-spin\"></i>");
  else if (state == "Connected")
    $('#connection-state').html(translationTable["connected"]);
}

function getDeviceName(devInstance) {
  var str = devInstance.substring(0, 2);
  var devName = null;
  switch (str) {
    case ("HB"):
    case ("BB"):
      devName = "Hummingbird";
      break;
    case ("MB"):
      devName = "micro:bit";
      break;
    default:
      devName = devInstance;
      break;
  }
  return devName;
}

function getDeviceImage(deviceName) {
  var deviceImage = "img-hummingbird-bit.svg" // default hummingbird image
  if (deviceName.startsWith("MB")) deviceImage = "img-bit.svg";
  if (deviceName.startsWith("FN")) deviceImage = "img-finch.svg";
  return deviceImage;
}

function getDeviceDisplay(deviceName) {
  var deviceDisplay = "style=\"display:inline-block\"";
  if (deviceName == "micro:bit")
    deviceDisplay = "style=\"display:none\"";
  return deviceDisplay;
}

function removeFromScanList(deviceName) {
  // Remove connected device from scan list
  for (var j = scanDeviceList.length - 1; j >= 0; --j) {
    if (scanDeviceList[j].name == deviceName) {
      console.log("Removing " + scanDeviceList[j].name + " from scan list");
      scanDeviceList.splice(j, 1);
    }
  }
}

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
  /*sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "Updated internet status"
  })*/
}

function updateBleStatus(isOn) {
  if (isOn) {
    $('#indicator-bluetooth').addClass("indicator-on");
    $('#indicators .fa-spin').css("display", "none");
  } else {
    $('#indicator-bluetooth').removeClass("indicator-on");
  }
}

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
    if (connectedDeviceList[i].deviceName.startsWith("FN")) {
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
