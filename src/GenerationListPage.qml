import QtQuick
import org.asteroid.controls
import org.asteroid.utils
import Pokedex

// Home page: a wheel of generations where the selected row always rests in the
// middle of the screen, away from the system gesture areas along the screen
// edges. A row shows the number of Pokémon the generation contains.
Item {
    id: page

    // The LayerStack of the application, used to open a generation.
    property var pageStack

    readonly property real sideMargin: DeviceSpecs.hasRoundScreen ? Dims.w(18) : Dims.w(12)
    readonly property real rowHeight: Dims.h(18)
    readonly property real rowSpacing: Dims.h(3)

    Component {
        id: pokemonPage
        PokemonPage {}
    }

    ListView {
        id: generations
        anchors.fill: parent
        clip: true
        model: Repository.generations
        spacing: page.rowSpacing

        // Keep the selected row, and only it, inside the middle of the screen.
        preferredHighlightBegin: height / 2 - page.rowHeight / 2
        preferredHighlightEnd: height / 2 + page.rowHeight / 2
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: 200
        // Invisible, but lets the view animate when a tapped neighbour becomes
        // the current item.
        highlight: Item { width: generations.width; height: page.rowHeight }

        // Empty room above and below so that the first and last generations can
        // be scrolled into the middle band as well.
        header: Item { width: generations.width; height: generations.height / 2 - page.rowHeight / 2 }
        footer: Item { width: generations.width; height: generations.height / 2 - page.rowHeight / 2 }

        delegate: Item {
            id: row
            width: ListView.view.width
            height: page.rowHeight

            readonly property bool selected: ListView.isCurrentItem

            opacity: selected ? 1.0 : 0.55
            Behavior on opacity { NumberAnimation { duration: 150 } }

            HighlightBar {
                forceOn: row.selected
                onClicked: {
                    if (row.selected)
                        page.pageStack.push(pokemonPage, { "generationName": modelData })
                    else
                        generations.currentIndex = index
                }
            }

            Rectangle {
                id: badge
                anchors {
                    left: parent.left
                    leftMargin: page.sideMargin
                    verticalCenter: parent.verticalCenter
                }
                width: Math.max(height, badgeLabel.implicitWidth + Dims.w(4))
                height: Dims.l(13)
                radius: height / 2
                color: "#33ffffff"

                Label {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: Repository.pokemonCount(modelData)
                    font.pixelSize: Dims.l(5)
                }
            }

            Label {
                anchors {
                    left: badge.right
                    leftMargin: DeviceSpecs.hasRoundScreen ? Dims.w(6) : Dims.w(10)
                    right: parent.right
                    rightMargin: page.sideMargin
                    verticalCenter: parent.verticalCenter
                }
                text: Repository.generationTitle(modelData)
                font.pixelSize: Dims.l(6)
            }
        }
    }
}
