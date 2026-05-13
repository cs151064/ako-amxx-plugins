#include <amxmodx>
#include <fakemeta>

#define MAX_PLAYERS 32
#define TASK_UNFREEZE 36000

#define CIRCLE_CLASS "amxx_chanmo_freeze_circle"
#define CIRCLE_MODEL "models/ref/magic_circle.mdl"
#define FREEZE_SOUND "ref/freeze_hit.wav"

new bool:g_enabled[MAX_PLAYERS + 1];
new Float:g_nextCast[MAX_PLAYERS + 1];
new bool:g_hasFreezeGlow[MAX_PLAYERS + 1];
new g_oldRenderFx[MAX_PLAYERS + 1];
new g_oldRenderMode[MAX_PLAYERS + 1];
new Float:g_oldRenderAmt[MAX_PLAYERS + 1];
new Float:g_oldRenderColor[MAX_PLAYERS + 1][3];

new g_cvarEnabled;
new g_cvarDuration;
new g_cvarFreezeTime;
new g_cvarCooldown;
new g_cvarMaxDistance;
new g_cvarTeamCheck;
new g_cvarFreezeGlow;
new g_cvarFreezeGlowAmount;
new g_cvarRadius;

public plugin_precache()
{
    precache_model(CIRCLE_MODEL);
    precache_sound(FREEZE_SOUND);
}

public plugin_init()
{
    register_plugin("magic_circle", "0.1.0", "Ako");

    g_cvarEnabled = register_cvar("magic_circle_enabled", "1");
    g_cvarDuration = register_cvar("magic_circle_duration", "5.0");
    g_cvarFreezeTime = register_cvar("magic_circle_freeze_time", "1.0");
    g_cvarCooldown = register_cvar("magic_circle_cooldown", "3.0");
    g_cvarMaxDistance = register_cvar("magic_circle_max_distance", "1000.0");
    g_cvarTeamCheck = register_cvar("magic_circle_teamcheck", "1");
    g_cvarFreezeGlow = register_cvar("magic_circle_freeze_glow", "1");
    g_cvarFreezeGlowAmount = register_cvar("magic_circle_freeze_glow_amount", "35.0");
    g_cvarRadius = register_cvar("magic_circle_radius", "180.0");

    register_forward(FM_CmdStart, "fw_CmdStart");
    register_forward(FM_Think, "fw_Think");

    register_event("DeathMsg", "event_death", "a");

    register_clcmd("magic_circle", "cmd_toggle_magic_circle");
}

public plugin_natives()
{
    register_native("magic_circle_get", "native_get", 1);
    register_native("magic_circle_toggle", "native_toggle", 1);
}

public client_putinserver(id)
{
    g_enabled[id] = false;
    g_nextCast[id] = 0.0;
    g_hasFreezeGlow[id] = false;
}

public client_disconnect(id)
{
    g_enabled[id] = false;
    g_hasFreezeGlow[id] = false;
    remove_task(id + TASK_UNFREEZE);
}

public event_death()
{
    new victim = read_data(2);

    if (is_valid_player(victim)) {
        clear_frozen_player(victim);
    }
}

public cmd_toggle_magic_circle(id)
{
    if (!is_user_connected(id)) {
        return PLUGIN_HANDLED;
    }

    magic_circle_toggle_player(id);
    return PLUGIN_HANDLED;
}

public fw_CmdStart(id, uc_handle, seed)
{
    if (!is_user_alive(id) || !g_enabled[id] || !get_pcvar_num(g_cvarEnabled)) {
        return FMRES_IGNORED;
    }

    new buttons = get_uc(uc_handle, UC_Buttons);
    new oldButtons = pev(id, pev_oldbuttons);

    if ((buttons & IN_USE) && !(oldButtons & IN_USE)) {
        set_uc(uc_handle, UC_Buttons, buttons & ~IN_USE);
        try_cast_circle(id);
    }

    return FMRES_IGNORED;
}

public fw_Think(ent)
{
    if (!pev_valid(ent)) {
        return FMRES_IGNORED;
    }

    static classname[32];
    pev(ent, pev_classname, classname, charsmax(classname));

    if (!equal(classname, CIRCLE_CLASS)) {
        return FMRES_IGNORED;
    }

    new Float:endTime;
    pev(ent, pev_fuser1, endTime);

    if (get_gametime() >= endTime) {
        engfunc(EngFunc_RemoveEntity, ent);
        return FMRES_IGNORED;
    }

    freeze_players_in_circle(ent);
    set_pev(ent, pev_nextthink, get_gametime() + 0.25);

    return FMRES_IGNORED;
}

public unfreeze_player(taskid)
{
    new id = taskid - TASK_UNFREEZE;

    if (!is_valid_player(id)) {
        return;
    }

    clear_frozen_player(id);
}

public native_get(id)
{
    return is_valid_player(id) && g_enabled[id];
}

public native_toggle(id)
{
    if (!is_valid_player(id)) {
        return 0;
    }

    return magic_circle_toggle_player(id);
}

magic_circle_toggle_player(id)
{
    g_enabled[id] = !g_enabled[id];
    client_print(id, print_chat, "[magic_circle] %s", g_enabled[id] ? "Enabled" : "Disabled");
    return g_enabled[id];
}

try_cast_circle(id)
{
    new Float:now = get_gametime();
    if (now < g_nextCast[id]) {
        client_print(id, print_center, "Magic circle cooldown %.1f sec", g_nextCast[id] - now);
        return;
    }

    static Float:origin[3];
    if (!get_aim_ground_position(id, origin)) {
        client_print(id, print_center, "Aim at the ground");
        return;
    }

    create_magic_circle(id, origin);
    g_nextCast[id] = now + get_pcvar_float(g_cvarCooldown);
}

create_magic_circle(id, const Float:origin[3])
{
    new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
    if (!pev_valid(ent)) {
        return;
    }

    set_pev(ent, pev_classname, CIRCLE_CLASS);
    set_pev(ent, pev_owner, id);
    set_pev(ent, pev_movetype, MOVETYPE_NONE);
    set_pev(ent, pev_solid, SOLID_NOT);
    set_pev(ent, pev_origin, origin);
    set_pev(ent, pev_rendermode, kRenderTransAdd);
    set_pev(ent, pev_renderamt, 230.0);
    set_pev(ent, pev_animtime, get_gametime());
    set_pev(ent, pev_framerate, 1.0);
    set_pev(ent, pev_fuser1, get_gametime() + get_pcvar_float(g_cvarDuration));

    engfunc(EngFunc_SetModel, ent, CIRCLE_MODEL);
    set_pev(ent, pev_nextthink, get_gametime() + 0.05);

    emit_sound(ent, CHAN_STATIC, FREEZE_SOUND, 1.0, ATTN_NORM, 0, PITCH_NORM);
}

freeze_players_in_circle(ent)
{
    new owner = pev(ent, pev_owner);
    new Float:radius = get_circle_radius();
    new Float:origin[3];
    pev(ent, pev_origin, origin);

    new victim = 0;
    while ((victim = engfunc(EngFunc_FindEntityInSphere, victim, origin, radius)) > 0) {
        if (!is_user_alive(victim) || victim == owner) {
            continue;
        }

        if (is_valid_player(owner) && get_pcvar_num(g_cvarTeamCheck) && get_user_team(victim) == get_user_team(owner)) {
            continue;
        }

        freeze_player(victim);
    }
}

freeze_player(id)
{
    static Float:zeroVelocity[3];
    zeroVelocity[0] = 0.0;
    zeroVelocity[1] = 0.0;
    zeroVelocity[2] = 0.0;

    set_pev(id, pev_velocity, zeroVelocity);
    set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN);
    apply_freeze_glow(id);

    remove_task(id + TASK_UNFREEZE);
    set_task(get_pcvar_float(g_cvarFreezeTime), "unfreeze_player", id + TASK_UNFREEZE);
}

clear_frozen_player(id)
{
    if (!is_valid_player(id)) {
        return;
    }

    set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
    restore_freeze_glow(id);
    remove_task(id + TASK_UNFREEZE);
}

apply_freeze_glow(id)
{
    if (!get_pcvar_num(g_cvarFreezeGlow)) {
        return;
    }

    if (!g_hasFreezeGlow[id]) {
        g_oldRenderFx[id] = pev(id, pev_renderfx);
        g_oldRenderMode[id] = pev(id, pev_rendermode);
        pev(id, pev_renderamt, g_oldRenderAmt[id]);
        pev(id, pev_rendercolor, g_oldRenderColor[id]);
        g_hasFreezeGlow[id] = true;
    }

    static Float:iceColor[3];
    iceColor[0] = 80.0;
    iceColor[1] = 210.0;
    iceColor[2] = 255.0;

    set_pev(id, pev_renderfx, kRenderFxGlowShell);
    set_pev(id, pev_rendermode, kRenderNormal);
    set_pev(id, pev_rendercolor, iceColor);
    set_pev(id, pev_renderamt, get_pcvar_float(g_cvarFreezeGlowAmount));
}

restore_freeze_glow(id)
{
    if (!g_hasFreezeGlow[id]) {
        return;
    }

    set_pev(id, pev_renderfx, g_oldRenderFx[id]);
    set_pev(id, pev_rendermode, g_oldRenderMode[id]);
    set_pev(id, pev_rendercolor, g_oldRenderColor[id]);
    set_pev(id, pev_renderamt, g_oldRenderAmt[id]);
    g_hasFreezeGlow[id] = false;
}

bool:get_aim_ground_position(id, Float:out[3])
{
    static Float:start[3], Float:viewOfs[3], Float:angles[3], Float:forwardVec[3], Float:endPos[3], Float:normal[3];

    pev(id, pev_origin, start);
    pev(id, pev_view_ofs, viewOfs);
    start[0] += viewOfs[0];
    start[1] += viewOfs[1];
    start[2] += viewOfs[2];

    pev(id, pev_v_angle, angles);
    engfunc(EngFunc_MakeVectors, angles);
    global_get(glb_v_forward, forwardVec);

    new Float:maxDistance = get_pcvar_float(g_cvarMaxDistance);
    endPos[0] = start[0] + forwardVec[0] * maxDistance;
    endPos[1] = start[1] + forwardVec[1] * maxDistance;
    endPos[2] = start[2] + forwardVec[2] * maxDistance;

    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, start, endPos, DONT_IGNORE_MONSTERS, id, trace);

    new Float:fraction;
    get_tr2(trace, TR_flFraction, fraction);
    get_tr2(trace, TR_vecPlaneNormal, normal);
    get_tr2(trace, TR_vecEndPos, out);
    free_tr2(trace);

    if (fraction >= 1.0 || normal[2] < 0.55) {
        return false;
    }

    out[2] += 4.0;
    return true;
}

Float:get_circle_radius()
{
    new Float:radius = get_pcvar_float(g_cvarRadius);

    if (radius < 32.0) {
        radius = 32.0;
    }
    else if (radius > 1000.0) {
        radius = 1000.0;
    }

    return radius;
}

bool:is_valid_player(id)
{
    return (id >= 1 && id <= MAX_PLAYERS && is_user_connected(id));
}
