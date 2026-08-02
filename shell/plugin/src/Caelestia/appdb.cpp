#include "appdb.hpp"

#include <qloggingcategory.h>
#include <qsqldatabase.h>
#include <qsqlquery.h>
#include <quuid.h>

Q_LOGGING_CATEGORY(lcAppDb, "caelestia.appdb", QtInfoMsg)

namespace caelestia {

AppEntry::AppEntry(QObject* entry, unsigned int frequency, QObject* parent)
    : QObject(parent)
    , m_entry(entry)
    , m_frequency(frequency) {
    const auto mo = m_entry->metaObject();
    const auto tmo = &AppEntry::staticMetaObject;

    for (const auto& prop :
        { "name", "comment", "execString", "startupClass", "genericName", "categories", "keywords" }) {
        const auto metaProp = mo->property(mo->indexOfProperty(prop));
        const auto thisMetaProp = tmo->property(tmo->indexOfProperty(prop));
        QObject::connect(m_entry, metaProp.notifySignal(), this, thisMetaProp.notifySignal());
    }

    QObject::connect(m_entry, &QObject::destroyed, this, [this]() {
        m_entry = nullptr;
        deleteLater();
    });
}

QObject* AppEntry::entry() const {
    return m_entry;
}

quint32 AppEntry::frequency() const {
    return m_frequency;
}

void AppEntry::setFrequency(unsigned int frequency) {
    if (m_frequency != frequency) {
        m_frequency = frequency;
        emit frequencyChanged();
    }
}

void AppEntry::incrementFrequency() {
    m_frequency++;
    emit frequencyChanged();
}

QString AppEntry::id() const {
    if (!m_entry) {
        return "";
    }
    return m_entry->property("id").toString();
}

QString AppEntry::name() const {
    if (!m_entry) {
        return "";
    }
    return m_entry->property("name").toString();
}

QString AppEntry::comment() const {
    if (!m_entry) {
        return "";
    }
    return m_entry->property("comment").toString();
}

QString AppEntry::execString() const {
    if (!m_entry) {
        return "";
    }
    return m_entry->property("execString").toString();
}

QString AppEntry::startupClass() const {
    if (!m_entry) {
        return "";
    }
    return m_entry->property("startupClass").toString();
}

QString AppEntry::genericName() const {
    if (!m_entry) {
        return "";
    }
    return m_entry->property("genericName").toString();
}

QString AppEntry::categories() const {
    if (!m_entry) {
        return "";
    }
    return m_entry->property("categories").toStringList().join(" ");
}

QString AppEntry::keywords() const {
    if (!m_entry) {
        return "";
    }
    return m_entry->property("keywords").toStringList().join(" ");
}

AppDb::AppDb(QObject* parent)
    : QObject(parent)
    , m_timer(new QTimer(this))
    , m_uuid(QUuid::createUuid().toString()) {
    m_timer->setSingleShot(true);
    m_timer->setInterval(300);
    QObject::connect(m_timer, &QTimer::timeout, this, &AppDb::updateApps);

    auto db = QSqlDatabase::addDatabase("QSQLITE", m_uuid);
    db.setDatabaseName(":memory:");
    db.open();

    QSqlQuery query(db);
    query.exec("CREATE TABLE IF NOT EXISTS frequencies (id TEXT PRIMARY KEY, frequency INTEGER)");
    query.exec("CREATE TABLE IF NOT EXISTS query_aliases (query TEXT NOT NULL, id TEXT NOT NULL, count INTEGER NOT NULL DEFAULT 1, PRIMARY KEY(query, id))");
}

QString AppDb::uuid() const {
    return m_uuid;
}

QString AppDb::path() const {
    return m_path;
}

void AppDb::setPath(const QString& path) {
    auto newPath = path.isEmpty() ? ":memory:" : path;

    if (m_path == newPath) {
        return;
    }

    m_path = newPath;
    emit pathChanged();

    auto db = QSqlDatabase::database(m_uuid, false);
    db.close();
    db.setDatabaseName(newPath);
    db.open();

    QSqlQuery query(db);
    query.exec("CREATE TABLE IF NOT EXISTS frequencies (id TEXT PRIMARY KEY, frequency INTEGER)");
    query.exec("CREATE TABLE IF NOT EXISTS query_aliases (query TEXT NOT NULL, id TEXT NOT NULL, count INTEGER NOT NULL DEFAULT 1, PRIMARY KEY(query, id))");

    updateAppFrequencies();
}

QObjectList AppDb::entries() const {
    return m_entries;
}

void AppDb::setEntries(const QObjectList& entries) {
    if (m_entries == entries) {
        return;
    }

    m_entries = entries;
    emit entriesChanged();

    m_timer->start();
}

QStringList AppDb::favouriteApps() const {
    return m_favouriteApps;
}

void AppDb::setFavouriteApps(const QStringList& favApps) {
    if (m_favouriteApps == favApps) {
        return;
    }

    m_favouriteApps = favApps;
    emit favouriteAppsChanged();
    m_favouriteAppsRegex.clear();
    m_favouriteAppsRegex.reserve(m_favouriteApps.size());
    for (const QString& item : std::as_const(m_favouriteApps)) {
        const QRegularExpression re(regexifyString(item));
        if (re.isValid()) {
            m_favouriteAppsRegex << re;
        } else {
            qCWarning(lcAppDb) << "setFavouriteApps: regular expression is not valid:" << re.pattern();
        }
    }

    emit appsChanged();
}

QString AppDb::regexifyString(const QString& original) const {
    if (original.startsWith('^') && original.endsWith('$'))
        return original;

    const QString escaped = QRegularExpression::escape(original);
    return QStringLiteral("^%1$").arg(escaped);
}

QQmlListProperty<AppEntry> AppDb::apps() {
    return QQmlListProperty<AppEntry>(this, &getSortedApps());
}

void AppDb::incrementFrequency(const QString& id) {
    auto db = QSqlDatabase::database(m_uuid);
    QSqlQuery query(db);

    query.prepare("INSERT INTO frequencies (id, frequency) "
                  "VALUES (:id, 1) "
                  "ON CONFLICT (id) DO UPDATE SET frequency = frequency + 1");
    query.bindValue(":id", id);
    query.exec();

    auto* app = m_apps.value(id);
    if (app) {
        const auto before = getSortedApps();
        app->incrementFrequency();
        getSortedApps();
        if (before != m_sortedApps) {
            emit appsChanged();
        }
    } else {
        qCWarning(lcAppDb) << "incrementFrequency: could not find app with id" << id;
    }
}

void AppDb::learnQuery(const QString& query, const QString& id) {
    const QString q = query.trimmed().toLower();
    if (q.isEmpty() || id.isEmpty())
        return;

    auto db = QSqlDatabase::database(m_uuid);
    QSqlQuery qr(db);
    qr.prepare("INSERT INTO query_aliases (query, id, count) "
               "VALUES (:query, :id, 1) "
               "ON CONFLICT (query, id) DO UPDATE SET count = count + 1");
    qr.bindValue(":query", q);
    qr.bindValue(":id", id);
    qr.exec();
}

QVariantMap AppDb::queryAliases(const QString& query) {
    QVariantMap out;
    const QString q = query.trimmed().toLower();
    if (q.isEmpty())
        return out;

    auto db = QSqlDatabase::database(m_uuid);
    QHash<QString, double> acc;

    const auto add = [&acc](const QString& id, int count, double factor) {
        if (count <= 0)
            return;
        acc[id] += count * factor;
    };

    // 1. Exact query -> the user typed this exact (or near) thing for this app.
    {
        QSqlQuery qr(db);
        qr.setForwardOnly(true);
        qr.prepare("SELECT id, count FROM query_aliases WHERE query = :q");
        qr.bindValue(":q", q);
        if (qr.exec()) {
            while (qr.next())
                add(qr.value(0).toString(), qr.value(1).toInt(), 1.0);
        }
    }

    // 2. The user's query is a substring of a remembered query (typo/variation).
    {
        QSqlQuery qr(db);
        qr.setForwardOnly(true);
        qr.prepare("SELECT id, count FROM query_aliases WHERE instr(query, :q) > 0");
        qr.bindValue(":q", q);
        if (qr.exec()) {
            while (qr.next())
                add(qr.value(0).toString(), qr.value(1).toInt(), 0.6);
        }
    }

    // 3. A remembered query is a substring of the user query (expansion as a prefix).
    {
        QSqlQuery qr(db);
        qr.setForwardOnly(true);
        qr.prepare("SELECT id, count FROM query_aliases WHERE instr(:q, query) > 0");
        qr.bindValue(":q", q);
        if (qr.exec()) {
            while (qr.next())
                add(qr.value(0).toString(), qr.value(1).toInt(), 0.6);
        }
    }

    double maxScore = 0;
    for (auto it = acc.constBegin(); it != acc.constEnd(); ++it) {
        if (it.value() > maxScore)
            maxScore = it.value();
    }
    if (maxScore <= 0)
        return out;

    for (auto it = acc.constBegin(); it != acc.constEnd(); ++it)
        out.insert(it.key(), it.value() / maxScore);

    return out;
}

QList<AppEntry*>& AppDb::getSortedApps() const {
    m_sortedApps = m_apps.values();

    // Pre-compute favourite status to avoid repeated regex matching during sort
    QSet<QString> favSet;
    favSet.reserve(m_sortedApps.size());
    for (const auto* app : std::as_const(m_sortedApps)) {
        if (isFavourite(app))
            favSet.insert(app->id());
    }

    std::sort(m_sortedApps.begin(), m_sortedApps.end(), [&favSet](AppEntry* a, AppEntry* b) {
        const bool aIsFav = favSet.contains(a->id());
        const bool bIsFav = favSet.contains(b->id());
        if (aIsFav != bIsFav)
            return aIsFav;
        if (a->frequency() != b->frequency())
            return a->frequency() > b->frequency();
        return a->name().localeAwareCompare(b->name()) < 0;
    });
    return m_sortedApps;
}

bool AppDb::isFavourite(const AppEntry* app) const {
    for (const QRegularExpression& re : m_favouriteAppsRegex) {
        if (re.match(app->id()).hasMatch()) {
            return true;
        }
    }
    return false;
}

quint32 AppDb::getFrequency(const QString& id) const {
    auto db = QSqlDatabase::database(m_uuid);
    QSqlQuery query(db);

    query.prepare("SELECT frequency FROM frequencies WHERE id = :id");
    query.bindValue(":id", id);

    if (query.exec() && query.next()) {
        return query.value(0).toUInt();
    }

    return 0;
}

void AppDb::updateAppFrequencies() {
    const auto before = getSortedApps();

    for (auto* app : std::as_const(m_apps)) {
        app->setFrequency(getFrequency(app->id()));
    }

    getSortedApps();
    if (before != m_sortedApps) {
        emit appsChanged();
    }
}

void AppDb::updateApps() {
    bool dirty = false;

    for (const auto& entry : std::as_const(m_entries)) {
        const auto id = entry->property("id").toString();
        if (!m_apps.contains(id)) {
            dirty = true;
            auto* const newEntry = new AppEntry(entry, getFrequency(id), this);
            QObject::connect(newEntry, &QObject::destroyed, this, [id, this]() {
                if (m_apps.remove(id)) {
                    emit appsChanged();
                }
            });
            m_apps.insert(id, newEntry);
        }
    }

    QSet<QString> newIds;
    for (const auto& entry : std::as_const(m_entries)) {
        newIds.insert(entry->property("id").toString());
    }

    for (auto it = m_apps.begin(); it != m_apps.end();) {
        if (!newIds.contains(it.key())) {
            dirty = true;
            it.value()->deleteLater();
            it = m_apps.erase(it);
        } else {
            ++it;
        }
    }

    if (dirty) {
        emit appsChanged();
    }
}

} // namespace caelestia
