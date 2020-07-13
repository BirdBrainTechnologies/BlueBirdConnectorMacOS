
/* Close calibration modal */
function closeModal() {
    removeVideos();
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

/* Launch calibration modal and position elements */
function launchCalibrate(devLetter, deviceName) {
    closeModal();
    setCalibrationDevLetter (devLetter);
    
    // set the appropriate calibration video
    var devVideo = getDeviceVideo(deviceName);
    
    var data = {
        'command' : 'calibrate',
        'devLetter' : devLetter
    }
    console.log(data);
    cs.send(JSON.stringify(data));
    
    launchVideo(devVideo);
}

function launchBluetooth() {
    launchVideo("Plug in Dongle_2.mp4");
    
    // Show bluetooth spinner
    $('#indicators .fa-spin').css("display", "block");
    
    return false;
}

/* Toggle connected section */
function toggleConnected() {
    var visible = $('#connected').css('display') != 'none';
    
    $('#connected').slideToggle();
    
    if(!visible)
        $('body').css('backgroundColor', '#881199');
    else
        $('body').css('backgroundColor', '#089BAB');
}


/* Launch calibration modal and position elements */
function launchDAPLinkUpgradeVideo() {
    launchVideo("Reset Button Press.mp4");
}


function launchNativeMacOSBLEvideo() {
    launchVideo("NativeMacBLEon.mp4");
    
}

/*
 * Add and launch a video
 */
function launchVideo(videoName) {
    console.log("launchVideo " + videoName);
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
    console.log("launchVideo before switch for " + videoName);
    switch(videoName){
        case "Plug in Dongle_2.mp4":
            icon.setAttribute("class", "fab fa-bluetooth-b");
            span.setAttribute("id", "Connection_Failure");
            span.textContent=" " + translationTable["Connection_Failure"] + " ";
            icon2.setAttribute("class", "fab fa-usb");
            break;
        case "HummBit Figure 8_2.mp4":
        case "MicroBit Figure 8_2.mp4":
        case "Finch_Calibration.mp4":
            section.setAttribute("id", "calibrate-modal");
            icon.setAttribute("class", "fas fa-compass");
            icon2 = null;
            
            onClickCloseBtn = "return closeCalibrationModal();";
            //<a href="#" onclick="return closeCalibrationModal();" class="close btn btn-modal"><i class="fas fa-times"></i></a>
            
            span.setAttribute("id", "CompassCalibrate");
            span.textContent=" " + translationTable["CompassCalibrate"] + " ";
            const status = document.createElement('div');
            //status.setAttribute("style", "position: relative; margin: 0 auto; height: auto; width: auto; top: 50%; transform: translateY(-50%);")
            status.setAttribute("class", "status /*status-success*/ /*status-fail*/");
            const check = document.createElement('i');
            check.setAttribute("class", "fas fa-check bounce");
            status.appendChild(check);
            const times = document.createElement('i');
            times.setAttribute("class", "fas fa-times bounce");
            status.appendChild(times);
            animation.appendChild(status);
            break;
        case "Reset Button Press.mp4": //daplink video
            //<a href="#" onclick="return closeDapLinkModal();" class="close btn btn-modal"><i class="fas fa-times"></i></a>
            onClickCloseBtn = "return closeDapLinkModal();";
            
            icon = null;
            span.setAttribute("id", "Update_firmware");
            span.textContent=" " + translationTable["Update_firmware"] + " ";
            icon2 = null;
            
            section.setAttribute("data-backdrop", "static");
            section.setAttribute("data-keyboard", "false");
            break;
        case "NativeMacBLEon.mp4":
            section.setAttribute("id", "nativeMacOSBLE-modal");
            icon.setAttribute("class", "fab fa-bluetooth-b");
            span.setAttribute("id", "Connection_Failure");
            span.textContent=" " + translationTable["Connection_Failure"] + " ";
            icon2.setAttribute("class", "fab fa-usb");
            break;
        default:
            icon = null;
    }
    console.log("launchVideo after switch for " + videoName);
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
    //videoElement.setAttribute("style", "position: relative; display: block; margin: 0 auto; height: auto; width: 95%; top: 50%; transform: translateY(-50%);")
    //videoElement.setAttribute("style", "position: relative; display: block; margin: 0 auto; height: auto; width: 95%;")
    videoElement.src = "vid/" + videoName;
    //videoElement.autoplay = true;
    videoElement.muted = true; //video must be muted to autoplay on Android.
    //Wait until the video is ready to play to display it.
    videoElement.addEventListener('canplay',function () {
                                  console.log("launchVideo about to show " + videoName);
                                  section.setAttribute("style", "display: block;");
                                  videoElement.play();
                                  },false);
    console.log("launchVideo about to add to document: " + videoName);
    //connect up the finished parts
    container.appendChild(header);
    animation.appendChild(videoElement);
    container.appendChild(animation);
    //document.body.appendChild(container);
    section.appendChild(container);
    document.body.appendChild(section);
    
    /* If overlay of modal window is clicked, close calibration window */
    $(".modal").click(function() { closeModal(); close }).children().click(function(e) { return false; });
};

/**
 * Removes any videos that are currently playing.
 * We only play one at a time anyway.
 */
function removeVideos() {
    const videosOpen = document.getElementsByTagName("video").length;
    if (videosOpen > 0){
        for (var i = 0; i < videosOpen; i++) {
            const videoElement = document.getElementsByTagName("video")[i];
            removeVideo(videoElement);
        }
    }
};
function removeVideo(videoElement) {
    console.log("removing video " + videoElement.id);
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
};
