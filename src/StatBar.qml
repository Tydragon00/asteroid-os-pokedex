import QtQuick
import org.asteroid.controls

// One base stat as a label, a bar and the value.
Item {
    id: bar

    property string statKey
    property int value

    readonly property var statLabels: ({
        "hp": "HP",
        "attack": "Attack",
        "defense": "Defense",
        "special-attack": "Sp. Atk",
        "special-defense": "Sp. Def",
        "speed": "Speed"
    })

    width: parent ? parent.width : 0
    height: Dims.h(6)

    Label {
        id: name
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        width: Dims.w(30)
        text: bar.statLabels[bar.statKey] !== undefined ? bar.statLabels[bar.statKey] : bar.statKey
        font.pixelSize: Dims.l(5)
        opacity: 0.8
    }

    Rectangle {
        id: track
        anchors {
            left: name.right
            right: valueLabel.left
            rightMargin: Dims.w(2)
            verticalCenter: parent.verticalCenter
        }
        height: Dims.h(2.4)
        radius: height / 2
        color: "#22ffffff"

        Rectangle {
            width: parent.width * Math.min(bar.value / 255, 1)
            height: parent.height
            radius: height / 2
            color: bar.value >= 100 ? "#7ac74c" : (bar.value >= 60 ? "#f7d02c" : "#ee8130")
        }
    }

    Label {
        id: valueLabel
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        width: Dims.w(10)
        horizontalAlignment: Text.AlignRight
        text: bar.value
        font.pixelSize: Dims.l(5)
    }
}
