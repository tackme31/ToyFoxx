#include "DisplayKeepAwake.h"

#include <qt_windows.h>

DisplayKeepAwake::~DisplayKeepAwake()
{
    if (m_active)
        SetThreadExecutionState(ES_CONTINUOUS);
}

void DisplayKeepAwake::setActive(bool active)
{
    if (m_active == active)
        return;
    m_active = active;
    // ES_CONTINUOUS alone clears the requirement again.
    SetThreadExecutionState(active ? ES_CONTINUOUS | ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED
                                   : ES_CONTINUOUS);
    emit activeChanged();
}
