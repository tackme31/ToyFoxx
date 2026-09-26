#include "MediaSource.h"

#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QSettings>
#include <QStyleHints>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("ToyFoxx"));
    app.setApplicationVersion(QStringLiteral(TOYFOXX_VERSION));
    app.setOrganizationName(QStringLiteral("ToyFoxx"));
    // %APPDATA%\ToyFoxx\ToyFoxx.ini instead of the registry. QML's Settings follows this default.
    QSettings::setDefaultFormat(QSettings::IniFormat);

    QCommandLineParser parser;
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument(QStringLiteral("media"),
                                 QCoreApplication::translate("main", "Media file or URL to open."));
    parser.process(app);

    const QStringList arguments = parser.positionalArguments();
    const QUrl initialSource =
        arguments.isEmpty() ? QUrl() : toyfoxx::resolveMediaSource(arguments.constFirst());

    // Dark only (F-21): the style would otherwise follow the OS light/dark setting.
    QGuiApplication::styleHints()->setColorScheme(Qt::ColorScheme::Dark);
    QQuickStyle::setStyle(QStringLiteral("FluentWinUI3"));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(EXIT_FAILURE); },
        Qt::QueuedConnection);
    engine.setInitialProperties({{QStringLiteral("initialSource"), initialSource}});
    engine.loadFromModule("ToyFoxx", "Main");

    return app.exec();
}
