#pragma once

#include "configobject.hpp"

namespace caelestia::config {

class SidebarConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, dragThreshold, 80)
    CONFIG_GLOBAL_PROPERTY(QString, hoverEdge, u"topRight"_s)
    CONFIG_GLOBAL_PROPERTY(int, hoverWidth, 60)
    CONFIG_GLOBAL_PROPERTY(int, hoverHeight, 60)
    CONFIG_GLOBAL_PROPERTY(bool, showHoverIndicator, true)

public:
    explicit SidebarConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace caelestia::config
