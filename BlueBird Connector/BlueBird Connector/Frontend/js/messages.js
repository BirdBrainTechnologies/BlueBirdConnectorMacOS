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

/*const requestObject = {};
requestObject.request = "someID"
requestObject.body = "testing"
sendMessageToBackend(requestObject)*/


CallbackManager = {}

CallbackManager.scanStarted = function() {
  if (!($('#find-button i').hasClass('fa-spin'))){
    $('#find-button i').addClass('fa-spin');
    $('#findBtnText').text(" "+translationTable["finding_robots"]);
  }
}
CallbackManager.scanEnded = function() {
  if ($('#find-button i').hasClass('fa-spin')) {
    $('#find-button i').removeClass('fa-spin');
    $('#findBtnText').text(" "+translationTable["find_robots"]);
  }
}
