import QtQuick
import QtQuick.Controls.Basic

Button {
    id: b
    property color accent: "#4da3ff"
    font.pixelSize: 24
    implicitHeight: 64
    leftPadding: 28
    rightPadding: 28
    focusPolicy: Qt.StrongFocus

    contentItem: Text {
        text: b.text
        font: b.font
        color: "#e8ecf8"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: 12
        color: b.activeFocus ? b.accent : (b.down ? "#2f3868" : "#232a4a")
        border.width: b.activeFocus ? 3 : 0
        border.color: "#ffffff"
    }
    Keys.onReturnPressed: b.clicked()
    Keys.onEnterPressed: b.clicked()
}
