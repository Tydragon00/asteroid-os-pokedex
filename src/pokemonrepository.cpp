#include "pokemonrepository.h"

#include "pokemonlistmodel.h"

#include <QLocale>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariantList>

#include <utility>

namespace {

const auto connectionName = QStringLiteral("pokedex");
const auto databasePath = QStringLiteral("/usr/share/pokemon/pokemon.db");

const char *statKeys[6] = {"hp", "attack", "defense", "special-attack", "special-defense", "speed"};

} // namespace

PokemonRepository::PokemonRepository(QObject *parent)
    : QObject(parent)
{
    m_language = detectLanguage();

    if (!QSqlDatabase::isDriverAvailable(QStringLiteral("QSQLITE"))) {
        m_errorString = tr("the QSQLITE driver is not available");
        return;
    }

    QSqlDatabase database = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
    database.setDatabaseName(databasePath);
    if (!database.open()) {
        m_errorString = tr("could not open %1: %2").arg(databasePath, database.lastError().text());
        return;
    }

    m_ready = true;
    loadGenerations();
}

PokemonRepository::~PokemonRepository()
{
    if (!QSqlDatabase::contains(connectionName))
        return;

    {
        QSqlDatabase database = QSqlDatabase::database(connectionName);
        if (database.isOpen())
            database.close();
    }
    QSqlDatabase::removeDatabase(connectionName);
}

void PokemonRepository::loadGenerations()
{
    QSqlQuery query(QSqlDatabase::database(connectionName));
    if (!query.exec(QStringLiteral(
            "SELECT DISTINCT GenerationName FROM Pokemons ORDER BY GenerationID"))) {
        qWarning() << "PokemonRepository: could not list generations:" << query.lastError().text();
        return;
    }

    while (query.next())
        m_generations.append(query.value(0).toString());
}

PokemonListModel *PokemonRepository::pokemonsForGeneration(const QString &generationName)
{
    if (PokemonListModel *cached = m_models.value(generationName))
        return cached;

    QVariantMap bindings;
    bindings.insert(QStringLiteral(":generation"), generationName);

    auto *model = new PokemonListModel(this);
    model->setPokemons(fetchPokemons(QStringLiteral("WHERE p.GenerationName = :generation"), bindings));
    m_models.insert(generationName, model);
    return model;
}

int PokemonRepository::pokemonCount(const QString &generationName) const
{
    QSqlQuery query(QSqlDatabase::database(connectionName));
    query.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM Pokemons WHERE GenerationName = :generationName"));
    query.bindValue(QStringLiteral(":generationName"), generationName);
    if (!query.exec() || !query.next()) {
        qWarning() << "PokemonRepository: could not count the Pokémon of" << generationName << ':'
                   << query.lastError().text();
        return 0;
    }

    return query.value(0).toInt();
}

QString PokemonRepository::generationTitle(const QString &generationName) const
{
    QSqlQuery query(QSqlDatabase::database(connectionName));
    query.prepare(QStringLiteral(
        "SELECT n.Name FROM GenerationNames n JOIN Pokemons p ON p.GenerationID = n.GenerationID "
        "WHERE p.GenerationName = :generation AND n.Language = :language LIMIT 1"));
    query.bindValue(QStringLiteral(":generation"), generationName);
    query.bindValue(QStringLiteral(":language"), m_language);
    if (query.exec() && query.next()) {
        const QString title = query.value(0).toString();
        if (!title.isEmpty())
            return title;
    }

    // Fall back to "Generation <roman numeral>".
    return QStringLiteral("Generation ") + generationName.section(QLatin1Char('-'), -1);
}

QString PokemonRepository::dexNumber(int pokemonId) const
{
    return QStringLiteral("#") + QString::number(pokemonId).rightJustified(4, QLatin1Char('0'));
}

QVector<PokemonEntry> PokemonRepository::fetchPokemons(const QString &where,
                                                       const QVariantMap &bindings) const
{
    QVector<PokemonEntry> entries;

    QString sql = QStringLiteral(
        "SELECT p.ID, p.Name, p.ImagePath, p.Types, p.GenerationName, p.GenerationID, "
        "p.Height, p.Weight, p.HP, p.Attack, p.Defense, p.SpecialAttack, p.SpecialDefense, p.Speed, "
        "(SELECT Name FROM PokemonNames WHERE PokemonID = p.ID AND Language = :lang_name) AS LocalName, "
        "(SELECT Genus FROM Genera WHERE PokemonID = p.ID AND Language = :lang_genus) AS LocalGenus, "
        "(SELECT Text FROM FlavorTexts WHERE PokemonID = p.ID AND Language = :lang_flavor) AS LocalFlavor, "
        "(SELECT Genus FROM Genera WHERE PokemonID = p.ID AND Language = 'en') AS EnglishGenus, "
        "(SELECT Text FROM FlavorTexts WHERE PokemonID = p.ID AND Language = 'en') AS EnglishFlavor "
        "FROM Pokemons p");
    if (!where.isEmpty())
        sql += QLatin1Char(' ') + where;
    sql += QStringLiteral(" ORDER BY p.ID");

    QSqlQuery query(QSqlDatabase::database(connectionName));
    query.prepare(sql);
    query.bindValue(QStringLiteral(":lang_name"), m_language);
    query.bindValue(QStringLiteral(":lang_genus"), m_language);
    query.bindValue(QStringLiteral(":lang_flavor"), m_language);
    for (auto it = bindings.constBegin(); it != bindings.constEnd(); ++it)
        query.bindValue(it.key(), it.value());

    if (!query.exec()) {
        qWarning() << "PokemonRepository: could not list Pokémon:" << query.lastError().text();
        return entries;
    }

    while (query.next()) {
        PokemonEntry entry;
        entry.id = query.value(0).toInt();
        entry.name = query.value(1).toString();
        // The QML files live under qrc:/Pokedex/, so relative paths would
        // resolve against that directory. Expose an absolute qrc URL.
        entry.imagePath = QStringLiteral("qrc:/") + query.value(2).toString();
        entry.types = query.value(3).toString().split(QLatin1Char(','), Qt::SkipEmptyParts);
        entry.generationName = query.value(4).toString();
        entry.generationId = query.value(5).toInt();
        entry.height = query.value(6).toInt();
        entry.weight = query.value(7).toInt();

        for (int i = 0; i < 6; ++i) {
            QVariantMap stat;
            stat.insert(QStringLiteral("key"), QString::fromLatin1(statKeys[i]));
            stat.insert(QStringLiteral("value"), query.value(8 + i).toInt());
            entry.stats.append(stat);
        }

        const QString localizedName = query.value(14).toString();
        if (!localizedName.isEmpty())
            entry.name = localizedName;

        entry.genus = query.value(15).toString();
        if (entry.genus.isEmpty())
            entry.genus = query.value(17).toString();

        entry.flavorText = query.value(16).toString();
        if (entry.flavorText.isEmpty())
            entry.flavorText = query.value(18).toString();

        entries.append(entry);
    }

    return entries;
}

// Maps the system locale to the language codes used by the Pokédex database.
QString PokemonRepository::detectLanguage()
{
    const QLocale locale;

    if (locale.language() == QLocale::Chinese)
        return locale.territory() == QLocale::Taiwan ? QStringLiteral("zh-hant") : QStringLiteral("zh-hans");

    const QString code = QLocale::languageToCode(locale.language());
    return code.isEmpty() ? QStringLiteral("en") : code;
}
