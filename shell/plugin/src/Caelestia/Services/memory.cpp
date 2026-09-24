#include "memory.hpp"

#include <cstdio>
#include <qfile.h>

namespace caelestia::services {

Memory::Memory(QObject* parent)
    : TickingService(parent) {}

qreal Memory::used() const {
    return m_used;
}

qreal Memory::total() const {
    return m_total;
}

qreal Memory::percentage() const {
    return m_total > 0.0 ? m_used / m_total : 0.0;
}

void Memory::tick() {
    QFile f(QStringLiteral("/proc/meminfo"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }

    unsigned long long totalKibRaw = 0;
    unsigned long long availKibRaw = 0;
    bool haveTotal = false;
    bool haveAvail = false;
    // NOTE: QFile::atEnd() is always true for procfs/sysfs (kernel reports
    // size 0), so loop on readLine() returning empty at EOF instead.
    for (;;) {
        const QByteArray line = f.readLine();
        if (line.isEmpty()) {
            break;
        }
        if (!haveTotal && line.startsWith("MemTotal:")) {
            haveTotal = std::sscanf(line.constData(), "MemTotal: %llu", &totalKibRaw) == 1;
        } else if (!haveAvail && line.startsWith("MemAvailable:")) {
            haveAvail = std::sscanf(line.constData(), "MemAvailable: %llu", &availKibRaw) == 1;
        }
        if (haveTotal && haveAvail) {
            break;
        }
    }
    f.close();

    if (!haveTotal || !haveAvail) {
        return;
    }

    const quint64 totalKib = static_cast<quint64>(totalKibRaw);
    const quint64 availKib = static_cast<quint64>(availKibRaw);
    if (totalKib == 0) {
        return;
    }
    const quint64 usedKib = totalKib > availKib ? totalKib - availKib : 0;

    if (totalKib == m_lastTotal && usedKib == m_lastUsed) {
        return;
    }
    m_lastTotal = totalKib;
    m_lastUsed = usedKib;
    m_total = static_cast<qreal>(totalKib);
    m_used = static_cast<qreal>(usedKib);
    Q_EMIT changed();
}

} // namespace caelestia::services
