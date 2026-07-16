#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

class GeneralApps : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(QStringList, terminal, { u"foot"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, audio, { u"pavucontrol"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, playback, { u"mpv"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, explorer, { u"thunar"_s })

public:
    explicit GeneralApps(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class GeneralIdle : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(bool, lockBeforeSleep, true)
    CONFIG_GLOBAL_PROPERTY(bool, inhibitWhenAudio, true)
    CONFIG_GLOBAL_PROPERTY(QVariantList, timeouts,
        {
            vmap({
                { u"timeout"_s, 180 },
                { u"idleAction"_s, u"lock"_s },
            }),
            vmap({
                { u"timeout"_s, 300 },
                { u"idleAction"_s, u"dpms off"_s },
                { u"returnAction"_s, u"dpms on"_s },
            }),
            vmap({
                { u"timeout"_s, 600 },
                { u"idleAction"_s, QStringList{ u"systemctl"_s, u"suspend-then-hibernate"_s } },
            }),
        })

public:
    explicit GeneralIdle(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class GeneralBattery : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(int, warningLevel, 20)
    CONFIG_GLOBAL_PROPERTY(int, criticalLevel, 5)
    CONFIG_GLOBAL_PROPERTY(int, hibernateLevel, 3)

public:
    explicit GeneralBattery(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class GeneralConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(QString, logo)
    CONFIG_PROPERTY(bool, showOverFullscreen, false)
    CONFIG_PROPERTY(qreal, mediaGifSpeedAdjustment, 300)
    CONFIG_PROPERTY(qreal, sessionGifSpeed, 0.7)
    CONFIG_SUBOBJECT(GeneralApps, apps)
    CONFIG_SUBOBJECT(GeneralIdle, idle)
    CONFIG_SUBOBJECT(GeneralBattery, battery)

public:
    explicit GeneralConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_apps(new GeneralApps(this))
        , m_idle(new GeneralIdle(this))
        , m_battery(new GeneralBattery(this)) {}
};

} // namespace caelestia::config
