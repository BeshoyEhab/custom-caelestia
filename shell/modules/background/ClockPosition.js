.pragma library

// Pure clock placement math. Keep this file free of QML types so it can be
// unit-tested with node (tests/clock_position_test.js).
//
// All values are in the same coordinate space: the desktop clock's parent
// (the background window). `w`/`h` are the clock's implicit size; insets are
// the bar/border-aware gaps the clock must keep from each screen edge.

function insetsOrZero(insets) {
    return insets || { left: 0, right: 0, top: 0, bottom: 0 };
}

function isAuto(position) {
    return position === "auto-empty" || position === "auto-full";
}

function preset(position, screenW, screenH, w, h, insets) {
    const gap = insetsOrZero(insets);
    const parts = String(position || "").split("-");
    const row = parts[0];
    const col = parts[1];

    const minX = gap.left;
    const maxX = screenW - gap.right - w;
    const minY = gap.top;
    const maxY = screenH - gap.bottom - h;

    let x;
    if (col === "left")
        x = minX;
    else if (col === "right")
        x = maxX;
    else
        x = (screenW - w) / 2;

    let y;
    if (row === "top")
        y = minY;
    else if (row === "bottom")
        y = maxY;
    else
        y = (screenH - h) / 2;

    return { x: x, y: y };
}

function fromCenter(cx, cy, screenW, screenH, w, h, insets) {
    const gap = insetsOrZero(insets);
    const minX = gap.left;
    const maxX = screenW - gap.right - w;
    const minY = gap.top;
    const maxY = screenH - gap.bottom - h;

    return {
        x: Math.min(Math.max(cx - w / 2, minX), maxX),
        y: Math.min(Math.max(cy - h / 2, minY), maxY)
    };
}

function clampOffset(dx, dy, baseX, baseY, w, h, screenW, screenH, insets) {
    const gap = insetsOrZero(insets);
    const minX = gap.left;
    const maxX = screenW - gap.right - w;
    const minY = gap.top;
    const maxY = screenH - gap.bottom - h;

    const clampedX = Math.min(Math.max(baseX + dx, minX), maxX);
    const clampedY = Math.min(Math.max(baseY + dy, minY), maxY);

    return { dx: clampedX - baseX, dy: clampedY - baseY };
}
