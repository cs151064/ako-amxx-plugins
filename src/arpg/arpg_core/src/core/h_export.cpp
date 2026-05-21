#include "extdll.h"
#include "h_export.h"

enginefuncs_t g_engfuncs;
globalvars_t *gpGlobals = nullptr;

void WINAPI GiveFnptrsToDll(enginefuncs_t *engine_functions, globalvars_t *globals)
{
    memcpy(&g_engfuncs, engine_functions, sizeof(enginefuncs_t));
    gpGlobals = globals;
}
