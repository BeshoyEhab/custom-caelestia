#pragma once

#include "configobject.hpp"

using Qt::StringLiterals::operator""_s;

namespace caelestia::config {

class DashboardPerformance : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, showBattery, true)
    CONFIG_PROPERTY(bool, showGpu, true)
    CONFIG_PROPERTY(bool, showCpu, true)
    CONFIG_PROPERTY(bool, showMemory, true)
    CONFIG_PROPERTY(bool, showStorage, true)
    CONFIG_PROPERTY(bool, showNetwork, true)

public:
    explicit DashboardPerformance(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DashboardConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, showOnHover, true)
    CONFIG_PROPERTY(bool, showDashboard, true)
    CONFIG_PROPERTY(bool, showMedia, true)
    CONFIG_PROPERTY(bool, showPerformance, true)
    CONFIG_PROPERTY(bool, showWeather, true)
    CONFIG_GLOBAL_PROPERTY(int, mediaUpdateInterval, 500)
    CONFIG_GLOBAL_PROPERTY(int, resourceUpdateInterval, 1000)
    CONFIG_PROPERTY(int, dragThreshold, 50)
    CONFIG_GLOBAL_PROPERTY(QString, hoverEdge, u"top"_s)
    CONFIG_GLOBAL_PROPERTY(int, hoverWidth, 850)
    CONFIG_GLOBAL_PROPERTY(int, hoverHeight, 20)
    CONFIG_GLOBAL_PROPERTY(bool, showHoverIndicator, true)
    CONFIG_SUBOBJECT(DashboardPerformance, performance)
    CONFIG_GLOBAL_PROPERTY(int, positioningEdge, 2)
    CONFIG_GLOBAL_PROPERTY(qreal, positioningOffset, 0.5)
    CONFIG_GLOBAL_PROPERTY(bool, positioningPixel, false)
    CONFIG_GLOBAL_PROPERTY(int, positioningX, 0)
    CONFIG_GLOBAL_PROPERTY(int, positioningY, 0)

public:
    explicit DashboardConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_performance(new DashboardPerformance(this)) {}
};

} // namespace caelestia::config
