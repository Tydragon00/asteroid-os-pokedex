#ifndef POKEMONLISTMODEL_H
#define POKEMONLISTMODEL_H

#include <QAbstractListModel>
#include <QByteArray>
#include <QHash>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVector>

struct PokemonEntry
{
    int id = 0;
    int generationId = 0;
    QString name;
    QString imagePath;
    QStringList types;
    QString generationName;
    QString genus;
    QString flavorText;
    int height = 0; // decimetres, as returned by the API
    int weight = 0; // hectograms, as returned by the API
    QVariantList stats;
};

// List of Pokémon of one generation, exposed to QML with named roles.
class PokemonListModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Role {
        IdRole = Qt::UserRole + 1,
        NameRole,
        ImageRole,
        TypesRole,
        GenerationNameRole,
        GenerationIdRole,
        GenusRole,
        FlavorTextRole,
        HeightRole,
        WeightRole,
        StatsRole,
    };
    Q_ENUM(Role)

    explicit PokemonListModel(QObject *parent = nullptr);

    void setPokemons(const QVector<PokemonEntry> &pokemons);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

private:
    QVector<PokemonEntry> m_pokemons;
};

#endif // POKEMONLISTMODEL_H
