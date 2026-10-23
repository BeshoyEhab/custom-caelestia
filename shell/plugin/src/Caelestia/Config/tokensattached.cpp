#include "tokensattached.hpp"
#include "anim.hpp"
#include "appearanceconfig.hpp"
#include "config.hpp"
#include "font.hpp"
#include "monitorconfigmanager.hpp"
#include "screenresolver.hpp"
#include "tokens.hpp"

namespace caelestia::config {

namespace {

const AppearanceConfig* resolveAppearance(GlobalConfig* config) {
    if (config)
        return config->appearance();
    return GlobalConfig::instance()->appearance();
}

} // namespace

Tokens::Tokens(QObject* parent)
    : QQuickAttachedPropertyPropagator(parent)
    , m_font(new FontTokens(this))
    , m_anim(new AnimTokens(this)) {
    bindAnim();
    bindFont();
    initialize();
}

void Tokens::classBegin() {}

void Tokens::componentComplete() {
    ensureScreen();
}

QString Tokens::screen() const {
    return m_screen;
}

void Tokens::inheritScreen(const QString& screen) {
    if (screen == m_screen)
        return;

    m_screen = screen;

    if (m_screen.isEmpty()) {
        m_config = nullptr;
        m_tokens = nullptr;
    } else {
        m_config = MonitorConfigManager::instance()->configForScreen(m_screen);
        m_tokens = MonitorConfigManager::instance()->tokensForScreen(m_screen);
    }

    bindFont();
    propagateScreen();
    emit sourceChanged();
}

void Tokens::ensureScreen() {
    if (!m_screen.isEmpty())
        return;

    const auto screen = screenNameForObject<Tokens>(parent());
    if (!screen.isEmpty())
        inheritScreen(screen);
}

void Tokens::propagateScreen() {
    const auto children = attachedChildren();
    for (auto* const child : children) {
        auto* const tokens = qobject_cast<Tokens*>(child);
        if (tokens)
            tokens->inheritScreen(m_screen);
    }
}

void Tokens::attachedParentChange(
    QQuickAttachedPropertyPropagator* newParent, QQuickAttachedPropertyPropagator* oldParent) {
    Q_UNUSED(oldParent);
    auto* const tokens = qobject_cast<Tokens*>(newParent);
    if (tokens)
        inheritScreen(tokens->screen());
    if (m_screen.isEmpty())
        ensureScreen();
}

void Tokens::bindAnim() {
    m_anim->bindDurations(GlobalConfig::instance()->appearance()->anim()->durations());
    m_anim->bindCurves(TokenConfig::instance()->appearance()->curves());
}

void Tokens::bindFont() {
    auto* appearance = m_config ? m_config->appearance() : GlobalConfig::instance()->appearance();
    m_font->bindFont(appearance->font());
}

#define TOKENS_ATTACHED_GETTER(Type, name)                                                                             \
    const Type* Tokens::name() const {                                                                                 \
        const_cast<Tokens*>(this)->ensureScreen();                                                                     \
        auto* a = resolveAppearance(m_config);                                                                         \
        return a ? a->name() : nullptr;                                                                                \
    }

TOKENS_ATTACHED_GETTER(AppearanceRounding, rounding)
TOKENS_ATTACHED_GETTER(AppearanceSpacing, spacing)
TOKENS_ATTACHED_GETTER(AppearancePadding, padding)

#undef TOKENS_ATTACHED_GETTER

const AppearanceTransparency* Tokens::transparency() const {
    return GlobalConfig::instance()->appearance()->transparency(); // Transparency is always global
}

const SizeTokens* Tokens::sizes() const {
    const_cast<Tokens*>(this)->ensureScreen();
    if (m_tokens)
        return m_tokens->sizes();
    return TokenConfig::instance()->sizes();
}

const FontTokens* Tokens::font() const {
    return m_font;
}

const AnimTokens* Tokens::anim() const {
    return m_anim;
}

TokenConfig* Tokens::forScreen(const QString& screen) {
    return TokenConfig::forScreen(screen);
}

Tokens* Tokens::qmlAttachedProperties(QObject* object) {
    auto* const tokens = new Tokens(object);
    tokens->ensureScreen();
    return tokens;
}

} // namespace caelestia::config
