
/**
 * closeModal - Close the currently open modal (or modals)
 */
function closeModal() {
    const videosOpen = document.getElementsByTagName("video").length;
    if (videosOpen > 0){
        for (var i = 0; i < videosOpen; i++) {
            const videoElement = document.getElementsByTagName("video")[i];
            //Fully unload the video.
            //see https://stackoverflow.com/questions/3258587/how-to-properly-unload-destroy-a-video-element
            videoElement.pause();
            videoElement.removeAttribute('src'); // empty source
            videoElement.load();

            //Remove the whole modal.
            //Each video is presented inside a div element inside a div element
            //inside a section. This is what must be removed. See launchVideo.
            const animation = videoElement.parentNode;
            const container = animation.parentNode;
            const section = container.parentNode

            section.parentNode.removeChild(section);
        }
    }
};

/**
 * launchCalibrate - Launch calibration modal and position elements. Send
 * calibration request to backend.
 *
 * @param  {string} devLetter  letter assigned to device to calibrate
 * @param  {string} deviceName name of device to calibrate
 */
function launchCalibrate(devLetter, deviceName, hasV2String) {
    sendMessageToBackend(msgTypes.CONSOLE_LOG, {
      consoleLog: "launch calibrate"
    })
    closeModal();

    var data = {
        'command' : 'calibrate',
        'devLetter' : devLetter
    }
    sendMessageToBackend(msgTypes.COMMAND, data)

    // set the appropriate calibration video
    var devVideo = getDeviceVideo(deviceName, (hasV2String == 'true'));
    launchVideo(devVideo);
}

/**
 * launchNativeMacOSBLEvideo - Launch video instructions for turning on ble.
 */
function launchNativeMacOSBLEvideo() {
    launchVideo("NativeMacBLEon.mp4");
}

 /**
  * getDeviceVideo - Get the correct calibration video for the given device
  *
  * @param  {string} deviceName Advertised name of the device to calibrate
  * @param  {boolean} hasV2  true if the device to calibrate has a V2 micro:bit
  * @return {string}            Filename of calibration video
  */
function getDeviceVideo(deviceName, hasV2) {
    var deviceVideo = "HummBit_Calibration.mp4" // default hummingbird video
    switch (deviceName.slice(0,2)) {
        case "MB":
            deviceVideo = hasV2 ? "MicroBit_V2_Calibration.mp4" : "MicroBit_Calibration.mp4"
            break;
        case "BB":
            deviceVideo = hasV2 ? "HummBit_V2_Calibration.mp4" : "HummBit_Calibration.mp4"
            break;
        case "FN":
            deviceVideo = hasV2 ? "Finch_V2_Calibration.mp4" : "Finch_Calibration.mp4"
            break;
    }
    return deviceVideo;
}

 /**
  * launchVideo - Add and launch a video modal.
  *
  * @param  {string} videoName Filename of video to launch
  */
function launchVideo(videoName) {
    sendMessageToBackend(msgTypes.CONSOLE_LOG, {
      consoleLog: "launchVideo " + videoName
    })

    const section = document.createElement('section');
    section.setAttribute("class", "modal");
    section.setAttribute("style", "display: none;")

    //Make a container to hold everything
    const container = document.createElement('div');
    container.setAttribute("class", "container")
    container.setAttribute("style", "position: relative; margin: 0 auto; height: auto; width: 95%; top: 50%; transform: translateY(-50%);");

    //Create the parts
    const header = document.createElement('h2');
    var icon = document.createElement('i');
    const span = document.createElement('span');
    var icon2 = document.createElement('i');

    //Make a container for the video and any other animations
    const animation = document.createElement('div');
    animation.setAttribute("class", "animation");

    //Set to close button action if close button required
    var onClickCloseBtn = null;
    //Set options based on specific video
    switch(videoName){
        case "HummBit_Calibration.mp4":
        case "MicroBit_Calibration.mp4":
        case "Finch_Calibration.mp4":
        case "HummBit_V2_Calibration.mp4":
        case "MicroBit_V2_Calibration.mp4":
        case "Finch_V2_Calibration.mp4":
            section.setAttribute("id", "calibrate-modal");
            icon.setAttribute("class", "fas fa-compass");
            icon2 = null;
            onClickCloseBtn = "return closeModal();";
            span.setAttribute("id", "CompassCalibrate");
            span.textContent=" " + translationTable["CompassCalibrate"] + " ";
            const status = document.createElement('div');
            status.setAttribute("class", "status /*status-success*/ /*status-fail*/");
            const check = document.createElement('i');
            check.setAttribute("class", "fas fa-check bounce");
            status.appendChild(check);
            const times = document.createElement('i');
            times.setAttribute("class", "fas fa-times bounce");
            status.appendChild(times);
            animation.appendChild(status);
            break;
        case "NativeMacBLEon.mp4":
            sendMessageToBackend(msgTypes.CONSOLE_LOG, {
              consoleLog: "launching native mac video"
            })
            section.setAttribute("id", "nativeMacOSBLE-modal");
            icon.setAttribute("class", "fab fa-bluetooth-b");
            span.setAttribute("id", "Connection_Failure");
            span.textContent=" " + translationTable["Connection_Failure"] + " ";
            icon2.setAttribute("class", "fab fa-usb");
            break;
        default:
            icon = null;
    }

    if (icon != null) { header.appendChild(icon); }
    header.appendChild(span);
    if (icon2 != null) { header.appendChild(icon2); }

    //Make a close button if required
    if (onClickCloseBtn != null) {
        //<a href="#" onclick="return closeDapLinkModal();" class="close btn btn-modal"><i class="fas fa-times"></i></a>
        const closeBtn = document.createElement('a');
        closeBtn.setAttribute("href", "#");
        closeBtn.setAttribute("onclick", onClickCloseBtn);
        closeBtn.setAttribute("class", "close btn btn-modal");
        const btnIcon = document.createElement('i');
        btnIcon.setAttribute("class", "fas fa-times");
        closeBtn.appendChild(btnIcon);
        container.appendChild(closeBtn);
    }

    //Make the video element
    const videoElement = document.createElement('video');
    videoElement.setAttribute("type", "video/mp4");
    videoElement.setAttribute("id", "video" + videoName);
    videoElement.setAttribute("loop", "loop");
    videoElement.src = videoName;
    videoElement.muted = true; //video must be muted to autoplay on Android.

    //Wait until the video is ready to play to display it.
    videoElement.addEventListener('canplay',function () {
                                  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
                                    consoleLog: "about to show " + videoName
                                  })
                                  section.setAttribute("style", "display: block;");
                                  videoElement.play();
                                  },false);

    sendMessageToBackend(msgTypes.CONSOLE_LOG, {
      consoleLog: "launchVideo about to add to document: " + videoName
    })
    //connect up the finished parts
    container.appendChild(header);
    animation.appendChild(videoElement);
    container.appendChild(animation);
    section.appendChild(container);
    document.body.appendChild(section);

    /* If overlay of modal window is clicked, close calibration window */
    $(".modal").click(function() { closeModal(); close }).children().click(function(e) { return false; });
};
