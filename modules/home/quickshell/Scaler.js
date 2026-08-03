.pragma library
function getScale(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (2160.0 / 3840.0);
    }
    if (mw <= 0 || mh <= 0) return 1.0;
    let rw = mw / 3840.0;
    let rh = mh / 2160.0;
    let r = Math.min(rw, rh);
    // Blend the exponent smoothly through r=1.0 instead of hard-switching
    // between 0.85 and 0.5. A hard switch matches in value at r=1 but not
    // in slope, which shows up as a visible kink in scale right at 4K.
    // Blending over a small window (0.85 <-> 1.15) removes that kink.
    let blendLo = 0.85, blendHi = 1.15;
    let t = Math.max(0, Math.min(1, (r - blendLo) / (blendHi - blendLo)));
    let smooth = t * t * (3 - 2 * t); // smoothstep
    let exponent = 0.85 + (0.5 - 0.85) * smooth;
    let baseScale = Math.max(0.35, Math.pow(r, exponent));
    return baseScale * (userScale !== undefined ? userScale : 1.0);
}
function s(val, scale) {
    return Math.round(val * scale);
}
function getLayout(name, mx, my, mw, mh, userScale) {
    let scale = getScale(mw, mh, userScale);
    let base = {
        // --- Top Right Popups ---
        "volume":    { w: s(650, scale), h: s(700, scale), rx: mw - s(455, scale), ry: s(60, scale), comp: "Audio.qml" },
        "network":   { w: s(900, scale), h: s(700, scale), rx: mw - s(904, scale), ry: s(60, scale), comp: "Network.qml" },
        "calendar":  { w: s(1450, scale), h: s(750, scale), rx: Math.floor((mw/2)-(s(1450, scale)/2)), ry: s(60, scale), comp: "Calendar.qml" },
        "settings":  { w: s(450, scale), h: mh - s(0, scale), rx: s(0, scale), ry: s(0, scale), comp: "Settings.qml" },
        "workspace": { w: s(430, scale), h: s(65, scale), rx: Math.floor((mw / 2) - (s(430, scale) / 2)), ry: s(30, scale), comp: "Workspace.qml" },
        // --- Central Standard Tools ---
        "applauncher": { w: s(800, scale), h: s(700, scale), rx: Math.floor((mw/2)-(s(800, scale)/2)), ry: Math.floor((mh/2)-(s(700, scale)/2)), comp: "applauncher/appLauncher.qml" },
        "clipboard": { w: s(800, scale), h: s(700, scale), rx: Math.floor((mw/2)-(s(800, scale)/2)), ry: Math.floor((mh/2)-(s(700, scale)/2)), comp: "clipboard/ClipboardManager.qml" },
        "wallpaper": { w: mw, h: s(650, scale), rx: 0, ry: Math.floor((mh/2)-(s(650, scale)/2)), comp: "WallpaperPicker.qml" },
        // --- Top Left Edge ---
        "music":     { w: s(640, scale), h: s(285, scale), rx: Math.floor((mw / 2) - (s(640, scale) / 2)), ry: s(70, scale), comp: "MusicPlayer.qml" },
        // --- Utility ---
        "hidden":    { w: 1, h: 1, rx: -5000 - mx, ry: -5000 - my, comp: "" }
    };
    if (!base[name]) return null;
    let t = base[name];
    t.x = mx + t.rx;
    t.y = my + t.ry;
    return t;
}
function getPopupLayout(mw, mh, userScale) {
    if (arguments.length === 2) {
        userScale = mh;
        mh = mw * (1080.0 / 1920.0);
    }
    let scale = getScale(mw, mh, userScale);
    return {
        w: s(350, scale),
        marginTop: s(60, scale),
        marginRight: s(20, scale),
        spacing: s(12, scale),
        radius: s(14, scale),
        padding: s(12, scale)
    };
}