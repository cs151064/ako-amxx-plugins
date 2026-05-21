#include "arpg_core.h"

#include "extdll.h"
#include "meta_api.h"
#include "sdk_util.h"

extern enginefuncs_t g_engfuncs;
extern globalvars_t *gpGlobals;

namespace arpg
{
namespace
{
constexpr int kMaxClients = 32;
constexpr int kHideHudHealth = 1 << 3;
constexpr int kHideHudTimer = 1 << 4;
constexpr int kHideHudMoney = 1 << 5;

int g_msg_hide_weapon = 0;
float g_next_hud_at[kMaxClients + 1] = {};

bool cvar_enabled(const char *name, bool fallback)
{
    cvar_t *cvar = CVAR_GET_POINTER(name);
    if (!cvar)
    {
        return fallback;
    }

    return cvar->value != 0.0f;
}

bool should_hide_hud()
{
    return core_is_enabled() && cvar_enabled("arpg_hide_hud", true);
}

bool is_client_edict(edict_t *player)
{
    return player && !player->free && (player->v.flags & FL_CLIENT) != 0;
}

void send_hide_hud(edict_t *player)
{
    if (!should_hide_hud() || !is_client_edict(player))
    {
        return;
    }

    if (!g_msg_hide_weapon)
    {
        g_msg_hide_weapon = REG_USER_MSG("HideWeapon", 1);
    }

    if (!g_msg_hide_weapon)
    {
        return;
    }

    MESSAGE_BEGIN(MSG_ONE_UNRELIABLE, g_msg_hide_weapon, nullptr, player);
    WRITE_BYTE(kHideHudHealth | kHideHudTimer | kHideHudMoney);
    MESSAGE_END();
}

void run_hud_updates()
{
    if (!should_hide_hud() || !gpGlobals)
    {
        return;
    }

    const float now = gpGlobals->time;
    const int max_clients = gpGlobals->maxClients < kMaxClients ? gpGlobals->maxClients : kMaxClients;

    for (int index = 1; index <= max_clients; ++index)
    {
        if (g_next_hud_at[index] > now)
        {
            continue;
        }

        g_next_hud_at[index] = now + 0.25f;
        send_hide_hud(INDEXENT(index));
    }
}
}

bool hooks_initialize()
{
    for (int index = 0; index <= kMaxClients; ++index)
    {
        g_next_hud_at[index] = 0.0f;
    }

    LOG_MESSAGE(PLID, "Core fallback hooks active; ReGameDLL hookchain layer is disabled in this build");
    return true;
}

void hooks_shutdown()
{
    for (int index = 0; index <= kMaxClients; ++index)
    {
        g_next_hud_at[index] = 0.0f;
    }
}

void hooks_start_frame()
{
    run_hud_updates();
}
}
