import QtQuick

Item {
    id: card
    property var game
    property bool focusRing: false
    signal activated()
    width: 220
    height: 330

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: 14
        color: "#232a4a"
        clip: true
        border.width: card.focusRing ? 4 : 0
        border.color: "#4da3ff"

        Image {
            id: img
            anchors.fill: parent
            source: card.game ? card.game.cover : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
        Text {
            visible: img.status !== Image.Ready
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -30
            text: card.game ? card.game.name.charAt(0).toUpperCase() : ""
            font.pixelSize: 110
            color: "#4da3ff"
            opacity: 0.6
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 84
            color: "#d00f1220"
            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 2
                Text {
                    width: parent.width
                    text: card.game ? card.game.name : ""
                    color: "#ffffff"
                    font.pixelSize: 20
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: card.game ? (card.game.consoleLabel !== "" ? card.game.consoleLabel : card.game.sourceLabel) : ""
                    color: "#8d96b5"
                    font.pixelSize: 16
                    elide: Text.ElideRight
                }
            }
        }
        Text {
            visible: card.game && card.game.favorite
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 10
            text: "★"
            color: "#ffd24d"
            font.pixelSize: 30
        }
    }
    MouseArea { anchors.fill: parent; onClicked: card.activated() }
}
