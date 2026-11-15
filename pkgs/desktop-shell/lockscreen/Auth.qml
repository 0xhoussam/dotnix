import QtQuick
import Quickshell
import Quickshell.Services.Pam

// One PAM conversation per attempt. `success` fires only after PAM accepts.
Scope {
    id: root
    property bool busy: false
    property string message: ""
    property bool messageIsError: false
    property string password: ""
    signal success()
    signal failed(string message)

    function attempt(pw) {
        if (busy || !pw) return
        busy = true
        message = ""
        password = pw
        pam.start()
    }

    PamContext {
        id: pam
        config: Session.pamService
        // Prompts get the password; info/error messages (security key touch,
        // faillock countdown, ...) are shown.
        onPamMessage: {
            if (responseRequired) {
                respond(root.password)
            } else if (message) {
                root.message = message
                root.messageIsError = messageIsError
            }
        }
        onCompleted: result => {
            root.busy = false
            root.password = ""
            if (result === PamResult.Success) root.success()
            else root.failed(root.message || "Authentication failed")
        }
        onError: err => {
            root.busy = false
            root.password = ""
            root.failed("Could not start authentication")
        }
    }
}
