#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#define MAX_PLAYERS 32
#define HEAD_BONE 8

enum
{
    AIM_MODE_FIRE = 0,
    AIM_MODE_ALWAYS
};

new bool:g_enabled[MAX_PLAYERS + 1];
new bool:g_firePrimed[MAX_PLAYERS + 1];
new bool:g_autoFire[MAX_PLAYERS + 1];
new g_mode[MAX_PLAYERS + 1];
new g_maxPlayers;

new g_cvarEnabled;
new g_cvarMaxDistance;
new g_cvarVisibleOnly;
new g_cvarTeamCheck;
new g_cvarFov;
new g_cvarPrefireLock;
new g_cvarHeadshotFix;
new g_cvarUseHeadBone;
new g_cvarPredictTime;
new g_cvarHeadOffsetZ;

public plugin_init()
{
    register_plugin("fake_aimbot", "0.1.0", "Ako");

    g_maxPlayers = get_maxplayers();

    g_cvarEnabled = register_cvar("fake_aimbot_enabled", "1");
    g_cvarMaxDistance = register_cvar("fake_aimbot_maxdist", "2500.0");
    g_cvarVisibleOnly = register_cvar("fake_aimbot_visible_only", "1");
    g_cvarTeamCheck = register_cvar("fake_aimbot_teamcheck", "1");
    g_cvarFov = register_cvar("fake_aimbot_fov", "45.0");
    g_cvarPrefireLock = register_cvar("fake_aimbot_prefire_lock", "1");
    g_cvarHeadshotFix = register_cvar("fake_aimbot_headshot_fix", "1");
    g_cvarUseHeadBone = register_cvar("fake_aimbot_use_head_bone", "1");
    g_cvarPredictTime = register_cvar("fake_aimbot_predict_time", "0.045");
    g_cvarHeadOffsetZ = register_cvar("fake_aimbot_head_offset_z", "0.0");

    register_forward(FM_CmdStart, "fw_CmdStart");
    RegisterHam(Ham_TraceAttack, "player", "fw_PlayerTraceAttack");
}

public plugin_natives()
{
    register_native("fake_aimbot_get", "native_aimbot_get", 1);
    register_native("fake_aimbot_set", "native_aimbot_set", 1);
    register_native("fake_aimbot_toggle", "native_aimbot_toggle", 1);
    register_native("fake_aimbot_get_mode", "native_aimbot_get_mode", 1);
    register_native("fake_aimbot_toggle_mode", "native_aimbot_toggle_mode", 1);
    register_native("fake_aimbot_get_autofire", "native_aimbot_get_autofire", 1);
    register_native("fake_aimbot_toggle_autofire", "native_aimbot_toggle_autofire", 1);
}

public client_disconnect(id)
{
    g_enabled[id] = false;
    g_firePrimed[id] = false;
    g_autoFire[id] = false;
    g_mode[id] = AIM_MODE_FIRE;
}

public bool:native_aimbot_get(id)
{
    if (!is_valid_player_index(id)) {
        return false;
    }

    return g_enabled[id];
}

public bool:native_aimbot_set(id, bool:enabled)
{
    if (!is_valid_player_index(id)) {
        return false;
    }

    g_enabled[id] = enabled;
    return g_enabled[id];
}

public bool:native_aimbot_toggle(id)
{
    if (!is_valid_player_index(id)) {
        return false;
    }

    g_enabled[id] = !g_enabled[id];
    return g_enabled[id];
}

public native_aimbot_get_mode(id)
{
    if (!is_valid_player_index(id)) {
        return AIM_MODE_FIRE;
    }

    return g_mode[id];
}

public native_aimbot_toggle_mode(id)
{
    if (!is_valid_player_index(id)) {
        return AIM_MODE_FIRE;
    }

    g_mode[id] = (g_mode[id] == AIM_MODE_FIRE) ? AIM_MODE_ALWAYS : AIM_MODE_FIRE;
    return g_mode[id];
}

public bool:native_aimbot_get_autofire(id)
{
    if (!is_valid_player_index(id)) {
        return false;
    }

    return g_autoFire[id];
}

public bool:native_aimbot_toggle_autofire(id)
{
    if (!is_valid_player_index(id)) {
        return false;
    }

    g_autoFire[id] = !g_autoFire[id];
    g_firePrimed[id] = false;
    return g_autoFire[id];
}

public fw_CmdStart(id, ucHandle)
{
    if (!get_pcvar_num(g_cvarEnabled) || !g_enabled[id] || !is_user_alive(id)) {
        g_firePrimed[id] = false;
        return FMRES_IGNORED;
    }

    new buttons = get_uc(ucHandle, UC_Buttons);

    if (!g_autoFire[id] && g_mode[id] == AIM_MODE_FIRE) {
        if (!(buttons & IN_ATTACK)) {
            g_firePrimed[id] = false;
            return FMRES_IGNORED;
        }
    }
    else {
        g_firePrimed[id] = false;
    }

    new target = find_best_target(id);
    if (!target) {
        return FMRES_IGNORED;
    }

    static Float:eye[3], Float:head[3], Float:angles[3], Float:punch[3];
    get_eye_origin(id, eye);
    get_aim_head_origin(target, head);
    get_angles_to_point(eye, head, angles);

    punch[0] = 0.0;
    punch[1] = 0.0;
    punch[2] = 0.0;

    apply_visible_aim(id, ucHandle, angles);
    set_pev(id, pev_punchangle, punch);

    if (g_autoFire[id]) {
        click_attack(id, ucHandle, buttons);
        g_firePrimed[id] = true;
        return FMRES_HANDLED;
    }

    if (g_mode[id] == AIM_MODE_FIRE && get_pcvar_num(g_cvarPrefireLock) && !g_firePrimed[id]) {
        buttons &= ~IN_ATTACK;
        set_uc(ucHandle, UC_Buttons, buttons);
        set_pev(id, pev_button, buttons);
        g_firePrimed[id] = true;
        return FMRES_HANDLED;
    }

    g_firePrimed[id] = true;

    return FMRES_HANDLED;
}

click_attack(id, ucHandle, buttons)
{
    new oldButtons = pev(id, pev_oldbuttons);
    oldButtons &= ~IN_ATTACK;
    set_pev(id, pev_oldbuttons, oldButtons);

    buttons |= IN_ATTACK;
    set_uc(ucHandle, UC_Buttons, buttons);
    set_pev(id, pev_button, buttons);
}

public fw_PlayerTraceAttack(victim, attacker, Float:damage, Float:direction[3], tracehandle, damage_type)
{
    if (!get_pcvar_num(g_cvarEnabled) || !get_pcvar_num(g_cvarHeadshotFix)) {
        return HAM_IGNORED;
    }

    if (!is_valid_player_index(attacker) || !g_enabled[attacker] || !is_user_alive(attacker)) {
        return HAM_IGNORED;
    }

    if (victim == attacker || !is_user_alive(victim)) {
        return HAM_IGNORED;
    }

    if (get_pcvar_num(g_cvarTeamCheck) && get_user_team(attacker) == get_user_team(victim)) {
        return HAM_IGNORED;
    }

    set_tr2(tracehandle, TR_iHitgroup, HIT_HEAD);
    return HAM_IGNORED;
}

apply_visible_aim(id, ucHandle, const Float:angles[3])
{
    set_uc(ucHandle, UC_ViewAngles, angles);

    // pev_angles + pev_fixangle is what makes the client camera actually snap.
    // Only changing UC_ViewAngles/pev_v_angle behaves like silent aim on CS 1.6.
    set_pev(id, pev_angles, angles);
    set_pev(id, pev_v_angle, angles);
    set_pev(id, pev_fixangle, 1);
}

find_best_target(id)
{
    static Float:eye[3], Float:head[3], Float:viewAngles[3], Float:targetAngles[3];
    get_eye_origin(id, eye);
    pev(id, pev_v_angle, viewAngles);

    new bestTarget = 0;
    new Float:bestScore = 999999.0;
    new Float:maxDistance = get_pcvar_float(g_cvarMaxDistance);
    new Float:maxFov = get_pcvar_float(g_cvarFov);

    for (new target = 1; target <= g_maxPlayers; target++) {
        if (target == id || !is_user_alive(target)) {
            continue;
        }

        if (get_pcvar_num(g_cvarTeamCheck) && get_user_team(id) == get_user_team(target)) {
            continue;
        }

        get_aim_head_origin(target, head);

        new Float:distance = get_distance_f(eye, head);
        if (distance > maxDistance) {
            continue;
        }

        if (get_pcvar_num(g_cvarVisibleOnly) && !is_target_visible(id, target, eye, head)) {
            continue;
        }

        get_angles_to_point(eye, head, targetAngles);

        new Float:fov = get_angle_delta(viewAngles, targetAngles);
        if (fov > maxFov || fov >= bestScore) {
            continue;
        }

        bestTarget = target;
        bestScore = fov;
    }

    return bestTarget;
}

bool:is_target_visible(id, target, const Float:start[3], const Float:end[3])
{
    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, start, end, DONT_IGNORE_MONSTERS, id, trace);

    new hit = get_tr2(trace, TR_pHit);
    new Float:fraction;
    get_tr2(trace, TR_flFraction, fraction);

    free_tr2(trace);

    return (hit == target || fraction >= 0.999);
}

get_eye_origin(id, Float:origin[3])
{
    static Float:viewOfs[3];
    pev(id, pev_origin, origin);
    pev(id, pev_view_ofs, viewOfs);
    xs_vec_add(origin, viewOfs, origin);
}

get_head_origin(id, Float:origin[3])
{
    static Float:viewOfs[3];
    pev(id, pev_origin, origin);
    pev(id, pev_view_ofs, viewOfs);

    origin[0] += viewOfs[0];
    origin[1] += viewOfs[1];
    origin[2] += viewOfs[2] + 2.0;
}

get_aim_head_origin(id, Float:origin[3])
{
    if (get_pcvar_num(g_cvarUseHeadBone)) {
        static Float:angles[3];
        engfunc(EngFunc_GetBonePosition, id, HEAD_BONE, origin, angles);
    }
    else {
        get_head_origin(id, origin);
    }

    static Float:velocity[3];
    pev(id, pev_velocity, velocity);

    new Float:predictTime = get_pcvar_float(g_cvarPredictTime);
    origin[0] += velocity[0] * predictTime;
    origin[1] += velocity[1] * predictTime;
    origin[2] += velocity[2] * predictTime;
    origin[2] += get_pcvar_float(g_cvarHeadOffsetZ);
}

get_angles_to_point(const Float:start[3], const Float:end[3], Float:angles[3])
{
    static Float:direction[3];
    xs_vec_sub(end, start, direction);
    vector_to_angle(direction, angles);

    angles[0] *= -1.0;

    if (angles[1] > 180.0) {
        angles[1] -= 360.0;
    }

    angles[2] = 0.0;
}

bool:is_valid_player_index(id)
{
    return (id >= 1 && id <= MAX_PLAYERS);
}

Float:get_angle_delta(const Float:source[3], const Float:target[3])
{
    new Float:pitch = floatabs(normalize_angle(source[0] - target[0]));
    new Float:yaw = floatabs(normalize_angle(source[1] - target[1]));

    return floatsqroot((pitch * pitch) + (yaw * yaw));
}

Float:normalize_angle(Float:angle)
{
    while (angle > 180.0) {
        angle -= 360.0;
    }

    while (angle < -180.0) {
        angle += 360.0;
    }

    return angle;
}
