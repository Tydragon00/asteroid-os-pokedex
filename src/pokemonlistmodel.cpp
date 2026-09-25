#include "pokemonlistmodel.h"

PokemonListModel::PokemonListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

void PokemonListModel::setPokemons(const QVector<PokemonEntry> &pokemons)
{
    beginResetModel();
    m_pokemons = pokemons;
    endResetModel();
}

int PokemonListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;

    return m_pokemons.size();
}

QVariant PokemonListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_pokemons.size())
        return {};

    const PokemonEntry &pokemon = m_pokemons.at(index.row());
    switch (role) {
    case IdRole:
        return pokemon.id;
    case NameRole:
        return pokemon.name;
    case ImageRole:
        return pokemon.imagePath;
    case TypesRole:
        return pokemon.types;
    case GenerationNameRole:
        return pokemon.generationName;
    case GenerationIdRole:
        return pokemon.generationId;
    case GenusRole:
        return pokemon.genus;
    case FlavorTextRole:
        return pokemon.flavorText;
    case HeightRole:
        return pokemon.height;
    case WeightRole:
        return pokemon.weight;
    case StatsRole:
        return pokemon.stats;
    default:
        return {};
    }
}

QHash<int, QByteArray> PokemonListModel::roleNames() const
{
    return {
        {IdRole, "pokemonId"},
        {NameRole, "name"},
        {ImageRole, "image"},
        {TypesRole, "types"},
        {GenerationNameRole, "generationName"},
        {GenerationIdRole, "generationId"},
        {GenusRole, "genus"},
        {FlavorTextRole, "flavorText"},
        {HeightRole, "pokemonHeight"},
        {WeightRole, "pokemonWeight"},
        {StatsRole, "stats"},
    };
}
