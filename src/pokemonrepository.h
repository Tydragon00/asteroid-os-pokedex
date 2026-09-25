#ifndef POKEMONREPOSITORY_H
#define POKEMONREPOSITORY_H

#include <QHash>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QVector>
#include <QtQml/qqmlregistration.h>

class PokemonListModel;
struct PokemonEntry;

// Read-only access to the Pokédex database installed by the package. Exposed
// to QML as the "Repository" singleton of the Pokedex module.
class PokemonRepository : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Repository)
    QML_SINGLETON

    Q_PROPERTY(bool ready READ isReady CONSTANT)
    Q_PROPERTY(QString errorString READ errorString CONSTANT)
    Q_PROPERTY(QString language READ language CONSTANT)
    Q_PROPERTY(QStringList generations READ generations CONSTANT)

public:
    explicit PokemonRepository(QObject *parent = nullptr);
    ~PokemonRepository() override;

    bool isReady() const { return m_ready; }
    QString errorString() const { return m_errorString; }
    QString language() const { return m_language; }
    QStringList generations() const { return m_generations; }

    // Returns the Pokémon of a generation. Models are cached, so calling this
    // again for the same generation returns the same object.
    Q_INVOKABLE PokemonListModel *pokemonsForGeneration(const QString &generationName);

    // Number of Pokémon in a generation, for the home page.
    Q_INVOKABLE int pokemonCount(const QString &generationName) const;

    // Localized "Generation I" style title for a database generation name.
    Q_INVOKABLE QString generationTitle(const QString &generationName) const;

    // "#0001" style dex number.
    Q_INVOKABLE QString dexNumber(int pokemonId) const;

private:
    void loadGenerations();
    QVector<PokemonEntry> fetchPokemons(const QString &where, const QVariantMap &bindings) const;
    static QString detectLanguage();

    bool m_ready = false;
    QString m_errorString;
    QString m_language;
    QStringList m_generations;
    QHash<QString, PokemonListModel *> m_models;
};

#endif // POKEMONREPOSITORY_H
