#include <amxmodx>
#include <amxmisc>

#define PLUGIN_NAME "monster_dynamic_spawn"
#define PLUGIN_VERSION "0.1.0"
#define PLUGIN_AUTHOR "Ako"

#define MAX_PLAYERS 32
#define MAX_MONSTER_NAME 48
#define MAX_ENABLED_MONSTERS 32
#define MONSTER_PRECACHE_CFG "monster_precache.cfg"

new const MONSTER_CLASSNAMES[][] = {
    "monster_hutao",
    "monster_zombie",
    "monster_headcrab",
    "monster_houndeye",
    "monster_bullchicken",
    "monster_gonome",
    "monster_babygarg",
    "monster_alien_grunt",
    "monster_human_grunt",
    "monster_alien_controller",
    "monster_alien_slave",
    "monster_pitdrone",
    "monster_shocktrooper",
    "monster_alien_voltigore",
    "monster_stukabat"
};

new g_enabledMonsters[MAX_ENABLED_MONSTERS][MAX_MONSTER_NAME];
new g_enabledMonsterCount;
new g_selectedMonster[MAX_PLAYERS + 1][MAX_MONSTER_NAME];

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_clcmd("monster_spawn", "cmd_monster_spawn_menu", ADMIN_RCON);
    register_clcmd("/monster_spawn", "cmd_monster_spawn_menu", ADMIN_RCON);
    register_clcmd("mspawn", "cmd_monster_spawn_menu", ADMIN_RCON);
    register_clcmd("/mspawn", "cmd_monster_spawn_menu", ADMIN_RCON);

    register_concmd("amx_mspawn", "cmd_amx_mspawn", ADMIN_RCON, "<monster_classname> [player_index]");

    load_enabled_monsters();
}

public client_disconnected(id)
{
    g_selectedMonster[id][0] = 0;
}

public cmd_monster_spawn_menu(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) {
        return PLUGIN_HANDLED;
    }

    show_monster_menu(id);
    return PLUGIN_HANDLED;
}

public cmd_amx_mspawn(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) {
        return PLUGIN_HANDLED;
    }

    new monster[MAX_MONSTER_NAME];
    read_argv(1, monster, charsmax(monster));

    if (!is_enabled_monster(monster)) {
        console_print(id, "[怪物] 此怪物尚未啟用或未預載: %s", monster);
        console_print(id, "[怪物] 請先在 %s 啟用。", MONSTER_PRECACHE_CFG);
        return PLUGIN_HANDLED;
    }

    new target = id;
    if (read_argc() >= 3) {
        new arg[8];
        read_argv(2, arg, charsmax(arg));
        target = str_to_num(arg);
    }

    if (!is_user_alive(target)) {
        console_print(id, "[怪物] 目標玩家必須存活。");
        return PLUGIN_HANDLED;
    }

    spawn_monster_near_player(id, monster, target);
    return PLUGIN_HANDLED;
}

show_monster_menu(id)
{
    new menu = menu_create("生成怪物", "handle_monster_menu");

    if (g_enabledMonsterCount == 0) {
        menu_additem(menu, "沒有已啟用的怪物", "");
    }
    else {
        new displayName[MAX_MONSTER_NAME];
        for (new i = 0; i < g_enabledMonsterCount; i++) {
            get_monster_display_name(g_enabledMonsters[i], displayName, charsmax(displayName));
            menu_additem(menu, displayName, g_enabledMonsters[i]);
        }
    }

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
    menu_display(id, menu, 0);
}

public handle_monster_menu(id, menu, item)
{
    if (item == MENU_EXIT || g_enabledMonsterCount == 0) {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[MAX_MONSTER_NAME];
    new unusedName[2];
    new access;
    new callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), unusedName, charsmax(unusedName), callback);
    menu_destroy(menu);

    copy(g_selectedMonster[id], charsmax(g_selectedMonster[]), info);
    show_target_menu(id);

    return PLUGIN_HANDLED;
}

show_target_menu(id)
{
    new menuTitle[96];
    new displayName[MAX_MONSTER_NAME];
    get_monster_display_name(g_selectedMonster[id], displayName, charsmax(displayName));
    formatex(menuTitle, charsmax(menuTitle), "在誰附近生成 %s", displayName);

    new menu = menu_create(menuTitle, "handle_target_menu");

    new info[8];
    num_to_str(id, info, charsmax(info));
    menu_additem(menu, "我自己", info);

    new players[MAX_PLAYERS], playerCount;
    get_players(players, playerCount, "a");

    new name[32];
    for (new i = 0; i < playerCount; i++) {
        new player = players[i];

        if (player == id) {
            continue;
        }

        get_user_name(player, name, charsmax(name));
        num_to_str(player, info, charsmax(info));
        menu_additem(menu, name, info);
    }

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
    menu_display(id, menu, 0);
}

public handle_target_menu(id, menu, item)
{
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[8];
    new unusedName[2];
    new access;
    new callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), unusedName, charsmax(unusedName), callback);
    menu_destroy(menu);

    new target = str_to_num(info);
    spawn_monster_near_player(id, g_selectedMonster[id], target);

    return PLUGIN_HANDLED;
}

spawn_monster_near_player(admin, const monster[], target)
{
    if (!is_user_alive(target)) {
        client_print(admin, print_chat, "[怪物] 目標玩家必須存活。");
        return;
    }

    server_cmd("monster %s #%d", monster, target);
    server_exec();

    new targetName[32];
    get_user_name(target, targetName, charsmax(targetName));
    new displayName[MAX_MONSTER_NAME];
    get_monster_display_name(monster, displayName, charsmax(displayName));
    client_print(admin, print_chat, "[怪物] 已在 %s 附近生成 %s。", targetName, displayName);
}

bool:is_known_monster(const monster[])
{
    for (new i = 0; i < sizeof MONSTER_CLASSNAMES; i++) {
        if (equal(monster, MONSTER_CLASSNAMES[i])) {
            return true;
        }
    }

    return false;
}

bool:is_enabled_monster(const monster[])
{
    for (new i = 0; i < g_enabledMonsterCount; i++) {
        if (equal(monster, g_enabledMonsters[i])) {
            return true;
        }
    }

    return false;
}

load_enabled_monsters()
{
    g_enabledMonsterCount = 0;

    new file = fopen(MONSTER_PRECACHE_CFG, "rt");
    if (!file) {
        log_amx("[mspawn] Could not open %s. Monster spawn menu will be empty.", MONSTER_PRECACHE_CFG);
        return;
    }

    new line[128];
    while (!feof(file) && g_enabledMonsterCount < MAX_ENABLED_MONSTERS) {
        fgets(file, line, charsmax(line));
        trim(line);

        strip_inline_comment(line, "//");
        strip_inline_comment(line, ";");
        strip_inline_comment(line, "#");
        trim(line);

        if (!line[0]) {
            continue;
        }

        if (!is_known_monster(line)) {
            log_amx("[mspawn] Ignoring unknown monster in %s: %s", MONSTER_PRECACHE_CFG, line);
            continue;
        }

        if (is_enabled_monster(line)) {
            continue;
        }

        copy(g_enabledMonsters[g_enabledMonsterCount], charsmax(g_enabledMonsters[]), line);
        g_enabledMonsterCount++;
    }

    fclose(file);
    log_amx("[mspawn] Loaded %d enabled monsters from %s.", g_enabledMonsterCount, MONSTER_PRECACHE_CFG);
}

strip_inline_comment(text[], const marker[])
{
    new pos = contain(text, marker);
    if (pos >= 0) {
        text[pos] = 0;
    }
}

get_monster_display_name(const monster[], output[], len)
{
    if (equal(monster, "monster_hutao")) {
        copy(output, len, "胡桃");
        return;
    }

    copy(output, len, monster);
}
