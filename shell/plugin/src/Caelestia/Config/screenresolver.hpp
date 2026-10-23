#pragma once

#include <qobject.h>
#include <qqml.h>
#include <qquickitem.h>
#include <qquickwindow.h>
#include <qscreen.h>

namespace caelestia::config {

/**
 * Resolve the screen for an attached Config/Tokens object.
 *
 * Attached objects are often parented to raw QObjects (Behavior, Connections),
 * not to the annotated QQuickItem. Walk the QObject chain instead of looking
 * only at the direct parent. Prefer the nearest item's attached screen, which
 * preserves an explicit `contentItem.Config.screen: screen.name` handoff, then
 * fall back to the item's window screen.
 */
template <typename Attached>
QString screenNameForObject(const QObject* object) {
    QString windowScreen;

    for (const QObject* current = object; current; current = current->parent()) {
        if (const auto* item = qobject_cast<const QQuickItem*>(current)) {
            // An explicit Config.screen on any ancestor wins, even when the
            // raw object is parented below that ancestor's window.
            if (const auto* attached =
                    qobject_cast<const Attached*>(qmlAttachedPropertiesObject<Attached>(item, false))) {
                if (!attached->screen().isEmpty())
                    return attached->screen();
            }
            if (windowScreen.isEmpty()) {
                if (const auto* window = item->window()) {
                    if (const auto* screen = window->screen())
                        windowScreen = screen->name();
                }
            }
        }
        if (const auto* window = qobject_cast<const QQuickWindow*>(current)) {
            if (windowScreen.isEmpty()) {
                if (const auto* screen = window->screen())
                    windowScreen = screen->name();
            }
        }
    }
    return windowScreen;
}

} // namespace caelestia::config
