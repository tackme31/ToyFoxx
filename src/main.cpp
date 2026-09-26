#include "MediaSource.h"

#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("ToyFoxx"));
    app.setApplicationVersion(QStringLiteral(TOYFOXX_VERSION));
    app.setOrganizationName(QStringLiteral("ToyFoxx"));

    QCommandLineParser parser;
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument(QStringLiteral("media"),
                                 QCoreApplication::translate("main", "Media file or URL to open."));
    parser.process(app);

    const QStringList arguments = parser.positionalArguments();
    const QUrl initialSource =
        arguments.isEmpty() ? QUrl() : toyfoxx::resolveMediaSource(arguments.constFirst());

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
