#include <amxmodx>

native bool:fake_aimbot_get(id);
native bool:fake_aimbot_toggle(id);
native fake_aimbot_get_mode(id);
native fake_aimbot_toggle_mode(id);
native bool:magic_circle_get(id);
native bool:magic_circle_toggle(id);

enum
{
    AIM_MODE_FIRE = 0,
    AIM_MODE_ALWAYS
};

enum
{
    N1,
    N2,
    N3,
    N4,
    N5,
    N6,
    N7,
    N8,
    N9,
    N0
};

enum
{
    B1 = 1 << N1,
    B2 = 1 << N2,
    B0 = 1 << N0
};

new g_mainKeys;
new g_aimbotKeys;

new g_mainBody[384];
new g_aimbotBody[256];

public plugin_init()
{
    register_plugin("special_menu", "0.4.0", "Ako");

    register_clcmd("/special", "cmd_special_menu");
    register_clcmd("special", "cmd_special_menu");
    register_clcmd("kkk", "cmd_special_menu");

    create_menu_templates();

    register_menucmd(register_menuid("special_main_menu"), g_mainKeys, "handle_main_menu");
    register_menucmd(register_menuid("special_aimbot_menu"), g_aimbotKeys, "handle_aimbot_menu");
}

create_menu_templates()
{
    new size = sizeof(g_mainBody);
    add(g_mainBody, size, "\y特殊功能選單^n^n");
    add(g_mainBody, size, "\r1. \w仿 Aimbot: %s^n");
    add(g_mainBody, size, "\r2. \w魔法陣: %s^n");
    add(g_mainBody, size, "^n\r0. \w離開");
    g_mainKeys = B1 | B2 | B0;

    size = sizeof(g_aimbotBody);
    add(g_aimbotBody, size, "\y仿 Aimbot 設定^n^n");
    add(g_aimbotBody, size, "\r1. \w狀態: %s^n");
    add(g_aimbotBody, size, "\r2. \w鎖定模式: \y%s^n");
    add(g_aimbotBody, size, "^n\r0. \w返回");
    g_aimbotKeys = B1 | B2 | B0;
}

public cmd_special_menu(id)
{
    if (!is_user_connected(id)) {
        return PLUGIN_HANDLED;
    }

    show_main_menu(id);
    return PLUGIN_HANDLED;
}

show_main_menu(id)
{
    new menu[384];
    new aimbot[16], magicCircle[16];

    copy(aimbot, charsmax(aimbot), fake_aimbot_get(id) ? "\y開啟" : "\r關閉");
    copy(magicCircle, charsmax(magicCircle), magic_circle_get(id) ? "\y開啟" : "\r關閉");

    formatex(menu, charsmax(menu), g_mainBody, aimbot, magicCircle);
    show_menu(id, g_mainKeys, menu, -1, "special_main_menu");
}

show_aimbot_menu(id)
{
    new menu[256];
    new enabled[16], aimMode[32];

    copy(enabled, charsmax(enabled), fake_aimbot_get(id) ? "\y開啟" : "\r關閉");
    copy(aimMode, charsmax(aimMode), fake_aimbot_get_mode(id) == AIM_MODE_FIRE ? "開火時" : "持續鎖定");

    formatex(menu, charsmax(menu), g_aimbotBody, enabled, aimMode);
    show_menu(id, g_aimbotKeys, menu, -1, "special_aimbot_menu");
}

public handle_main_menu(id, key)
{
    switch (key) {
        case N1: show_aimbot_menu(id);
        case N2: {
            magic_circle_toggle(id);
            show_main_menu(id);
        }
        case N0: return PLUGIN_HANDLED;
    }

    return PLUGIN_HANDLED;
}

public handle_aimbot_menu(id, key)
{
    switch (key) {
        case N1: {
            fake_aimbot_toggle(id);
            show_aimbot_menu(id);
        }
        case N2: {
            fake_aimbot_toggle_mode(id);
            show_aimbot_menu(id);
        }
        case N0: show_main_menu(id);
    }

    return PLUGIN_HANDLED;
}
