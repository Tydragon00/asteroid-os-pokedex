import QtQuick
import org.asteroid.controls

// Coloured type badge. The text switches between black and white depending on
// how bright the type colour is.
Item {
    id: chip

    property string typeName

    // Official Pokémon type colours.
    readonly property var typeColors: ({
        "Normal": "#a8a77a", "Fire": "#ee8130", "Water": "#6390f0",
        "Electric": "#f7d02c", "Grass": "#7ac74c", "Ice": "#96d9d6",
        "Fighting": "#c22e28", "Poison": "#a33ea1", "Ground": "#e2bf65",
        "Flying": "#a98ff3", "Psychic": "#f95587", "Bug": "#a6b91a",
        "Rock": "#b6a136", "Ghost": "#735797", "Dragon": "#6f35fc",
        "Dark": "#705746", "Steel": "#b7b7ce", "Fairy": "#d685ad"
    })

    readonly property color chipColor: typeColors[typeName] !== undefined ? typeColors[typeName] : "#b8b8b8"
    readonly property color textColor: (0.299 * chipColor.r + 0.587 * chipColor.g + 0.114 * chipColor.b) > 0.6 ? "black" : "white"

    width: Math.max(Dims.w(22), label.implicitWidth + Dims.w(6))
    height: Dims.h(9)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: chip.chipColor
        border.color: Qt.darker(chip.chipColor, 1.6)
        border.width: 1
    }

    Label {
        id: label
        anchors.centerIn: parent
        text: chip.typeName
        color: chip.textColor
        font.pixelSize: Dims.l(5)
    }
}
