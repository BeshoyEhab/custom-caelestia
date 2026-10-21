#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qvariant.h>

using Qt::StringLiterals::operator""_s;

namespace caelestia::config {

class DesktopClockBackground : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(bool, blur, true)

public:
    explicit DesktopClockBackground(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopClockShadow : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(qreal, blur, 0.4)

public:
    explicit DesktopClockShadow(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopClockQuote : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(QString, text, QString())

public:
    explicit DesktopClockQuote(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopClockFont : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(QString, family, QString())
    CONFIG_PROPERTY(qreal, size, 1.0)
    CONFIG_PROPERTY(int, weight, 700)
    CONFIG_PROPERTY(int, width, 100)
    CONFIG_PROPERTY(int, roundness, 0)

public:
    explicit DesktopClockFont(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopClockDigital : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(QString, orientation, QStringLiteral("auto"))
    CONFIG_PROPERTY(bool, showDate, true)
    CONFIG_PROPERTY(bool, showSeconds, false)
    CONFIG_PROPERTY(bool, animateChange, true)
    CONFIG_PROPERTY(bool, adaptiveAlignment, true)
    CONFIG_SUBOBJECT(DesktopClockFont, font)

public:
    explicit DesktopClockDigital(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_font(new DesktopClockFont(this)) {}
};

class DesktopClockCookie : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, sides, 14)
    CONFIG_PROPERTY(QString, dialNumberStyle, QStringLiteral("full"))
    CONFIG_PROPERTY(QString, hourHandStyle, QStringLiteral("fill"))
    CONFIG_PROPERTY(QString, minuteHandStyle, QStringLiteral("medium"))
    CONFIG_PROPERTY(QString, secondHandStyle, QStringLiteral("dot"))
    CONFIG_PROPERTY(QString, dateStyle, QStringLiteral("bubble"))
    CONFIG_PROPERTY(bool, timeIndicators, true)
    CONFIG_PROPERTY(bool, hourMarks, false)
    CONFIG_PROPERTY(bool, dateInClock, true)
    CONFIG_PROPERTY(bool, useSineCookie, false)
    CONFIG_PROPERTY(bool, constantlyRotate, false)

public:
    explicit DesktopClockCookie(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopClock : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, scale, 1.0)
    // 9 anchor presets, or "auto-empty"/"auto-full": snap the clock to the
    // flattest / busiest region of the wallpaper (see least_busy_region.py).
    CONFIG_PROPERTY(QString, position, QStringLiteral("bottom-right"))
    CONFIG_PROPERTY(QString, clockStyle, QStringLiteral("digital"))
    CONFIG_PROPERTY(bool, invertColors, false)
    CONFIG_SUBOBJECT(DesktopClockBackground, background)
    CONFIG_SUBOBJECT(DesktopClockShadow, shadow)
    CONFIG_PROPERTY(bool, animatePosition, true)
    CONFIG_SUBOBJECT(DesktopClockQuote, quote)
    CONFIG_SUBOBJECT(DesktopClockDigital, digital)
    CONFIG_SUBOBJECT(DesktopClockCookie, cookie)

public:
    explicit DesktopClock(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_background(new DesktopClockBackground(this))
        , m_shadow(new DesktopClockShadow(this))
        , m_quote(new DesktopClockQuote(this))
        , m_digital(new DesktopClockDigital(this))
        , m_cookie(new DesktopClockCookie(this)) {}
};

class BackgroundVisualiser : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, autoHide, true)
    CONFIG_PROPERTY(bool, blur, false)
    CONFIG_PROPERTY(bool, mic, false)
    CONFIG_PROPERTY(qreal, rounding, 1)
    CONFIG_PROPERTY(qreal, spacing, 1)

public:
    explicit BackgroundVisualiser(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BackgroundConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, wallpaperEnabled, true)
    // "crop" = PreserveAspectCrop (default), "fit" = PreserveAspectFit, "stretch" = Stretch
    CONFIG_PROPERTY(QString, wallpaperMode, QStringLiteral("crop"))
    CONFIG_PROPERTY(bool, wallpaperRotation, false)
    CONFIG_PROPERTY(int, wallpaperRotationInterval, 2)
    CONFIG_PROPERTY(QString, videoBackend, QStringLiteral("mpvpaper"))
    CONFIG_PROPERTY(bool, videoAutoStop, true)
    // "" = stop/pause only when the wallpaper itself is hidden (default:
    // -a FULL blanked every workspace when any window was fullscreen
    // anywhere, e.g. a game on another workspace).
    CONFIG_PROPERTY(QString, videoAutoMode, QStringLiteral(""))
    CONFIG_PROPERTY(QVariantMap, videoOutputs, {})
    CONFIG_SUBOBJECT(DesktopClock, desktopClock)
    CONFIG_SUBOBJECT(BackgroundVisualiser, visualiser)

public:
    explicit BackgroundConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_desktopClock(new DesktopClock(this))
        , m_visualiser(new BackgroundVisualiser(this)) {}
};

} // namespace caelestia::config
