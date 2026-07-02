# patch_qmldir.cmake — idempotently add Positioning singleton to qmldir
file(READ "${QMLDIR}" _content)
string(FIND "${_content}" "singleton Positioning" _pos)
if(_pos EQUAL -1)
    string(REPLACE "typeinfo" "singleton Positioning 254.0 positioning.hpp\ntypeinfo" _content "${_content}")
    file(WRITE "${QMLDIR}" "${_content}")
    message(STATUS "Patched qmldir: added Positioning singleton")
endif()
