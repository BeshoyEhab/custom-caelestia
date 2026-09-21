qml_module(caelestia-components
    URI Caelestia.Components
    SOURCES
        animatedrepeater.cpp
        lazylistview.cpp
        wavyline.cpp
        buttonrow.cpp
        circularindicatormanager.cpp
        linearindicatormanager.cpp
        visualiserbars.cpp
    LIBRARIES
        Qt::Quick
)

# Upstream-verbatim animatedrepeater.cpp trips -Wnull-dereference (GCC false
# positive inlined from Qt QHash::const_iterator::key()); silence only for it.
set_source_files_properties(animatedrepeater.cpp PROPERTIES COMPILE_OPTIONS -Wno-null-dereference)
# Pre-existing GCC false positive of the same kind in lazylistview.cpp:1081
# (guarded constBegin().key()); silence per-file, do not touch logic.
set_source_files_properties(lazylistview.cpp PROPERTIES COMPILE_OPTIONS -Wno-null-dereference)
