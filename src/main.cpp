#include <asteroidapp.h>
#include <QGuiApplication>
#include <QQmlApplicationEngine>

#include <QSqlDatabase>
#include <QSqlDriver>
#include <QSqlError>
#include <QSqlQuery>

#include <QObject>
#include <QDebug>

class MyDatabase : public QObject
{
    Q_OBJECT

public:
    explicit MyDatabase(QObject *parent = 0) : QObject(parent) {}

    Q_INVOKABLE QStringList getGenerations()
    {
        QStringList seriesList;

        QSqlQuery query;
        query.prepare("SELECT distinct GenerationName FROM Pokemons ORDER BY GenerationID");

        if (!query.exec())
        {
            qWarning() << "MainWindow::OnSearchClicked - ERROR: " << query.lastError().text();
            return seriesList; // Restituisci un array vuoto in caso di errore
        }

        while (query.next())
        {
            QString GenerationName = query.value(0).toString();
            seriesList.append(GenerationName);
        }

        if (seriesList.isEmpty())
        {
            seriesList.append("generation not found");
        }

        return seriesList;
    }

    Q_INVOKABLE QVariantList getPokemonList(const QString &serieName)
    {
        QList<QVariant> resultList;

        QMap<QString, QString> typeColors = {
            {"Normal", "lightgray"},
            {"Fire", "red"},
            {"Water", "blue"},
            {"Electric", "yellow"},
            {"Grass", "green"},
            {"Ice", "lightblue"},
            {"Fighting", "brown"},
            {"Poison", "purple"},
            {"Ground", "saddlebrown"},
            {"Flying", "lightskyblue"},
            {"Psychic", "deeppink"},
            {"Bug", "limegreen"},
            {"Rock", "burlywood"},
            {"Ghost", "mediumpurple"},
            {"Dragon", "darkslateblue"},
            {"Dark", "dimgray"},
            {"Steel", "lightslategrey"},
            {"Fairy", "pink"}};

        QSqlQuery query;
        query.prepare("SELECT name, GenerationName, ImagePath, Types FROM Pokemons WHERE GenerationName = :serieName ORDER BY ID");
        query.bindValue(":serieName", serieName);

        if (!query.exec())
        {
            qWarning() << "MainWindow::OnSearchClicked - ERROR: " << query.lastError().text();
            return QVariantList(); // Restituisci una lista vuota in caso di errore
        }

        while (query.next())
        {
            QVariantMap map;
            map.insert("name", query.value(0).toString());
            map.insert("GenerationName", query.value(1).toString());
            map.insert("image", query.value(2).toString());

            QString typesString = query.value(3).toString();
            QStringList types = typesString.split(","); // Supponendo che i tipi siano separati da spazi

            QVariantList typesList;
            for (const QString &type : types)
            {
                QVariantMap typeMap;
                typeMap.insert("type", type);
                if (typeColors.contains(type))
                {
                    typeMap.insert("color", typeColors[type]);
                }
                else
                {
                    typeMap.insert("color", "lightgray");
                }
                typesList.append(typeMap);
            }

            map.insert("types", typesList);
            resultList.append(map);
        }

        if (resultList.isEmpty())
        {
            QVariantMap notFound;
            notFound.insert("name", "person not found");
            notFound.insert("GenerationName", "");
            notFound.insert("image", ""); // Immagine vuota per questo caso
            resultList.append(notFound);
        }

        return resultList;
    }
};

// We want to avoid defining the class above in a my_database.h file. That would let the MOC
// pre-processor find what it needs automatically, but we'd have another file in this demo.
// To avoid that, we have to include the .moc manually. See: https://stackoverflow.com/a/3005403
#include "main.moc"

void databaseConnect()
{
    const QString DRIVER("QSQLITE");

    if (QSqlDatabase::isDriverAvailable(DRIVER))
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(DRIVER);

        db.setDatabaseName("/home/ceres/pokemon.db");

        if (!db.open())
            qWarning() << "MainWindow::DatabaseConnect - ERROR: " << db.lastError().text();
    }
    else
        qWarning() << "MainWindow::DatabaseConnect - ERROR: no driver " << DRIVER << " available";
}

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication application(argc, argv);

    application.setApplicationName("Qt QML SQL example");

    databaseConnect();

    qmlRegisterType<MyDatabase>("org.mydb", 1, 0, "MyDatabase");

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:///main.qml")));

    if (engine.rootObjects().isEmpty())
    {
        QCoreApplication::exit(-1);
    }
    return AsteroidApp::main(argc, argv);
}
