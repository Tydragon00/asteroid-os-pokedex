#include <asteroidapp.h>

#include <QGuiApplication>
#include <QQuickView>
#include <QScopedPointer>

int main(int argc, char *argv[])
{
    // AsteroidApp::application() returns the QGuiApplication cached by the
    // mapplauncherd booster; creating another one here would abort.
    QScopedPointer<QGuiApplication> application(AsteroidApp::application(argc, argv));

    // The QML root is an org.asteroid.controls Application item, so the window
    // comes from the QQuickView the framework hands to boosted apps; a
    // QQmlApplicationEngine would run without ever showing a window.
    QScopedPointer<QQuickView> view(AsteroidApp::createView());
    view->setSource(QUrl(QStringLiteral("qrc:/Pokedex/main.qml")));

    if (view->status() == QQuickView::Error)
        return -1;

    view->resize(application->primaryScreen()->size());
    view->show();

    return application->exec();
}
