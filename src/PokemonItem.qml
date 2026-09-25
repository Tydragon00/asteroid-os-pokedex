import QtQuick
import org.asteroid.controls
import org.asteroid.utils
import Pokedex

// One Pokémon page inside the horizontal list of PokemonPage. The details
// scroll vertically while the pages snap horizontally.
Item {
    id: pokemon

    // Roles of the PokemonListModel.
    required property int pokemonId
    required property string name
    required property string image
    required property var types
    required property string genus
    required property string flavorText
    required property int pokemonHeight
    required property int pokemonWeight
    required property var stats

    width: ListView.view ? ListView.view.width : 0
    height: ListView.view ? ListView.view.height : 0

    PageHeader {
        id: header
        text: pokemon.name
    }

    Flickable {
        id: scroller
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentHeight: content.height + Dims.h(2)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: scroller.width
            spacing: Dims.h(1.5)

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: text.length > 0
                text: pokemon.genus
                font.pixelSize: Dims.l(5)
                opacity: 0.6
            }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: pokemon.image
                sourceSize: Qt.size(width, height)
                asynchronous: true
                width: Dims.l(38)
                height: width
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Repository.dexNumber(pokemon.pokemonId)
                      + "     " + (pokemon.pokemonHeight / 10).toFixed(1) + " m"
                      + "     " + (pokemon.pokemonWeight / 10).toFixed(1) + " kg"
                font.pixelSize: Dims.l(5)
                opacity: 0.7
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Dims.w(3)

                Repeater {
                    model: pokemon.types
                    TypeChip { typeName: modelData }
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.8
                spacing: Dims.h(0.5)

                Repeater {
                    model: pokemon.stats
                    StatBar {
                        statKey: modelData.key
                        value: modelData.value
                    }
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                lineHeight: 1.1
                visible: text.length > 0
                text: pokemon.flavorText
                font.pixelSize: Dims.l(5)
                opacity: 0.75
            }
        }
    }
}
