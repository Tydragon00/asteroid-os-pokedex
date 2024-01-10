import QtQuick 2.9
import org.asteroid.controls 1.0
import org.mydb 1.0

Item {

    property string gormitaName
    property string imagePath
    property variant typesList

    width: app.width
    height: app.height



    Column {
        anchors.centerIn: parent

        Label {
            id: hello
            text: gormitaName
            font.pixelSize: 30
            verticalAlignment: Text.AlignVCenter
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.rightMargin: 50

        }

        Image {
            source: imagePath
            width: 200
            height: 200
            anchors.leftMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter // Centra i rettangoli

            Repeater {
                model: typesList // Itera attraverso la lista dei tipi

                Rectangle {
                    width: 80
                    height: 40
                    color: modelData.color
                    border.color: "black"
                    border.width: 1
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: modelData.type
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
