.pragma library

// Pure widget registry. Keep this file free of QML types so it can be
// unit-tested with node (tests/widget_registry_test.js).
//
// The ids below are the contract consumed by the dock, the widget catalog and
// the popover/focus rules. Metadata fields that are inert in the current plan
// (`role`, `ownsPopover`, `wantsFocus`, `minSize`) still ship here so later
// plans do not have to change the shape of a registry entry.

var MAX_DEPTH = 4;

var REGIONS = {
    start: ["logo", "workspaces"],
    center: ["activeWindow"],
    end: ["tray", "clock", "statusIcons", "power"]
};

var WIDGETS = [
    {
        id: "logo",
        name: "Logo",
        description: "Launcher button",
        icon: "apps",
        category: "widget",
        role: null,
        singleton: true,
        defaultOptions: {},
        allowHelpers: false,
        compositeOf: [],
        wantsFocus: false,
        ownsPopover: false,
        minSize: { width: 0, height: 0 }
    },
    {
        id: "workspaces",
        name: "Workspaces",
        description: "Workspace switcher",
        icon: "workspaces",
        category: "widget",
        role: null,
        singleton: true,
        defaultOptions: {},
        allowHelpers: false,
        compositeOf: [],
        wantsFocus: false,
        ownsPopover: true,
        minSize: { width: 0, height: 0 }
    },
    {
        id: "activeWindow",
        name: "Active window",
        description: "Title of the focused window",
        icon: "web_asset",
        category: "widget",
        role: null,
        singleton: true,
        defaultOptions: { fillWidth: true },
        allowHelpers: false,
        compositeOf: [],
        wantsFocus: false,
        ownsPopover: true,
        minSize: { width: 0, height: 0 }
    },
    {
        id: "tray",
        name: "System tray",
        description: "Tray icons and their menus",
        icon: "notifications",
        category: "widget",
        role: null,
        singleton: true,
        defaultOptions: {},
        allowHelpers: false,
        compositeOf: [],
        wantsFocus: false,
        ownsPopover: true,
        minSize: { width: 0, height: 0 }
    },
    {
        id: "clock",
        name: "Clock",
        description: "Time and date",
        icon: "schedule",
        category: "widget",
        role: null,
        singleton: true,
        defaultOptions: {},
        allowHelpers: false,
        compositeOf: [],
        wantsFocus: false,
        ownsPopover: false,
        minSize: { width: 0, height: 0 }
    },
    {
        id: "statusIcons",
        name: "Status icons",
        description: "Battery, network, audio and other indicators",
        icon: "battery_android_full",
        category: "widget",
        role: null,
        singleton: true,
        defaultOptions: {},
        allowHelpers: false,
        compositeOf: ["battery", "network", "audio", "bluetooth", "kbLayout", "lockStatus", "microphone"],
        wantsFocus: false,
        ownsPopover: true,
        minSize: { width: 0, height: 0 }
    },
    {
        id: "power",
        name: "Power",
        description: "Session actions",
        icon: "power_settings_new",
        category: "widget",
        role: null,
        singleton: true,
        defaultOptions: {},
        allowHelpers: false,
        compositeOf: [],
        wantsFocus: false,
        ownsPopover: true,
        minSize: { width: 0, height: 0 }
    },
    {
        id: "spacer",
        name: "Spacer",
        description: "Empty space between widgets",
        icon: "space_dashboard",
        category: "helper",
        role: "structure",
        singleton: false,
        defaultOptions: { size: 0 },
        allowHelpers: false,
        compositeOf: [],
        wantsFocus: false,
        ownsPopover: false,
        minSize: { width: 0, height: 0 }
    },
    {
        id: "separator",
        name: "Separator",
        description: "Divider between widgets",
        icon: "horizontal_rule",
        category: "helper",
        role: "decoration",
        singleton: false,
        defaultOptions: {},
        allowHelpers: false,
        compositeOf: [],
        wantsFocus: false,
        ownsPopover: false,
        minSize: { width: 0, height: 0 }
    },
    {
        id: "group",
        name: "Group",
        description: "Container for other widgets",
        icon: "folder",
        category: "helper",
        role: "structure",
        singleton: false,
        defaultOptions: {},
        allowHelpers: true,
        compositeOf: [],
        wantsFocus: false,
        ownsPopover: false,
        minSize: { width: 0, height: 0 }
    }
];

function registry() {
    return WIDGETS;
}

function get(type) {
    for (var i = 0; i < WIDGETS.length; i++) {
        if (WIDGETS[i].id === type)
            return WIDGETS[i];
    }
    return null;
}

function nextInstanceId(type, items) {
    var used = {};
    for (var i = 0; i < (items || []).length; i++)
        used[items[i].instance] = true;
    if (!used[type])
        return type;
    var n = 2;
    while (used[type + "-" + n])
        n++;
    return type + "-" + n;
}

function normalizeItem(raw) {
    var source = raw || {};
    var meta = get(source.type);
    var options = Object.assign({}, meta ? meta.defaultOptions : {}, source.options || {});
    var children = [];
    var rawChildren = source.children || [];
    for (var i = 0; i < rawChildren.length; i++)
        children.push(normalizeItem(rawChildren[i]));
    return {
        type: source.type,
        instance: source.instance || nextInstanceId(source.type, []),
        enabled: source.enabled === undefined ? true : source.enabled,
        options: options,
        children: children
    };
}

// Validate one sibling list. Uniqueness is scoped to the list: nested groups
// may reuse type names without colliding with their parent.
function validateList(rawItems, depth, path, errors) {
    var out = [];
    var seenInstances = {};
    var seenEnabledTypes = {};

    for (var i = 0; i < rawItems.length; i++) {
        var itemPath = path + "[" + i + "]";
        var item = validateItem(rawItems[i], depth, itemPath, errors, seenInstances, seenEnabledTypes);
        if (item)
            out.push(item);
    }
    return out;
}

function validateItem(raw, depth, path, errors, seenInstances, seenEnabledTypes) {
    if (depth > MAX_DEPTH) {
        errors.push('widget nesting exceeds maximum depth of ' + MAX_DEPTH + ' at "' + path + '"');
        return null;
    }

    var source = raw || {};
    var meta = get(source.type);
    if (!meta) {
        errors.push('unknown widget "' + source.type + '" at "' + path + '"');
        return null;
    }

    var item = normalizeItem(source);
    if (item.enabled && meta.singleton && seenEnabledTypes[item.type]) {
        errors.push('duplicate singleton "' + item.type + '" at "' + path + '"');
        return null;
    }
    if (seenInstances[item.instance]) {
        errors.push('duplicate instance "' + item.instance + '" at "' + path + '"');
        return null;
    }

    item.children = [];
    if (source.children && source.children.length) {
        if (!meta.allowHelpers) {
            errors.push('widget "' + item.type + '" does not accept children at "' + path + '"');
        } else {
            item.children = validateList(source.children, depth + 1, path + ".children", errors);
        }
    }

    seenInstances[item.instance] = true;
    if (item.enabled && meta.singleton)
        seenEnabledTypes[item.type] = true;
    return item;
}

function validateItems(items, opts) {
    var errors = [];
    var list = items || [];
    var validated = validateList(list, 0, "items", errors);
    return {
        ok: errors.length === 0,
        errors: errors,
        items: validated
    };
}

function visibleItems(items) {
    return validateItems(items).items.filter(function (item) {
        return item.enabled;
    });
}

function fromBarEntries(entries, region) {
    var allowed = REGIONS[region] || [];
    var items = [];
    var list = entries || [];

    for (var i = 0; i < list.length; i++) {
        var entry = list[i] || {};
        if (!get(entry.id) || allowed.indexOf(entry.id) === -1)
            continue;
        items.push(normalizeItem({
            type: entry.id,
            instance: nextInstanceId(entry.id, items),
            enabled: entry.enabled,
            options: entry.options
        }));
    }
    return items;
}
