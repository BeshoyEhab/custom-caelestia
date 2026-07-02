#pragma once

#include "configobject.hpp"

namespace caelestia::config {

class Positioning : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, edge, 2)
    CONFIG_PROPERTY(qreal, offset, 0.5)
    CONFIG_PROPERTY(int, x, 0)
    CONFIG_PROPERTY(int, y, 0)
    CONFIG_PROPERTY(bool, pixel, false)

public:
    enum Edge { Left = 0, Right = 1, Top = 2, Bottom = 3 };
    Q_ENUM(Edge)

    explicit Positioning(QObject* parent = nullptr)
        : ConfigObject(parent) {}

    Q_INVOKABLE qreal computeX(qreal screenWidth, qreal panelWidth) const {
        if (m_pixel)
            return m_x;
        switch (m_edge) {
        case Left:
            return 0;
        case Right:
            return screenWidth - panelWidth;
        case Top:
        case Bottom:
            return (screenWidth - panelWidth) * m_offset;
        default:
            return 0;
        }
    }

    Q_INVOKABLE qreal computeY(qreal screenHeight, qreal panelHeight) const {
        if (m_pixel)
            return m_y;
        switch (m_edge) {
        case Top:
            return 0;
        case Bottom:
            return screenHeight - panelHeight;
        case Left:
        case Right:
            return (screenHeight - panelHeight) * m_offset;
        default:
            return 0;
        }
    }

    Q_INVOKABLE bool isHorizontal() const {
        return m_edge == Left || m_edge == Right;
    }

    Q_INVOKABLE bool isVertical() const {
        return m_edge == Top || m_edge == Bottom;
    }
};

} // namespace caelestia::config
