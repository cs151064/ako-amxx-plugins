#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <xs>

#define MAX_PLAYERS 32

#define WEAPON_CSW CSW_AK47
#define WEAPON_CLASS "weapon_ak47"

#define V_MODEL "models/v_plasmagun2.mdl"
#define P_MODEL "models/p_plasmagun.mdl"
#define W_MODEL "models/w_plasmagun.mdl"
#define AK_V_MODEL "models/v_ak47.mdl"
#define AK_P_MODEL "models/p_ak47.mdl"
#define OLD_W_MODEL "models/w_ak47.mdl"
#define WEAPON_EVENT "events/ak47.sc"

#define PLASMA_BALL_MODEL "sprites/plasmaball.spr"
#define PLASMA_BOMB_MODEL "sprites/plasmabomb.spr"
#define MUZZLE_MODEL "sprites/muzzleflash27.spr"

#define FIRE_SOUND "weapons/plasmagun-1.wav"
#define EXP_SOUND "weapons/plasmagun_exp.wav"
#define DRAW_SOUND "weapons/plasmagun_draw.wav"

#define PLASMA_SECRET 260509
#define LASER_CLIP_AMMO 1

new const PRIMARY_WEAPON_CLASSES[][] = {
    "weapon_scout",
    "weapon_xm1014",
    "weapon_mac10",
    "weapon_aug",
    "weapon_ump45",
    "weapon_sg550",
    "weapon_galil",
    "weapon_famas",
    "weapon_awp",
    "weapon_mp5navy",
    "weapon_m249",
    "weapon_m3",
    "weapon_m4a1",
    "weapon_tmp",
    "weapon_g3sg1",
    "weapon_sg552",
    "weapon_ak47",
    "weapon_p90"
};

new const PRIMARY_WEAPON_IDS[] = {
    CSW_SCOUT,
    CSW_XM1014,
    CSW_MAC10,
    CSW_AUG,
    CSW_UMP45,
    CSW_SG550,
    CSW_GALIL,
    CSW_FAMAS,
    CSW_AWP,
    CSW_MP5NAVY,
    CSW_M249,
    CSW_M3,
    CSW_M4A1,
    CSW_TMP,
    CSW_G3SG1,
    CSW_SG552,
    CSW_AK47,
    CSW_P90
};

new bool:g_hasCannon[MAX_PLAYERS + 1];

new g_spriteBomb;
new g_spriteMuzzle;
new g_spriteLaser;
new g_spriteLightning;
new g_msgScreenShake;
new g_weaponEvent;

new g_cvarEnabled;
new g_cvarDamage;
new g_cvarRadius;
new g_cvarRecoil;
new g_cvarBpAmmo;
new g_cvarFireRate;
new g_cvarTeamCheck;
new g_cvarSelfDamage;

public plugin_precache()
{
    register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1);

    precache_model(V_MODEL);
    precache_model(P_MODEL);
    precache_model(W_MODEL);
    precache_model(PLASMA_BALL_MODEL);
    g_spriteBomb = precache_model(PLASMA_BOMB_MODEL);
    g_spriteMuzzle = precache_model(MUZZLE_MODEL);
    g_spriteLaser = precache_model("sprites/laserbeam.spr");
    g_spriteLightning = precache_model("sprites/lgtning.spr");

    precache_sound(FIRE_SOUND);
    precache_sound(EXP_SOUND);
    precache_sound(DRAW_SOUND);
    precache_sound("weapons/plasmagun_clipout.wav");
    precache_sound("weapons/plasmagun_clipin1.wav");
    precache_sound("weapons/plasmagun_clipin2.wav");
}

public plugin_init()
{
    register_plugin("laser_cannon", "0.4.0", "Ako");

    g_cvarEnabled = register_cvar("laser_cannon_enabled", "1");
    g_cvarDamage = register_cvar("laser_cannon_damage", "420.0");
    g_cvarRadius = register_cvar("laser_cannon_radius", "220.0");
    g_cvarRecoil = register_cvar("laser_cannon_recoil", "4.5");
    g_cvarBpAmmo = register_cvar("laser_cannon_bpammo", "60");
    g_cvarFireRate = register_cvar("laser_cannon_fire_rate", "0.38");
    g_cvarTeamCheck = register_cvar("laser_cannon_teamcheck", "1");
    g_cvarSelfDamage = register_cvar("laser_cannon_selfdamage", "0");

    register_clcmd("laser_cannon", "cmd_give_laser_cannon");
    register_clcmd("/laser_cannon", "cmd_give_laser_cannon");
    register_clcmd("lc", "cmd_give_laser_cannon");

    register_forward(FM_SetModel, "fw_SetModel");
    register_forward(FM_PlaybackEvent, "fw_PlaybackEvent");
    register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1);

    RegisterHam(Ham_Item_Deploy, WEAPON_CLASS, "fw_ItemDeploy_Post", 1);
    RegisterHam(Ham_Item_PostFrame, WEAPON_CLASS, "fw_ItemPostFrame");
    RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_CLASS, "fw_PrimaryAttack");
    RegisterHam(Ham_Weapon_Reload, WEAPON_CLASS, "fw_Reload");
    RegisterHam(Ham_Weapon_Reload, WEAPON_CLASS, "fw_Reload_Post", 1);
    RegisterHam(Ham_Item_AddToPlayer, WEAPON_CLASS, "fw_AddToPlayer_Post", 1);
    RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack");
    RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack");

    g_msgScreenShake = get_user_msgid("ScreenShake");
}

public fw_PrecacheEvent_Post(type, const name[])
{
    if (equal(WEAPON_EVENT, name)) {
        g_weaponEvent = get_orig_retval();
    }
}

public client_disconnect(id)
{
    g_hasCannon[id] = false;
}

public cmd_give_laser_cannon(id)
{
    if (!is_user_alive(id)) {
        client_print(id, print_chat, "[laser_cannon] You must be alive.");
        return PLUGIN_HANDLED;
    }

    give_laser_cannon(id);
    return PLUGIN_HANDLED;
}

give_laser_cannon(id)
{
    if (!g_hasCannon[id]) {
        drop_primary_weapons(id);
    }

    g_hasCannon[id] = true;

    if (!user_has_weapon(id, WEAPON_CSW)) {
        give_item(id, WEAPON_CLASS);
    }

    engclient_cmd(id, WEAPON_CLASS);

    new weapon = find_weapon_ent(id);
    if (weapon > 0) {
        cs_set_weapon_ammo(weapon, LASER_CLIP_AMMO);
    }

    cs_set_user_bpammo(id, WEAPON_CSW, get_pcvar_num(g_cvarBpAmmo));
    apply_models(id);

    emit_sound(id, CHAN_ITEM, DRAW_SOUND, 1.0, ATTN_NORM, 0, PITCH_NORM);
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
    if (is_laser_owner(id) && get_user_weapon(id) == WEAPON_CSW) {
        set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001);
    }

    return FMRES_HANDLED;
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
    if (eventid == g_weaponEvent && is_laser_owner(invoker) && get_user_weapon(invoker) == WEAPON_CSW) {
        return FMRES_SUPERCEDE;
    }

    return FMRES_IGNORED;
}

public fw_TraceAttack(victim, attacker, Float:damage, Float:direction[3], tracehandle, damagebits)
{
    if (is_laser_owner(attacker) && get_user_weapon(attacker) == WEAPON_CSW) {
        return HAM_SUPERCEDE;
    }

    return HAM_IGNORED;
}

public fw_ItemDeploy_Post(weapon)
{
    if (!pev_valid(weapon)) {
        return HAM_IGNORED;
    }

    new id = pev(weapon, pev_owner);
    if (!is_laser_owner(id)) {
        return HAM_IGNORED;
    }

    apply_models(id);
    cs_set_weapon_ammo(weapon, LASER_CLIP_AMMO);
    return HAM_IGNORED;
}

public fw_PrimaryAttack(weapon)
{
    if (!pev_valid(weapon)) {
        return HAM_IGNORED;
    }

    new id = pev(weapon, pev_owner);
    if (!is_laser_owner(id)) {
        return HAM_IGNORED;
    }

    if (!get_pcvar_num(g_cvarEnabled)) {
        return HAM_SUPERCEDE;
    }

    new bpammo = cs_get_user_bpammo(id, WEAPON_CSW);
    if (bpammo <= 0) {
        emit_sound(id, CHAN_WEAPON, "weapons/dryfire_rifle.wav", 0.8, ATTN_NORM, 0, PITCH_NORM);
        set_pdata_float(weapon, 46, 0.35, 4);
        return HAM_SUPERCEDE;
    }

    cs_set_user_bpammo(id, WEAPON_CSW, bpammo - 1);
    cs_set_weapon_ammo(weapon, LASER_CLIP_AMMO);

    set_weapon_anim(id, random_num(3, 5));
    make_muzzleflash(id);
    fire_instant_laser(id);
    apply_recoil(id);
    emit_sound(id, CHAN_WEAPON, FIRE_SOUND, 1.0, ATTN_NORM, 0, PITCH_NORM);

    new Float:fireRate = get_fire_rate();
    set_pdata_float(weapon, 46, fireRate, 4);
    set_pdata_float(weapon, 47, fireRate, 4);
    set_pdata_float(weapon, 48, fireRate + 0.35, 4);
    set_pdata_float(id, 83, 0.05, 5);

    return HAM_SUPERCEDE;
}

public fw_Reload(weapon)
{
    if (!pev_valid(weapon)) {
        return HAM_IGNORED;
    }

    new id = pev(weapon, pev_owner);
    if (!is_laser_owner(id)) {
        return HAM_IGNORED;
    }

    cs_set_weapon_ammo(weapon, LASER_CLIP_AMMO);
    set_pdata_int(weapon, 54, 0, 4);
    return HAM_SUPERCEDE;
}

public fw_Reload_Post(weapon)
{
    if (!pev_valid(weapon)) {
        return HAM_IGNORED;
    }

    new id = pev(weapon, pev_owner);
    if (!is_laser_owner(id)) {
        return HAM_IGNORED;
    }

    cs_set_weapon_ammo(weapon, LASER_CLIP_AMMO);
    set_pdata_int(weapon, 54, 0, 4);

    return HAM_IGNORED;
}

public fw_ItemPostFrame(weapon)
{
    if (!pev_valid(weapon)) {
        return HAM_IGNORED;
    }

    new id = pev(weapon, pev_owner);
    if (!is_laser_owner(id)) {
        return HAM_IGNORED;
    }

    set_pdata_int(weapon, 54, 0, 4);
    cs_set_weapon_ammo(weapon, LASER_CLIP_AMMO);

    return HAM_IGNORED;
}

public fw_AddToPlayer_Post(weapon, id)
{
    if (!pev_valid(weapon)) {
        return HAM_IGNORED;
    }

    if (pev(weapon, pev_impulse) == PLASMA_SECRET) {
        g_hasCannon[id] = true;
        set_pev(weapon, pev_impulse, 0);

        cs_set_weapon_ammo(weapon, LASER_CLIP_AMMO);

        if (is_user_alive(id) && get_user_weapon(id) == WEAPON_CSW) {
            apply_models(id);
        }

        set_task(0.1, "refresh_player_weapon_model", id);
    }

    return HAM_IGNORED;
}

public fw_SetModel(entity, const model[])
{
    if (!pev_valid(entity) || !equal(model, OLD_W_MODEL)) {
        return FMRES_IGNORED;
    }

    static classname[32];
    pev(entity, pev_classname, classname, charsmax(classname));

    if (!equal(classname, "weaponbox")) {
        return FMRES_IGNORED;
    }

    new owner = pev(entity, pev_owner);
    if (!is_valid_player_index(owner) || !g_hasCannon[owner]) {
        return FMRES_IGNORED;
    }

    new weapon = find_ent_by_owner(-1, WEAPON_CLASS, entity);
    if (weapon > 0) {
        set_pev(weapon, pev_impulse, PLASMA_SECRET);
    }

    g_hasCannon[owner] = false;
    engfunc(EngFunc_SetModel, entity, W_MODEL);
    set_task(0.1, "refresh_player_weapon_model", owner);

    return FMRES_SUPERCEDE;
}

fire_instant_laser(id)
{
    static Float:start[3], Float:target[3], Float:hit[3];
    get_weapon_position(id, start, 48.0, 10.0, -5.0);
    get_aim_position(id, target, 4096.0);
    trace_laser(id, start, target, hit);

    make_launch_beam(start, hit);
    explode_plasma(id, hit, find_direct_hit(id, start, hit));
}

trace_laser(id, const Float:start[3], const Float:target[3], Float:hit[3])
{
    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, start, target, DONT_IGNORE_MONSTERS, id, trace);
    get_tr2(trace, TR_vecEndPos, hit);
    free_tr2(trace);
}

find_direct_hit(id, const Float:start[3], const Float:hit[3])
{
    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, start, hit, DONT_IGNORE_MONSTERS, id, trace);
    new touched = get_tr2(trace, TR_pHit);
    free_tr2(trace);

    return touched;
}

explode_plasma(attacker, const Float:origin[3], touched)
{
    new flags = TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NOPARTICLES;

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0);
    write_byte(TE_EXPLOSION);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2]);
    write_short(g_spriteBomb);
    write_byte(18);
    write_byte(30);
    write_byte(flags);
    message_end();

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0);
    write_byte(TE_EXPLOSION);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2] + 28.0);
    write_short(g_spriteBomb);
    write_byte(9);
    write_byte(40);
    write_byte(flags);
    message_end();

    send_plasma_splash(origin, 120.0, 255, 90, 30, 255);
    send_plasma_splash(origin, 230.0, 255, 210, 60, 235);
    send_plasma_splash(origin, 360.0, 80, 220, 255, 220);
    send_plasma_splash(origin, 500.0, 255, 255, 255, 160);
    send_dynamic_light(origin, 62, 255, 95, 35);
    send_dynamic_light(origin, 42, 80, 220, 255);
    send_sparks(origin);

    emit_explosion_sound(origin);

    damage_plasma(attacker, origin, touched);
    shake_nearby_players(origin);
}

damage_plasma(attacker, const Float:origin[3], touched)
{
    new Float:radius = get_pcvar_float(g_cvarRadius);
    new Float:damage = get_pcvar_float(g_cvarDamage);

    for (new victim = 1; victim <= MAX_PLAYERS; victim++) {
        if (!is_user_alive(victim)) {
            continue;
        }

        if (victim == attacker && !get_pcvar_num(g_cvarSelfDamage)) {
            continue;
        }

        if (attacker && victim != attacker && get_pcvar_num(g_cvarTeamCheck) && get_user_team(victim) == get_user_team(attacker)) {
            continue;
        }

        static Float:victimOrigin[3];
        pev(victim, pev_origin, victimOrigin);

        new Float:distance = get_distance_f(origin, victimOrigin);
        if (distance > radius && victim != touched) {
            continue;
        }

        new Float:scale = 1.0 - (distance / radius);
        if (victim == touched) {
            scale = 1.0;
        }
        else if (scale < 0.35) {
            scale = 0.35;
        }

        ExecuteHamB(Ham_TakeDamage, victim, attacker, attacker, damage * scale, DMG_ACID | DMG_ENERGYBEAM);
    }
}

send_plasma_splash(const Float:origin[3], Float:radius, red, green, blue, brightness)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0);
    write_byte(TE_BEAMCYLINDER);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2] + 6.0);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2] + radius);
    write_short(g_spriteBomb);
    write_byte(0);
    write_byte(12);
    write_byte(8);
    write_byte(42);
    write_byte(4);
    write_byte(red);
    write_byte(green);
    write_byte(blue);
    write_byte(brightness);
    write_byte(18);
    message_end();
}

send_dynamic_light(const Float:origin[3], radius, red, green, blue)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0);
    write_byte(TE_DLIGHT);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2]);
    write_byte(radius);
    write_byte(red);
    write_byte(green);
    write_byte(blue);
    write_byte(8);
    write_byte(24);
    message_end();
}

make_muzzleflash(id)
{
    static Float:origin[3];
    get_weapon_position(id, origin, 32.0, 6.0, -15.0);

    new flags = TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NOPARTICLES;

    engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, origin, id);
    write_byte(TE_EXPLOSION);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2]);
    write_short(g_spriteMuzzle);
    write_byte(2);
    write_byte(30);
    write_byte(flags);
    message_end();

    send_dynamic_light(origin, 22, 255, 140, 40);
    send_plasma_splash(origin, 80.0, 255, 180, 60, 190);
}

apply_recoil(id)
{
    static Float:punch[3];
    pev(id, pev_punchangle, punch);

    new Float:recoil = get_pcvar_float(g_cvarRecoil);
    punch[0] -= recoil;
    punch[1] += random_float(-recoil * 0.35, recoil * 0.35);
    punch[2] = 0.0;

    set_pev(id, pev_punchangle, punch);
}

make_launch_beam(const Float:start[3], const Float:target[3])
{
    send_beam_points(start, target, g_spriteLaser, 255, 70, 30, 255, 34, 6, 2);
    send_beam_points(start, target, g_spriteLightning, 70, 230, 255, 230, 18, 28, 3);
    send_beam_points(start, target, g_spriteLaser, 255, 255, 255, 220, 7, 2, 2);
}

send_beam_points(const Float:start[3], const Float:target[3], sprite, red, green, blue, brightness, width, noise, life)
{
    engfunc(EngFunc_MessageBegin, MSG_BROADCAST, SVC_TEMPENTITY, start, 0);
    write_byte(TE_BEAMPOINTS);
    engfunc(EngFunc_WriteCoord, start[0]);
    engfunc(EngFunc_WriteCoord, start[1]);
    engfunc(EngFunc_WriteCoord, start[2]);
    engfunc(EngFunc_WriteCoord, target[0]);
    engfunc(EngFunc_WriteCoord, target[1]);
    engfunc(EngFunc_WriteCoord, target[2]);
    write_short(sprite);
    write_byte(0);
    write_byte(20);
    write_byte(life);
    write_byte(width);
    write_byte(noise);
    write_byte(red);
    write_byte(green);
    write_byte(blue);
    write_byte(brightness);
    write_byte(40);
    message_end();
}

send_sparks(const Float:origin[3])
{
    for (new i = 0; i < 12; i++) {
        engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0);
        write_byte(TE_SPARKS);
        engfunc(EngFunc_WriteCoord, origin[0] + random_float(-110.0, 110.0));
        engfunc(EngFunc_WriteCoord, origin[1] + random_float(-110.0, 110.0));
        engfunc(EngFunc_WriteCoord, origin[2] + random_float(-35.0, 120.0));
        message_end();
    }
}

shake_nearby_players(const Float:origin[3])
{
    new Float:radius = get_pcvar_float(g_cvarRadius) + 160.0;

    for (new id = 1; id <= MAX_PLAYERS; id++) {
        if (!is_user_connected(id)) {
            continue;
        }

        static Float:playerOrigin[3];
        pev(id, pev_origin, playerOrigin);

        if (get_distance_f(origin, playerOrigin) > radius) {
            continue;
        }

        message_begin(MSG_ONE_UNRELIABLE, g_msgScreenShake, _, id);
        write_short(1 << 13);
        write_short(1 << 12);
        write_short(1 << 13);
        message_end();
    }
}

emit_explosion_sound(const Float:origin[3])
{
    new soundEntity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
    if (pev_valid(soundEntity)) {
        set_pev(soundEntity, pev_classname, "ako_laser_sound");
        engfunc(EngFunc_SetOrigin, soundEntity, origin);
        emit_sound(soundEntity, CHAN_STATIC, EXP_SOUND, 1.0, ATTN_NORM, 0, PITCH_NORM);
        set_task(1.0, "remove_sound_entity", soundEntity);
    }
    else {
        emit_sound(0, CHAN_AUTO, EXP_SOUND, 1.0, ATTN_NORM, 0, PITCH_NORM);
    }
}

public remove_sound_entity(entity)
{
    if (pev_valid(entity)) {
        engfunc(EngFunc_RemoveEntity, entity);
    }
}

apply_models(id)
{
    set_pev(id, pev_viewmodel2, V_MODEL);
    set_pev(id, pev_weaponmodel2, P_MODEL);
}

public refresh_player_weapon_model(id)
{
    if (!is_user_alive(id) || get_user_weapon(id) != WEAPON_CSW) {
        return;
    }

    if (g_hasCannon[id]) {
        apply_models(id);
        return;
    }

    set_pev(id, pev_viewmodel2, AK_V_MODEL);
    set_pev(id, pev_weaponmodel2, AK_P_MODEL);
}

set_weapon_anim(id, anim)
{
    set_pev(id, pev_weaponanim, anim);
    message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id);
    write_byte(anim);
    write_byte(pev(id, pev_body));
    message_end();
}

get_aim_position(id, Float:target[3], Float:range)
{
    static Float:eye[3], Float:viewAngles[3], Float:vecForward[3];

    get_eye_origin(id, eye);
    pev(id, pev_v_angle, viewAngles);
    engfunc(EngFunc_MakeVectors, viewAngles);
    global_get(glb_v_forward, vecForward);

    target[0] = eye[0] + vecForward[0] * range;
    target[1] = eye[1] + vecForward[1] * range;
    target[2] = eye[2] + vecForward[2] * range;
}

get_weapon_position(id, Float:origin[3], Float:addForward, Float:addRight, Float:addUp)
{
    static Float:eye[3], Float:viewAngles[3], Float:vecForward[3], Float:vecRight[3], Float:vecUp[3];

    get_eye_origin(id, eye);
    pev(id, pev_v_angle, viewAngles);
    engfunc(EngFunc_MakeVectors, viewAngles);
    global_get(glb_v_forward, vecForward);
    global_get(glb_v_right, vecRight);
    global_get(glb_v_up, vecUp);

    origin[0] = eye[0] + vecForward[0] * addForward + vecRight[0] * addRight + vecUp[0] * addUp;
    origin[1] = eye[1] + vecForward[1] * addForward + vecRight[1] * addRight + vecUp[1] * addUp;
    origin[2] = eye[2] + vecForward[2] * addForward + vecRight[2] * addRight + vecUp[2] * addUp;
}

get_eye_origin(id, Float:origin[3])
{
    static Float:viewOfs[3];
    pev(id, pev_origin, origin);
    pev(id, pev_view_ofs, viewOfs);
    xs_vec_add(origin, viewOfs, origin);
}

find_weapon_ent(id)
{
    return find_ent_by_owner(-1, WEAPON_CLASS, id);
}

drop_primary_weapons(id)
{
    for (new i = 0; i < sizeof PRIMARY_WEAPON_IDS; i++) {
        if (!user_has_weapon(id, PRIMARY_WEAPON_IDS[i])) {
            continue;
        }

        engclient_cmd(id, PRIMARY_WEAPON_CLASSES[i]);
        engclient_cmd(id, "drop");
    }
}

Float:get_fire_rate()
{
    new Float:rate = get_pcvar_float(g_cvarFireRate);

    if (rate < 0.08) {
        rate = 0.08;
    }
    else if (rate > 2.0) {
        rate = 2.0;
    }

    return rate;
}

bool:is_laser_owner(id)
{
    return is_valid_player_index(id) && g_hasCannon[id] && is_user_connected(id);
}

bool:is_valid_player_index(id)
{
    return (id >= 1 && id <= MAX_PLAYERS);
}
