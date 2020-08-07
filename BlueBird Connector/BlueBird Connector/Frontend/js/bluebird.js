      var hostname = window.location.hostname;
      console.log("hostname = " + hostname);
      var host = hostname + ':30061';
      var csDataURL = 'ws://' + host + '/control/';
      var cs = null;
      var dataURL = 'ws://' + host + '/scratch/';
      var ws = null;
      var connectTimer;


      var listLength = 0;
      var selected = false;
      var connectedDevSelected = false;
      var scanDeviceList = [];
      var connectedDeviceList = {};
      var serviceTable = {};  // service table to attribute handle keyed by connection

      var hbList = [1,2,3];
      var mbList = [1,2,3];
      var CSList = [1,2,3];

      var devLetterList = ['A', 'B', 'C'];

      //Hummingbird specific service UUIDs and characteristics
      var HB_WRITE_SVC_UUID  = "6e4002b5a3f393e0a9e5e24dcca9e";
      var HB_NOTIFY_SVC_UUID = "6e4003b5a3f393e0a9e5e24dcca9e";
      var HB_NOTIFY_CTL_CHAR = 0x2902;

      var loading = true;

      var calibrationDevLetter = null;  // Only one device can be calibrating at a time
      var usingSerial = false;
      var usingBLE = false;
      var usingNativeMacOS = false;
//      var lastBLEstateOff = false;
      //If we just lost communication or never had communication, we will need
      // to start a video, but if communication was already off, no need to do
      // anything.
      var lastCommunicationStateOff = false;

      //HTML code to string conversion tool:  http://pojo.sodhanalibrary.com/string.html
      var connectButton =
            "              <div class=\"col-xs-2 buttons\">"+
            "                 <a class=\"button\" href=\"#\"><span class=\"button-connect fa-stack fa-2x\">"+
            "                   <i class=\"fas fa-circle fa-stack-2x\"></i>"+
            "                   <i class=\"fas fa-plus fa-stack-1x fa-inverse\"></i>"+
            "                 </span></a>"+
            "               </div>"+
            "             </div>";

      var addressTable = {};

      var internetUp = false;
      var translationTable = {};


      // Socket receive data handler
      var csOnmessage = function (evt) {
            //console.log("Control SOcket Received message from driver");
            var isSerialDevice = false;
            //console.log (evt.data);
            var msg = JSON.parse(evt.data);
            if (msg.hasOwnProperty("type")) {
              switch (msg.type) {
                  case ("active") :
                    console.log("!!!!!!!!!!!!!!!Device List Length: " + msg.deviceList.length);
                    scanDeviceList = [];
                    for (var i=0; i < msg.deviceList.length; i++) {
                      scanDeviceList[i] = msg.deviceList[i]
                      console.log(msg.deviceList[i]);
                    }
                    scanDeviceList.sort(function(a, b) {
                      //return (a.address > b.address) - (a.address < b.address);
                      return (a.rssi < b.rssi) - (a.rssi > b.rssi);
                    });
                    console.log("!!!!!!!!!!!!!!!!scanDeviceList");
                    console.log(scanDeviceList);
                    //if (!selected)
                      $.scanListRefresh(); // Initialize List on every list update message
                  break;
                  case ("status") :
                      //console.log(scanDeviceList);
                      if (msg.scanning) {
                        if (!($('#find-button i').hasClass('fa-spin'))){
                          $('#find-button i').addClass('fa-spin');
                          $('#findBtnText').text(" "+translationTable["finding_robots"]);
                        }
                      }
                      else {
                        if ($('#find-button i').hasClass('fa-spin')) {
                          $('#find-button i').removeClass('fa-spin');
                          $('#findBtnText').text(" "+translationTable["find_robots"]);
                        }
                      }

                      //console.log(msg);
                      $.updateDongleStatus(msg);
                      $.updateInternetStatus(msg);
                      $.updateBatteryStatus(msg);

                  break;
                  case ("foundSerialDevice") :
                        //closeBluetooth();
                        closeModal();
                        setConnectedDisplay("show");
                        setConnectingState("Connecting");
                        $('#finder').css("display", "none");
                        $('#indicators .fa-spin').css("display", "none");
                        $('.button-disconnect').css("display", "none");
                        usingSerial = true;
                  break;
                  case ("deviceInfo") :
                  /*
                     console.log(msg);
                    if (msg.connected) {
                      if (!(msg.deviceConnection in connectedDeviceList)){
                        connectedDeviceList[msg.deviceConnection] = msg; //Add device object to list
                      }
                    }
                    else {
                      if (msg.deviceConnection in connectedDeviceList)
                        delete connectedDeviceList[msg.deviceConnection]; //disconnection event delete
                    }
                    $.connectedDevListRefresh();*/
                  break;

                  // This is the connection event. The updated connected device list is returned.
                  case ("connectionTable") :
                      console.log("connectionTable");
                      console.log(scanDeviceList);
                      console.log(msg);
                      connectedDeviceList = {};
                      for (i in msg.connectedDeviceTable){
                        console.log("connected device:");
                        console.log(msg.connectedDeviceTable[i]);
                        connectedDeviceList[msg.connectedDeviceTable[i].deviceConnection] = msg.connectedDeviceTable[i];
                        // THere's only going to be one serial device
                        if (msg.connectedDeviceTable[i].deviceAddress == "Serial Device")
                          isSerialDevice = true;
                      }

                      if (isSerialDevice){
                        console.log("Serial device found");
                        $.connectedDevListRefresh();
                        setConnectedDisplay("show");
                        setConnectingState("Connected");
                        $('#start-programming').css("display", "block");
                      }
                      else {
                        // Process BLE connection(s) here
                        console.log("Updated connectedDeviceList: Updating Device Lists...");
                        console.log(connectedDeviceList);

                        devLetterList = ['A', 'B', 'C'];
                        for (i in connectedDeviceList){
                          console.log(connectedDeviceList[i]);
                          console.log("Device Name: " + connectedDeviceList[i].deviceName + " Device Num: " + connectedDeviceList[i].devNum );
                          var devName = getDeviceName(connectedDeviceList[i].deviceName);

                          // Remove connected device from scan list
                          removeFromScanList(connectedDeviceList[i].deviceName);

                          hideUsedDevNum(devName, connectedDeviceList[i].devLetter);
                        }

                        $.scanListRefresh();

                        if (loading) {
                              $.connectedDevListRefresh();
                              loading = false;
                        }
                      }
                      console.log("connectedDeviceList:");
                      console.log(connectedDeviceList);

                  break;
                  case ("driverConnectionStateTable") :
                      console.log("driverConnectionStateTable");
                      console.log(msg);
                      serviceTable = {};
                      for (var i in msg.table) {
                        var conn = i;
                        console.log("Service Table For Connection " + conn);
                        console.log(msg.table[conn].connectionTable[conn].primaryServiceTable);
                        serviceTable[conn] = msg.table[conn].connectionTable[conn].primaryServiceTable;
                      }
                      console.log("Event: " + msg.event);
                      if (msg.event == "newConnection") {  // Enable notifications on new connection event
                          //dataStream("on", msg.connection, serviceTable[msg.connection]);
                          $.connectedDevListRefresh();
                          //clearTimeout(connectTimer);

                      }
                      if (msg.event == "disconnection") {  // Enable notifications on new connection event
                          $('#scanning').css ({"display" : "none"}); // failed connection immediately after scanning. Remove
                          if (!connectedDevSelected)
                            $.connectedDevListRefresh();
                      }

                      if (msg.event == "newSerialConnection") {  // Enable notifications on new connection event
                        console.log("newSerialConnection:");
                        setConnectedDisplay("show");
                        setConnectingState("Connected");
                        $('#start-programming').css("display", "block");
                      }


                      //Show or hide Connected devices based on table
                      if (jQuery.isEmptyObject(msg.table))
                        setConnectedDisplay("hide");
                      else
                        setConnectedDisplay("show");
                  break;

                  case ("connectionObj") :
                      console.log("connectionObj");
                      console.log(msg);
                  break;
                  case ("calibrationStatus") :
                      console.log("calibrationStatus");
                      var ha = $('#calibrate-modal .animation').height();
                      var hi = $('#calibrate-modal .animation i').height();
                      $('#calibrate-modal .animation i').css('marginTop', ((ha-hi)/2)+'px');
                      if (msg.status == "success") {
                        $('#calibrate-modal .status').addClass('status-success');
                        //setTimeout(function() {$('#calibrate-modal').css ({"display" : "none"});}, 3000);
                        setTimeout(function() { closeCalibrationModal(); }, 3000);
                      }
                      if (msg.status == "fail") {
                        //var video = document.getElementById("compassVid");
                        //video.pause();
                        $('#calibrate-modal .status').addClass('status-fail');
                      }
                      // Let user close modal in case of failure
                      //setTimeout(function() {$('#calibrate-modal').css ({"display" : "none"});}, 3000);
                  break;

                  case ("DAPLinkUpgradeRequired") :
                    closeModal();
                    launchDAPLinkUpgradeVideo();
                  break;
                  case ("microbitFound") :
                    setConnectedDisplay("show");
                    setConnectingState("Connecting");
                    $('#start-programming').css("display", "none");
                  break;
                  case ("translationTable") :
                      console.log("translationTable");
                      console.log(msg);
                      translateStrings(msg.translationTable, msg.language);
                  break;

                  case ("closeModal") :
                    closeModal();
                    setConnectedDisplay("show");
                    setConnectingState("Connecting");
                    $('#start-programming').css("display", "block");
                    $('#finder').css("display", "none");
                    $('#indicators .fa-spin').css("display", "none");
                    $('.button-disconnect').css("display", "none");
                  break;


              }// end switch
            } else console.log (evt.data);
      }

      /* first time connecton */
      if ((cs === null) || (!(cs.readyState == 1))) {
        console.log("control socket connecting to server");
        cs = new WebSocket(csDataURL);
        cs.onmessage = csOnmessage;
        //cs.onopen = csOnopen;
        console.log(cs);
      }
      else { console.log ("Connect: control socket already connected");}

      if ((ws === null) || (!(ws.readyState == 1))) {
        console.log("binary socket connecting to server");
        ws = new WebSocket(dataURL);
        ws.binaryType = 'arraybuffer';  // designates binary connection
        console.log(ws);
      }
      else { console.log ("Connect: binary socket already connected");}





          //
          // Disconnect a connected device.
          // The selected row highlighted is the device to disconnect
          //
            $('.disconnect').on('click', function(e){
                //$('.connect').prop('disabled', true);
                var connection = $("#connectedDevTable tr.selected td:last").html();
                //var devNum = $("#connectedDevTable tr.selected td:nth-child(3)").html();
                var devName = $("#connectedDevTable tr.selected td:nth-child(3)").html();
                console.log("Connection  = " + connection + " devName = " + devName);;
                connectedDevSelected = false;
                $.connectedDevListRefresh();
                //$('.startscan').prop('disabled', false);
                //$('.stopscan').prop('disabled', true);
                var data = {
                    'command' : 'disconnect',
                    'connection' : connection
                  }
                  cs.send(JSON.stringify(data));

                  $('.disconnect').prop('disabled', true);
                  $('.connectListRefresh').prop('disabled', true);
                  restoreUsedDevNum(devName);
            });

            $('.connectListRefresh').on('click', function(e){
                connectedDevSelected = false;
                $(this).prop('disabled', true);
                $('.disconnect').prop('disabled', true);
                $.connectedDevListRefresh();
             });

            //Launch snap cloud site in OS default browser
            $('#snapCloud').on('click', function(e){
                cs.send("startCloudSnap");
             });

            //Launch snap local site in OS default browser
            $('#snapLocal').on('click', function(e){
                cs.send("startLocalSnap");
             });
          //
          // scanListRefresh
          // Populate the list of advertising devices
          //
          $.scanListRefresh = function() {
              console.log("scanListRefresh:");
              console.log(scanDeviceList);
              $('.connect').prop('disabled', true);
              $('#robots-found').empty();
              //Loop through and populate row items
              $.each(scanDeviceList, function(i, item) {
                  var name = (item.fancyName == null ? item.name : item.fancyName);
                  addressTable[name] = item.address;
                  var deviceName = getDeviceName(item.name);
                  var deviceImage = getDeviceImage(deviceName);

                  console.log("Scan List Item:");
                  console.log(item);

                  var el = $(
                    "<div class=\"address\" style=\"display:none\">" + item.address + "</div>" +
                    "<div class=\"devLetter\" style=\"display:none\">" + devLetterList[0] + "</div>" +
                    "<div class=\"row robot-item\"><a href=\"#\"> " +
                    "<div class=\"row robot-item\">" +
                    "<div class=\"col-xs-2 img\"><img src=\""+ deviceImage + "\" alt=\"Bit\" /></div>" +
                    "<div class=\"col-xs-8 name\">" + name + "</div>" +
                    connectButton + "</a>" );

                    //the connect button click event

                    // Stop the scanning
                    el.find('a').click(function() {
                       var stopData = {
                       'command' : 'scan',
                       'scanState' : 'off',
                       'devNum': 1   //dummy
                       }
                       cs.send(JSON.stringify(stopData));

                    // Show the spinner of a device about to appear connected
                    setConnectedDisplay ("show");
                    setConnectingState("Connecting");

                   // Send the actual connect command
                   var data = {
                   'command' : 'connect',
                   'address' : item.address,
                   'devLetter': devLetterList[0]
                   }
                   console.log("Connection address = " + data.address);
                   console.log("devLetter = " + data.devLetter);

                   // There appeared to be a conflict between stopping the scan and connecting, so experimentation
                   // revealed that a 10ms wait would space the commands out enough.
                   setTimeout (function() {
                       cs.send(JSON.stringify(data));

                       // Clear the scan list and remove the devLetter from subsequent use on the connect button click event
                       console.log("Removing from scan list on connect button click event: " + deviceName + "  " + name);
                       removeFromScanList(item.name);
                       hideUsedDevNum(deviceName, devLetterList[0]);
                       $.scanListRefresh();
                   }, 10);

                    //Connection in progress remove from scan list
                    el.remove();
                    // Put up modal to say connection in progress...
                    $('#scanning').css ({"display" : "block"});
                    //Just in case something goes wrong. Do not let the connection progress modal get stuck on
                    connectTimer = setTimeout(function() {$('#scanning').css ({"display" : "none"});},3000);
                  });

                  $('#robots-found').append(el);
                //console.log($tr.wrap('<p>').html());

                if (devLetterList.length > 0)
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
              var refreshTable = {};
              $.each(connectedDeviceList, function(i, item) {
                  var name = (item.deviceFancyName == null ? item.deviceName : item.deviceFancyName);
                  var deviceName = getDeviceName(item.deviceName);
                  var devLetter = connectedDeviceList[item.deviceConnection].devLetter;
                  hideUsedDevNum(deviceName, devLetter);
                  var deviceImage = getDeviceImage(deviceName);
                  var devDisplay = getDeviceDisplay(deviceName);

                  var el =     $(
                      "             <div class=\"address\" style=\"display:none\">" + item.deviceAddress + "</div>" +
                      "             <div class=\"devLetter\" style=\"display:none\">" + devLetter + "</div>" +
                      "             <div class=\"row robot-item\">"+
                      "               <div class=\"col-xs-2 img\">" + devLetter +  " <img src=\"" + deviceImage +"\" alt=\"Hummingbird Bit\" /></div>"+
                      "               <div class=\"col-xs-6 name\">" + name + "</div>"+
                      "               <div class=\"col-xs-4 buttons\">"+

                                        //Battery for Hummingbits and Finches only
                      "                 <div style=\"display:inline-block\">" +
                      "                   <span " + devDisplay + " class=\"button button-battery button-battery-" + devLetter + " fa-stack fa-2x\"><i class=\"fas /*fa-battery-full fa-battery-half*/ /*fa-battery-quarter*/ fa-stack-2x\"></i></span> "+

                                          // Calibration button
                      "                   <a class=\"button\" href=\"#\" onclick=\"return launchCalibrate(\'" + devLetter + "\', \'" + deviceName + "\');\"><span class=\"button-calibrate fa-stack fa-2x\">"+
                      "                     <i class=\"fas fa-square fa-stack-2x\"></i>"+
                      "                     <i class=\"fas fa-compass fa-stack-1x fa-inverse\"></i>"+
                      "                   </span></a>"+
                      "                  </div>" +

                                        //Disconnect Button
                      "                 <a class=\"button\" href=\"#\"><span class=\"button-disconnect fa-stack fa-2x\">"+
                      "                   <i class=\"fas fa-circle fa-stack-2x\"></i>"+
                      "                   <i class=\"fas fa-minus fa-stack-1x fa-inverse\"></i>"+
                      "                 </span></a>"+
                      "               </div>"+
                      "             </div>");

                    el.find('.button-disconnect').click(function() {
                      var data = {
                          'command' : 'disconnect',
                          'connection' : item.deviceConnection,
                          'address' : item.deviceAddress
                        }
                      cs.send(JSON.stringify(data));

                      console.log("Disconnect Data");
                      console.log(data);

                      //Disconnection in progress remove from  list
                      el.remove();
                      restoreUsedDevLetter(devLetter);
                      /*
                      var el = $('<tr><td>' + name + '</td><td style=\"display:none\">' + item.deviceAddress + '</td><td >Device ' + devLetter + ' (' + deviceName + ')</td><td style=\"display:none\">'+ item.deviceConnection + '</td></tr>')
                      .click(function(){
                         $(this).addClass('selected').siblings().removeClass('selected');
                         var value=$(this).find('td:first').html();
                         connectedDevSelected = true;
                         console.log(value);
                         $('.disconnect').prop('disabled', false);
                         $('.connectListRefresh').prop('disabled', false);
                      });   */

                      //$('#connectedDevTable').append(el);


                      //console.log($tr.wrap('<p>').html());
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
            }
            else
              setConnectedDisplay("hide");
          };

        //
        // updateDongleStatus
        // Indicate BLED112 dongle status i.e. present and working or not
        // THis function has been extedned to give Serial and Native MacOS status as well.
        //
        $.updateDongleStatus = function(deviceStatus) {
            //console.log("updateDongleStatus: ");
            //console.log(deviceStatus);
            // update global vars
            usingSerial = deviceStatus.usingSerial;
            usingBLE = deviceStatus.dongleConnected;
            usingNativeMacOS = deviceStatus.usingNativeMacOS;
            const nativeMacOSBluetoothOn = usingNativeMacOS && deviceStatus.nativeMacOSBluetoothOn;


            if ((usingBLE) || (usingSerial) || (nativeMacOSBluetoothOn)) {
                //closeBluetooth();

                $('#indicators .fa-spin').css("display", "none");
                if (lastCommunicationStateOff) {
                  lastCommunicationStateOff = false;
                  closeModal();
                  //$('#robots-found').css("display", "block");
                }
            }

            if (usingBLE || (nativeMacOSBluetoothOn)) {
                  $('#indicator-bluetooth').addClass("indicator-on");
            } else {
                  $('#indicator-bluetooth').removeClass("indicator-on");
            }

            if (usingSerial) {
                  $('#finder').css("display", "none");
                  //$('#indicators .fa-spin').css("display", "none");
                  $('.button-disconnect').css("display", "none");
            } else {
                  $('#finder').css("display", "block");
                  $('.button-disconnect').css("display", "inline-block");
            }

            //If we have macos native ble available, but it is not turned on,
            // start the video if this is new information.
            if (usingNativeMacOS && !nativeMacOSBluetoothOn && !lastCommunicationStateOff) {// Do not call  repeatedly because it will restart the video over and over every second
                    lastCommunicationStateOff = true;
                    scanDeviceList = [];
                    $('#robots-found').empty();
                    //$('#robots-found').css("display", "none");
                    $.scanListRefresh();
                    // Keep button from going into scanning state
                    if ($('#find-button i').hasClass('fa-spin')) {
                        $('#find-button i').removeClass('fa-spin');
                        $('#findBtnText').text(" "+translationTable["find_robots"]);
                    }

                    closeModal();
                    launchNativeMacOSBLEvideo();
            }

            //No connection at all. Play dongle/serial video. (but only start it once)
            if  (!usingNativeMacOS && !usingSerial && !usingBLE && !lastCommunicationStateOff) {
                lastCommunicationStateOff = true;
                closeModal();
                launchBluetooth();
            }
        }

        $.updateInternetStatus = function(deviceStatus) {
            //BLED112 Connnected?
            //console.log("updateInternetStatus");
            //console.log(deviceStatus);
            if (deviceStatus.internetUp) {
              $('#indicator-wifi').addClass("indicator-on");
              //$('#cloud-slider').prop('checked', true);
              internetUp = true;
            }
            else {
              $('#indicator-wifi').removeClass("indicator-on");
              $('#cloud-slider').prop('checked', false);
              internetUp = false;
            }
          }

        $.updateBatteryStatus = function(deviceStatus) {
            //BLED112 Connnected?
            //console.log("updateBatteryStatus");
            //console.log(deviceStatus);
            if (deviceStatus.battLevelTable === null)
              return;
            for (i in connectedDeviceList){
              var devName = getDeviceName(connectedDeviceList[i].deviceName);
              if (devName == "Hummingbird" || devName.startsWith("FN")) {
                var devLetter = connectedDeviceList[i].devLetter;
                var battLevel = deviceStatus.battLevelTable[devLetter];
                //console.log ("Battery level for Hummingbird " + devLetter + ": " + battLevel);

                var battSelector = '.button-battery-' + devLetter + ' i';
                $(battSelector).removeClass("fa-battery-full");
                $(battSelector).removeClass("fa-battery-half");
                $(battSelector).removeClass("fa-battery-quarter");
                switch (battLevel) {
                  case "high":
                    $(battSelector).addClass("fa-battery-full");
                  break;
                  case "medium":
                    $(battSelector).addClass("fa-battery-half");
                  break;
                  case "low":
                    $(battSelector).addClass("fa-battery-quarter");
                  break;
                  default:  //Default to grey -  This has no effect when page is first loaded ??
                    //$(battSelector).addClass("fa-battery-full");
                    //$(battSelector).css("color", "#CACACA");
                }
              }
            }
          }

          var dongleConnect = function () {
                  console.log("connect Dongle");
                  cs.send("dongleConnect");
          }

          var dongleDisconnect = function () {
                  console.log("disconnect Dongle");
                  cs.send("dongleDisconnect");
          }

          var getDeviceName = function (devInstance) {
              var str = devInstance.substring(0,2);
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


            var removeFromScanList = function(deviceName) {

                // Remove connected device from scan list
                for (var j = scanDeviceList.length - 1; j >= 0; --j) {
                    if (scanDeviceList[j].name == deviceName) {
                        console.log("Removing " + scanDeviceList[j].name + " from scan list");
                        scanDeviceList.splice(j,1);
                    }
                }
            }



          var hideUsedDevNum = function (deviceName, devLetter) {
            console.log("hideUsedDevNum");

            var list = devLetterList;
            var i = list.indexOf(devLetter);
            if (i > -1)
              list.splice(i, 1);
            console.log(list);

            // Update the device list of the given deviceName
            var newOptions =  populateSelectList(deviceName);
            console.log (newOptions);
            console.log($('select.'+deviceName));
            $('select.'+deviceName).empty();
            $('select.'+deviceName).append(newOptions);

          }


          var hideUsedDevLetter = function (deviceName, devLetter) {
            console.log("hideUsedDevLetter");

            var list = devLetterList;
            var i = list.indexOf(devLetter);
            if (i > -1)
              list.splice(i, 1);
            console.log(list);

            // Update the device list of the given deviceName
            var newOptions =  populateSelectList(deviceName);
            console.log (newOptions);
            console.log($('select.'+deviceName));
            $('select.'+deviceName).empty();
            $('select.'+deviceName).append(newOptions);

          }



          var restoreUsedDevLetter = function (devLetter) {
            var list = devLetterList;
            var i = list.indexOf(devLetter);

            if (i == -1)
              list.push(parseInt(devLetter));
            list.sort();
            console.log(list);
            }

          var populateSelectList = function(deviceName) {
            var optionList = "";
            var list = devLetterList;

            if (!(list == null)) {
              //for (var i=0; i < list.length; i++)
                //optionList +='<option value=\"' + list[i].toString() + '\">' + list[i].toString() + '</option>';
              if (list.length > 0) {
                optionList +='<option value=\"' + list[0].toString() + '\">' + list[0].toString() + '</option>';
                 $('.connect').prop('disabled', false);
               }
              else {
                optionList +='<option value=\"' + ' ' + '\">' + ' ' + '</option>';
                 $('.connect').prop('disabled', true);
              }
              console.log(optionList);
              return optionList;
            } else return null;
          }

          function setConnectedDisplay (state) {
            if (state == "show") {
              $('#connected').css('display', 'block');
              //setConnectingState("Connecting");
              $('body').css('backgroundColor', '#881199');  // redundant, doesn't change?
            } else if (state == "hide") {
              $('#connected').css('display', 'none');
              $('body').css('backgroundColor', '#881199');   // redundant, doesn't change?
            }
          }

          function setConnectingState (state) {
            if (state == "Connecting")
              //$('#connection-state').html("<i class=\"fas fa-sync-alt fa-spin\"></i>" + " " + translationTable["connected"]);  //Do not change "Connected" to "Connecting"
              $('#connection-state').html("<i class=\"fas fa-sync-alt fa-spin\"></i>");
            else if (state == "Connected")
              $('#connection-state').html(translationTable["connected"]);
          }

          function launchSnap () {
            console.log("Background color: " + $('.slider').css('background-color'))
            if ($('#cloud-slider').prop('checked')) {
               cs.send("startCloudSnap");
             }
            else
                cs.send("startLocalSnap");
          }

          //-------------------------------------------------------
          //  Enable device notifications with this set of functions
          //-------------------------------------------------------
          function concatArrays(a, b) { // a, b TypedArray of same type
            //console.log("concatArrays");
              var c = new (a.constructor)(a.length + b.length);
              c.set(a, 0);
              c.set(b, a.length);
              return c;
          }

          var writeBytesUUIDHandle = function (connection, attHandle, bytes) {
              console.log("writeBytesUUIDHandle:  Connection: " + connection + "  Atthandle: " + attHandle);
              if (!(connection == null)) {
                var header = new Uint8Array(3);
                header[0] = 0x13;      // Command type -write handle
                header[1] = connection & 0xFF;
                header[2] = attHandle;
                var data = concatArrays(header,bytes);
                ws.send(data);
              } else console.log("ERROR: Null connection number. Data not sent");
          }

          var writeBytesUUIDHandleSync = function (connection, attHandle, bytes) {
              console.log("writeBytesUUIDHandleSync:  Connection: " + connection + "  Atthandle: " + attHandle);
              if (!(connection == null)) {
                var header = new Uint8Array(3);
                header[0] = 0x14;      // Command type -write handle
                header[1] = connection & 0xFF;
                header[2] = attHandle;
                var data = concatArrays(header,bytes);
                ws.send(data);
              } else console.log("ERROR: Null connection number. Data not sent");
          }

          // Not used anymore
          dataStream = function(state, connection, serviceTable) {
            console.log("dataStream: connection = " + connection);
            setTimeout(
              function()
              {

              var payload = new Uint8Array(2);
              if (state == 'on')
                payload[0] = 0x01;
              else
                payload[0] = 0x00;
              payload[1] = 0x00;
              // Write 0x00 or 0x01 to client characteristic at handle 12
                //var table = serviceTable[HB_NOTIFY_SVC_UUID];
                //console.log ("table: ");
                //console.log(table);
                //writeBytesUUIDHandleSync(connection, table[0x2902], payload);
                //Disabled writes, however, need the timing to refresh the dev list and clear connecting timer below. TODO: move these somewhere else.
                $.connectedDevListRefresh();

              // Enable broadcast of Sensor values: 0x6267
              setTimeout(
                function()
                {
                  var payload = new Uint8Array(2);
                  payload[0] = 0x62;
                  payload[1] = 0x67;
                  //writeBytesUUIDHandleSync(connection, serviceTable[HB_WRITE_SVC_UUID][0], payload);
                  //if (!connectedDevSelected)

                  clearTimeout(connectTimer);
                  $('#scanning').css ({"display" : "none"});
                },1000);
            }, 1500);

          }

          getDeviceImage = function (deviceName) {
            var deviceImage = "img/img-hummingbird-bit.svg" // default hummingbird image
            if (deviceName == "micro:bit") deviceImage = "img/img-bit.svg";
            if (deviceName.startsWith("FN")) deviceImage = "img/img-finch.svg";
            return deviceImage;
          }

          getDeviceDisplay = function (deviceName) {
            var deviceDisplay = "style=\"display:inline-block\"";
            if (deviceName == "micro:bit")
              deviceDisplay = "style=\"display:none\"";
            return deviceDisplay;
          }

          getDeviceVideo = function (deviceName) {
            var deviceImage = "HummBit Figure 8_2.mp4" // default hummingbird video
            if (deviceName == "micro:bit")
              deviceImage = "MicroBit Figure 8_2.mp4";
            if (deviceName.startsWith("FN"))
              deviceImage = "Finch_Calibration.mp4";
            return deviceImage;
          }


          setCalibrationDevLetter = function (devLetter) {
            calibrationDevLetter = devLetter;
          }

          getCalibrationDevLetter = function () {
            return calibrationDevLetter;
          }
          usingSerialDevice = function () {
            return usingSerial;
          }

          usingBLEDDevice = function () {
            return usingBLE;
          }

          translateStrings = function (table, language) {
            translationTable = table;
            // Set up defaults
            $('#findBtnText').text(" "+translationTable["finding_robots"]);
            $('#connection-state').html(translationTable["connected"]);
            $('#start_programming').html(translationTable["start_programming"]);
            $('#Connection_Failure').html(" "+translationTable["Connection_Failure"]+" ");
            $('#CompassCalibrate').html(" "+translationTable["CompassCalibrate"]);
            $('#Update_firmware').html(translationTable["Update_firmware"]);

            if (language == "ar") {
              $('#findBtnText').css("font-family", "Arial");
              $('#connection-state').css("font-family", "Arial");
              $('#start_programming').css("font-family", "Arial");
              $('#Connection_Failure').css("font-family", "Arial");
              $('#CompassCalibrate').css("font-family", "Arial");
              $('#Update_firmware').css("font-family", "Arial");
            }
          }




         //-------------------------------------------------------
         // Dustbin

          //Not needed
          var selectRow = function(){
             $(this).addClass('selected').siblings().removeClass('selected');
             var value=$(this).find('td:first').html();
             console.log(value);
          };

          // No longer needed
          var restoreUsedDevNum = function (deviceName) {
            console.log("restoreUsedDevNum");
            console.log("deviceName = " + deviceName);
            var list = devLetterList;
            var className;
            var devNum = deviceName.charAt(deviceName.length - 1);
            var i = list.indexOf(devNum);

            if (i == -1)
              list.push(parseInt(devNum));
            list.sort();
            console.log(list);

            // Update the device list of the given deviceName
            var newOptions =  populateSelectList(className);
            console.log (newOptions);
            console.log($('select.'+className));
            $('select.'+className).empty();
            $('select.'+className).append(newOptions);
          }


          /* Close calibration modal */
          function closeCalibrationModal() {
              console.log("closeCalibrationModal");
              removeVideos();

              var devLetter = null;
              if (usingSerialDevice())
                  devLetter =  'A'  // Serial connection is always devLetter = A.
                  else if (usingBLEDDevice())
                      devLetter = getCalibrationDevLetter();

              if (devLetter !== null) {
                  var data = {
                      'command' : 'calibrateStop',
                      'devLetter' : devLetter
                  }
                  console.log(data);
                  //Send message to app to stop calibration
                  cs.send(JSON.stringify(data));
              }

              return false;
          }



          /* Close DapLinkModal modal */
          function closeDapLinkModal() {
              removeVideos();

              var devLetter = null;
              if (usingSerialDevice())
                  devLetter =  'A'  // Serial connection is always devLetter = A.

                  if (devLetter !== null) {
                      var data = {
                          'command' : 'DAPLinkStop',
                          'devLetter' : devLetter
                      }
                      console.log(data);
                      //Send message to app to stop calibration
                      cs.send(JSON.stringify(data));
                  }

              return false;
          }
