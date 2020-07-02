function sendMessageToBackend(message) {
    if (window.webkit) {
      window.webkit.messageHandlers.serverSubstitute.postMessage(message);
    } else {
      console.error("window.webkit missing. ", message);
    }
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
    sendMessageToBackend(message);
  } else {
    console.log("Error:", message);
  }
};

const requestObject = {};
requestObject.request = "someID"
requestObject.body = "testing"
sendMessageToBackend(requestObject)





