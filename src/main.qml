import QtQml 2.2
import QtQuick 2.9
import org.asteroid.controls 1.0
import org.mydb 1.0
Application {
    id: app

    centerColor: "#000000"
    outerColor: "#282121"


    MyDatabase {
        id: mydb
        property var serieList: mydb.getGenerations()
    }
    LayerStack {
        id: layerStack
        firstPage: firstPageComponent
    }

    Component {
        id: firstPageComponent
        Item {
            ListView {
                id: flick
                anchors.fill: parent
                model: mydb.serieList.length

                highlight: Item { width: app.width }
                clip: true
                snapMode: ListView.SnapToItem
                orientation: Qt.Horizontal

                property int currentIndex: Math.round(contentX/(app.width))

                delegate: GenerationItem {
                    serieName: mydb.serieList[modelData]
                }
            }
        }
    }

}
