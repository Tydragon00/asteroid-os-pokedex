import QtQuick 2.9
import org.asteroid.controls 1.0
import org.mydb 1.0
Item {

    width: app.width
    height: app.height

    property string serieNameBy

    MyDatabase {
        id: mydb
        property var pokemonList: mydb.getPokemonList(serieNameBy)
    }
    LayerStack {
        id: layerStack
        firstPage: testPageComponent
    }

    Component {
        id: testPageComponent
        Item {
            ListView {
                id: flick
                anchors.fill: parent
                model: mydb.pokemonList

                highlight: Item { width: app.width }
                clip: true
                snapMode: ListView.SnapToItem
                orientation: Qt.Horizontal

                property int currentIndex: Math.round(contentX/(app.width))

                delegate: PokemonItem {
                    gormitaName: modelData.name
                    imagePath: modelData.image
                    typesList: modelData.types
                }
            }
        }
    }
}
