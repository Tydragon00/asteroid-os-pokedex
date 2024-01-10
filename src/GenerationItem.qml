import QtQuick 2.9
import org.asteroid.controls 1.0
import org.mydb 1.0

Item {
    property string serieName

    width: app.width
    height: app.height

    Component { id: pokemon; Pokemon { serieNameBy: serieName } }

    Item {
        width: parent.width
        height: parent.height

        MouseArea {
            id: clickArea
            width: parent.width
            height: parent.height
            onClicked: {
                layerStack.push(pokemon)
            }

            Rectangle {
                width: 250
                height: 150
                color: "transparent"
                border.color: "grey"
                border.width: 4
                radius: 26
                anchors.centerIn: parent

                Text {
                    text: serieName.indexOf(' ') !== -1 ? serieName.replace(' ', '\n') : serieName
                    anchors.centerIn: parent
                    font.pixelSize: 30
                    color: "white"
                }
            }
        }
    }
}
