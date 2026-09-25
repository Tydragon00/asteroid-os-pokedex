import QtQuick
import org.asteroid.controls
import Pokedex

Application {
    id: app

    // Same colours as poke-dex.desktop.template so that the launcher tile and
    // the application background match. The flat mesh animates blobs of the
    // outer colour towards the screen edges, so it stays a neutral dark grey
    // to avoid tinting the corners.
    centerColor: "#2b2928"
    outerColor: "#1a1918"

    LayerStack {
        id: layerStack
        visible: Repository.ready
        firstPage: firstPageComponent
    }

    Label {
        anchors.centerIn: parent
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: !Repository.ready
        text: "Database error: " + Repository.errorString
    }

    Component {
        id: firstPageComponent
        GenerationListPage { pageStack: layerStack }
    }
}
