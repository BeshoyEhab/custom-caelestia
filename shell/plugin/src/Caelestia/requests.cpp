#include "requests.hpp"

#include <qjsvalueiterator.h>
#include <qloggingcategory.h>
#include <qnetworkaccessmanager.h>
#include <qnetworkcookiejar.h>
#include <qnetworkreply.h>
#include <qnetworkrequest.h>
#include <qregularexpression.h>

Q_LOGGING_CATEGORY(lcRequests, "caelestia.requests", QtInfoMsg)

namespace caelestia {

Requests::Requests(QObject* parent)
    : QObject(parent)
    , m_manager(new QNetworkAccessManager(this)) {}

void Requests::get(const QUrl& url, QJSValue onSuccess, QJSValue onError, QJSValue headers) const {
    if (!onSuccess.isCallable()) {
        qCWarning(lcRequests) << "get: onSuccess is not callable";
        return;
    }

    if (url.scheme() != QStringLiteral("https")) {
        const QString err = QStringLiteral("get: refusing non-https url with scheme '%1'").arg(url.scheme());
        qCWarning(lcRequests, "%s", qUtf8Printable(err));
        if (onError.isCallable())
            onError.call({ err });
        return;
    }

    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    request.setAttribute(QNetworkRequest::CookieSaveControlAttribute, QNetworkRequest::Manual);
    request.setAttribute(
        QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(10000);
    request.setRawHeader("Cache-Control", "no-cache, no-store");
    request.setRawHeader("Pragma", "no-cache");

    static const QRegularExpression headerNameRe(QStringLiteral("^[A-Za-z0-9-]+$"));
    if (headers.isObject()) {
        QJSValueIterator it(headers);
        while (it.hasNext()) {
            it.next();
            if (!headerNameRe.match(it.name()).hasMatch()) {
                qCWarning(lcRequests) << "get: refusing header with invalid name" << it.name();
                continue;
            }
            const QByteArray value = it.value().toString().toUtf8();
            if (value.contains('\r') || value.contains('\n')) {
                qCWarning(lcRequests) << "get: refusing header with CR/LF in value" << it.name();
                continue;
            }
            request.setRawHeader(it.name().toUtf8(), value);
        }
    }

    auto reply = m_manager->get(request);

    QObject::connect(reply, &QNetworkReply::finished, [reply, onSuccess, onError]() {
        if (reply->error() == QNetworkReply::NoError) {
            onSuccess.call({ QString(reply->readAll()) });
        } else if (onError.isCallable()) {
            onError.call({ reply->errorString() });
        } else {
            qCWarning(lcRequests) << "get: request failed with error" << reply->errorString();
        }

        reply->deleteLater();
    });
}

void Requests::resetCookies() const {
    m_manager->setCookieJar(new QNetworkCookieJar(m_manager));
}

} // namespace caelestia
