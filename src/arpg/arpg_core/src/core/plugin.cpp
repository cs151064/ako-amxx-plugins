#include "arpg_core.h"

#include "extdll.h"
#include "meta_api.h"
#include "sdk_util.h"

#include <cstring>

extern enginefuncs_t g_engfuncs;
extern globalvars_t *gpGlobals;

meta_globals_t *gpMetaGlobals = nullptr;
gamedll_funcs_t *gpGamedllFuncs = nullptr;
mutil_funcs_t *gpMetaUtilFuncs = nullptr;

plugin_info_t Plugin_info = {
    META_INTERFACE_VERSION,
    "Ako ARPG Core",
    ARPG_CORE_VERSION_STRING,
    "20/05/2026",
    "Ako",
    "local-ako-arpg",
    "ARPGCORE",
    PT_CHANGELEVEL,
    PT_CHANGELEVEL,
};

namespace
{
cvar_t g_enabled_cvar = {"arpg_core_enabled", "1", FCVAR_EXTDLL, 0, nullptr};
cvar_t g_db_path_cvar = {"arpg_db_path", "addons/ako-rpg/arpg.sqlite", FCVAR_EXTDLL, 0, nullptr};
cvar_t g_force_t_cvar = {"arpg_force_t", "1", FCVAR_EXTDLL, 0, nullptr};
cvar_t g_respawn_delay_cvar = {"arpg_respawn_delay", "0.1", FCVAR_EXTDLL, 0, nullptr};
cvar_t g_hide_hud_cvar = {"arpg_hide_hud", "1", FCVAR_EXTDLL, 0, nullptr};
cvar_t *g_enabled = nullptr;
cvar_t *g_db_path = nullptr;

bool is_enabled()
{
    return !g_enabled || g_enabled->value != 0.0f;
}

const char *safe_cmd_arg(int index)
{
    const char *value = g_engfuncs.pfnCmd_Argv ? g_engfuncs.pfnCmd_Argv(index) : "";
    return value ? value : "";
}

bool strings_equal(const char *left, const char *right)
{
    return left && right && _stricmp(left, right) == 0;
}

void apply_server_cvars()
{
    if (!is_enabled())
    {
        return;
    }

    // These are harmless on vanilla CS and useful immediately on ReGameDLL.
    SERVER_COMMAND("mp_limitteams 0\n");
    SERVER_COMMAND("mp_autoteambalance 0\n");
    SERVER_COMMAND("mp_freezetime 0\n");
    SERVER_COMMAND("mp_round_infinite 1\n");
    SERVER_COMMAND("mp_ignore_round_win_conditions 1\n");
    SERVER_COMMAND("mp_forcerespawn 1\n");
    SERVER_COMMAND("mp_respawn_immunitytime 0\n");
    SERVER_COMMAND("humans_join_team T\n");
    SERVER_COMMAND("mp_auto_join_team 1\n");
    SERVER_EXECUTE();
}

void init_database()
{
    char game_dir[260] = {0};
    GET_GAME_DIR(game_dir);

    const char *db_path = g_db_path ? g_db_path->string : "addons/ako-rpg/arpg.sqlite";
    char error[512] = {0};
    if (!arpg::database_initialize(game_dir, db_path, error, sizeof(error)))
    {
        LOG_ERROR(PLID, "SQLite init failed: %s", error);
        return;
    }

    LOG_MESSAGE(PLID, "SQLite ready: %s\\%s", game_dir, db_path);
}

void touch_player(edict_t *player)
{
    if (!player || !is_enabled() || !arpg::database_is_open())
    {
        return;
    }

    const char *auth_id = g_engfuncs.pfnGetPlayerAuthId ? g_engfuncs.pfnGetPlayerAuthId(player) : nullptr;
    if (!auth_id || !auth_id[0])
    {
        auth_id = "UNKNOWN";
    }

    const char *name = STRING(player->v.netname);
    arpg::database_touch_player(auth_id, name);
}

void mm_game_init()
{
    apply_server_cvars();
    RETURN_META(MRES_IGNORED);
}

void mm_start_frame()
{
    arpg::hooks_start_frame();
    RETURN_META(MRES_IGNORED);
}

void mm_client_put_in_server(edict_t *player)
{
    touch_player(player);
    if (player && is_enabled())
    {
        CLIENT_COMMAND(player, "jointeam 1\n");
        CLIENT_COMMAND(player, "joinclass 1\n");
    }
    RETURN_META(MRES_IGNORED);
}

void mm_client_disconnect(edict_t *player)
{
    touch_player(player);
    RETURN_META(MRES_IGNORED);
}

void mm_client_command(edict_t *player)
{
    if (!is_enabled())
    {
        RETURN_META(MRES_IGNORED);
    }

    const char *command = safe_cmd_arg(0);
    if (strings_equal(command, "chooseteam"))
    {
        if (player)
        {
            CLIENT_PRINTF(player, print_center, "ARPG menu is handled by Ako RPG.");
        }
        RETURN_META(MRES_SUPERCEDE);
    }

    if (strings_equal(command, "jointeam"))
    {
        const char *team = safe_cmd_arg(1);
        if (strings_equal(team, "1") || strings_equal(team, "TERRORIST"))
        {
            RETURN_META(MRES_IGNORED);
        }

        if (player)
        {
            CLIENT_PRINTF(player, print_center, "Ako RPG locks players to Terrorist.");
        }
        RETURN_META(MRES_SUPERCEDE);
    }

    RETURN_META(MRES_IGNORED);
}

DLL_FUNCTIONS g_dll_hooks = {};

void init_dll_hooks()
{
    std::memset(&g_dll_hooks, 0, sizeof(g_dll_hooks));
    g_dll_hooks.pfnGameInit = mm_game_init;
    g_dll_hooks.pfnClientDisconnect = mm_client_disconnect;
    g_dll_hooks.pfnClientPutInServer = mm_client_put_in_server;
    g_dll_hooks.pfnClientCommand = mm_client_command;
    g_dll_hooks.pfnStartFrame = mm_start_frame;
}

META_FUNCTIONS g_meta_hooks = {
    nullptr,
    nullptr,
    GetEntityAPI2,
    nullptr,
    nullptr,
    nullptr,
    nullptr,
    nullptr,
};
}

C_DLLEXPORT int Meta_Query(char *ifvers, plugin_info_t **plugin_info, mutil_funcs_t *meta_util_funcs)
{
    if (ifvers)
    {
    }

    *plugin_info = &Plugin_info;
    gpMetaUtilFuncs = meta_util_funcs;
    return TRUE;
}

C_DLLEXPORT int Meta_Attach(PLUG_LOADTIME now, META_FUNCTIONS *function_table, meta_globals_t *meta_globals, gamedll_funcs_t *gamedll_funcs)
{
    if (now)
    {
    }

    if (!function_table || !meta_globals)
    {
        return FALSE;
    }

    std::memcpy(function_table, &g_meta_hooks, sizeof(META_FUNCTIONS));
    gpMetaGlobals = meta_globals;
    gpGamedllFuncs = gamedll_funcs;

    CVAR_REGISTER(&g_enabled_cvar);
    CVAR_REGISTER(&g_db_path_cvar);
    CVAR_REGISTER(&g_force_t_cvar);
    CVAR_REGISTER(&g_respawn_delay_cvar);
    CVAR_REGISTER(&g_hide_hud_cvar);
    g_enabled = CVAR_GET_POINTER("arpg_core_enabled");
    g_db_path = CVAR_GET_POINTER("arpg_db_path");

    LOG_CONSOLE(PLID, "[ARPGCORE] %s v%s loaded", Plugin_info.name, Plugin_info.version);
    init_database();
    arpg::hooks_initialize();
    apply_server_cvars();
    return TRUE;
}

C_DLLEXPORT int Meta_Detach(PLUG_LOADTIME now, PL_UNLOAD_REASON reason)
{
    if (now)
    {
    }
    if (reason)
    {
    }

    arpg::hooks_shutdown();
    arpg::database_shutdown();
    return TRUE;
}

C_DLLEXPORT int GetEntityAPI2(DLL_FUNCTIONS *function_table, int *interface_version)
{
    if (!function_table)
    {
        LOG_ERROR(PLID, "GetEntityAPI2 called with null function table");
        return FALSE;
    }

    if (*interface_version != INTERFACE_VERSION)
    {
        LOG_ERROR(PLID, "GetEntityAPI2 version mismatch; requested=%d ours=%d", *interface_version, INTERFACE_VERSION);
        *interface_version = INTERFACE_VERSION;
        return FALSE;
    }

    init_dll_hooks();
    std::memcpy(function_table, &g_dll_hooks, sizeof(DLL_FUNCTIONS));
    return TRUE;
}

extern "C" __declspec(dllexport) int arpg_core_version()
{
    return ARPG_CORE_VERSION;
}

namespace arpg
{
bool core_is_enabled()
{
    return is_enabled();
}
}
