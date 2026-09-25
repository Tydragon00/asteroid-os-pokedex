import QtQuick
import org.asteroid.controls
import Pokedex

// One Pokémon per page; swipe horizontally to browse the generation.
Item {
    id: page

    property string generationName

    // LayerStack sets these as initial properties when pushing the page.
    property int depth
    property var pop

    ListView {
        id: pokemonList
        anchors.fill: parent
        orientation: Qt.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: 250
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: width
        model: Repository.pokemonsForGeneration(page.generationName)

        delegate: PokemonItem {}
    }
}
