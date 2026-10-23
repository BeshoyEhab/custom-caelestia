.pragma library

// Pure colour-pairing math for the desktop clock. Keep this file free of QML
// types so it can be unit-tested with node (tests/clock_colours_test.js).
//
// Colours may be QML color objects (0..1 channels) or #rrggbb strings. Alpha is
// ignored: the clock face, badges and plate are opaque, so the visible contrast
// is the RGB one.

function toRgb(color) {
    if (typeof color === "string") {
        let s = color.trim().toLowerCase();
        if (s.charAt(0) === "#")
            s = s.slice(1);
        if (s.length === 3)
            s = s.split("").map(c => c + c).join("");
        if (s.length === 8)
            s = s.slice(2);
        const n = parseInt(s, 16);
        return {
            r: ((n >> 16) & 0xff) / 255,
            g: ((n >> 8) & 0xff) / 255,
            b: (n & 0xff) / 255
        };
    }
    return { r: color.r, g: color.g, b: color.b };
}

function channel(value) {
    return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
}

function luminance(color) {
    const c = toRgb(color);
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

// WCAG 2 contrast ratio, 1:1 – 21:1.
function contrast(a, b) {
    const la = luminance(a);
    const lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

function colorKey(color) {
    const c = toRgb(color);
    return [c.r, c.g, c.b].map(v => Math.round(v * 255)).join(",");
}

// Pick a badge pair (background + matching foreground) that reads against the
// clock face. Candidates are ordered by preference; each is
// `{ background, foreground }`. A pair is accepted when it clears `minBackground`
// against the face and its own `minForeground` for the text. Backgrounds already
// used by another badge are skipped first, so two badges do not collapse into
// the same colour, and a pair is reused only when nothing else qualifies.
// When no candidate is legible at all, invert the face pair: on-face background
// with face-coloured text is always readable by construction.
function pickBadge(face, onFace, candidates, usedBackgrounds, minBackground, minForeground) {
    const minBg = minBackground === undefined ? 3 : minBackground;
    const minFg = minForeground === undefined ? 4.5 : minForeground;
    const used = (usedBackgrounds || []).map(colorKey);
    const list = candidates || [];

    const againstFace = c => contrast(face, c.background) >= minBg;
    const readable = c => contrast(c.background, c.foreground) >= minFg;

    for (const c of list) {
        if (used.indexOf(colorKey(c.background)) !== -1)
            continue;
        if (againstFace(c) && readable(c))
            return c;
    }
    for (const c of list) {
        if (againstFace(c) && readable(c))
            return c;
    }
    // No pair both separates from the face and keeps its text legible: invert
    // the face pair. A chip that blends into the face (the original bug) is not
    // an acceptable fallback.
    return { background: onFace, foreground: face };
}
