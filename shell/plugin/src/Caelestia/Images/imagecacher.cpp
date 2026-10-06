#include "imagecacher.hpp"

#include <qcryptographichash.h>
#include <qdir.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qhash.h>
#include <qimage.h>
#include <qloggingcategory.h>
#include <qmutex.h>
#include <qpainter.h>
#include <qsavefile.h>
#include <qthreadpool.h>
#include <algorithm>

Q_LOGGING_CATEGORY(lcCacher, "caelestia.images.cacher", QtInfoMsg)

namespace caelestia::images {

namespace {

QString sha256sum(const QString& path) {
    // Keyed by path + mtime + size so edited files don't serve stale hashes.
    // Guarded: called from both the UI thread and QThreadPool workers.
    static QHash<QString, QString> s_cache;
    static QMutex s_mutex;

    const QFileInfo info(path);
    const QString key = path + u'|' + QString::number(info.lastModified().toMSecsSinceEpoch()) + u'|'
        + QString::number(info.size());
    {
        const QMutexLocker locker(&s_mutex);
        if (const auto it = s_cache.constFind(key); it != s_cache.constEnd())
            return *it;
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        qCWarning(lcCacher).noquote() << "sha256sum: failed to open" << path;
        return {};
    }

    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(&file);
    file.close();

    const QString result = hash.result().toHex();
    const QMutexLocker locker(&s_mutex);
    s_cache.insert(key, result);
    return result;
}

QString fillSuffix(ImageCacher::FillMode fillMode) {
    switch (fillMode) {
    case ImageCacher::FillMode::Crop:
        return QStringLiteral("crop");
    case ImageCacher::FillMode::Fit:
        return QStringLiteral("fit");
    default:
        return QStringLiteral("stretch");
    }
}

} // namespace

namespace {

// Newest entries are kept; the rest go once either cap is exceeded.
constexpr int kMaxFiles = 200;
constexpr qint64 kMaxBytes = 256LL * 1024 * 1024;

} // namespace

const QString& ImageCacher::cacheDir() {
    static const QString s_dir = [] {
        QString cache = qEnvironmentVariable("XDG_CACHE_HOME");
        if (cache.isEmpty())
            cache = QDir::homePath() + QStringLiteral("/.cache");
        return cache + QStringLiteral("/caelestia/imagecache");
    }();
    return s_dir;
}

QString ImageCacher::cachePathFor(const QString& sourcePath, const QSize& size, FillMode fillMode) {
    const QString sha = sha256sum(sourcePath);
    if (sha.isEmpty())
        return {};

    const QString filename =
        QStringLiteral("%1@%2x%3-%4.png")
            .arg(sha, QString::number(size.width()), QString::number(size.height()), fillSuffix(fillMode));

    return cacheDir() + QLatin1Char('/') + filename;
}

ImageCacher* ImageCacher::instance() {
    static ImageCacher s_instance;
    return &s_instance;
}

ImageCacher::ImageCacher(QObject* parent)
    : QObject(parent) {
    prune();
}

void ImageCacher::prune() {
    QDir dir(cacheDir());
    if (!dir.exists())
        return;

    QFileInfoList files = dir.entryInfoList(QDir::Files | QDir::NoDotAndDotDot, QDir::NoSort);
    std::sort(files.begin(), files.end(), [](const QFileInfo& a, const QFileInfo& b) {
        return a.lastModified() > b.lastModified(); // newest first
    });

    qint64 totalBytes = 0;
    for (const QFileInfo& fi : std::as_const(files))
        totalBytes += fi.size();

    int removed = 0;
    for (int i = 0; i < files.size(); ++i) {
        if (i < kMaxFiles && totalBytes <= kMaxBytes)
            continue;
        if (QFile::remove(files[i].absoluteFilePath())) {
            totalBytes -= files[i].size();
            ++removed;
        }
    }

    if (removed > 0)
        qCInfo(lcCacher).noquote() << "prune: removed" << removed << "stale entries";
}

void ImageCacher::schedule(const QString& sourcePath, const QSize& size, FillMode fillMode) {
    schedule(sourcePath, cachePathFor(sourcePath, size, fillMode), size, fillMode);
}

void ImageCacher::schedule(const QString& sourcePath, const QString& cachePath, const QSize& size, FillMode fillMode) {
    if (cachePath.isEmpty())
        return;

    {
        QMutexLocker locker(&m_mutex);
        if (m_inflight.contains(cachePath))
            return;
        m_inflight.insert(cachePath);
    }

    QThreadPool::globalInstance()->start([this, sourcePath, cachePath, size, fillMode]() {
        runJob(sourcePath, cachePath, size, fillMode);
        QMutexLocker locker(&m_mutex);
        m_inflight.remove(cachePath);
    });
}

void ImageCacher::runJob(const QString& sourcePath, const QString& cachePath, const QSize& size, FillMode fillMode) {
    if (QFile::exists(cachePath)) {
        return;
    }

    QImage image(sourcePath);
    if (image.isNull()) {
        qCWarning(lcCacher).noquote() << "Failed to decode source" << sourcePath;
        return;
    }

    Qt::AspectRatioMode scaleMode = Qt::IgnoreAspectRatio;
    switch (fillMode) {
    case FillMode::Crop:
        scaleMode = Qt::KeepAspectRatioByExpanding;
        break;
    case FillMode::Fit:
        scaleMode = Qt::KeepAspectRatio;
        break;
    case FillMode::Stretch:
    default:
        scaleMode = Qt::IgnoreAspectRatio;
        break;
    }

    image.convertTo(QImage::Format_ARGB32);
    image = image.scaled(size, scaleMode, Qt::SmoothTransformation);

    if (image.isNull()) {
        qCWarning(lcCacher).noquote() << "Failed to scale" << sourcePath;
        return;
    }

    QImage canvas;
    if (fillMode == FillMode::Stretch) {
        canvas = image;
    } else {
        canvas = QImage(size, QImage::Format_ARGB32);
        canvas.fill(Qt::transparent);

        QPainter painter(&canvas);
        painter.drawImage((size.width() - image.width()) / 2, (size.height() - image.height()) / 2, image);
        painter.end();
    }

    const QString parent = QFileInfo(cachePath).absolutePath();
    if (!QDir().mkpath(parent)) {
        qCWarning(lcCacher).noquote() << "Failed to create cache dir" << parent;
        return;
    }

    QSaveFile saveFile(cachePath);
    if (!saveFile.open(QIODevice::WriteOnly) || !canvas.save(&saveFile, "PNG") || !saveFile.commit()) {
        qCWarning(
            lcCacher, "Failed to save to %s: %s", qUtf8Printable(cachePath), qUtf8Printable(saveFile.errorString()));
        return;
    }

    qCDebug(lcCacher).noquote() << "Saved to" << cachePath;
}

} // namespace caelestia::images
