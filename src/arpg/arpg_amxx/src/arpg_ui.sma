#include <amxmodx>
#include <engine>

enum AuthAction
{
    Auth_None = 0,
    Auth_Register,
    Auth_Login
}

new bool:g_logged_in[33];
new AuthAction:g_pending_action[33];
new g_pending_user[33][32];
new g_account_name[33][32];

public plugin_init()
{
    register_plugin("Ako ARPG UI", "0.1.0", "Ako");

    register_event("ResetHUD", "event_reset_hud", "be");

    register_clcmd("chooseteam", "cmd_arpg_menu");
    register_clcmd("say /arpg", "cmd_arpg_menu");
    register_clcmd("say_team /arpg", "cmd_arpg_menu");
    register_clcmd("arpg_auth_user", "cmd_auth_user");
    register_clcmd("arpg_auth_pass", "cmd_auth_pass");
}

public client_putinserver(id)
{
    reset_client(id);
    set_task(2.0, "task_apply_camera", id);
}

public client_disconnected(id)
{
    remove_task(id);
    reset_client(id);
}

public event_reset_hud(id)
{
    if (is_user_connected(id))
    {
        set_task(0.25, "task_apply_camera", id);
    }
}

public task_apply_camera(id)
{
    if (!is_user_connected(id))
    {
        return;
    }

    set_view(id, CAMERA_3RDPERSON);
}

public cmd_arpg_menu(id)
{
    if (!is_user_connected(id))
    {
        return PLUGIN_HANDLED;
    }

    if (!g_logged_in[id])
    {
        show_auth_menu(id);
        return PLUGIN_HANDLED;
    }

    show_main_menu(id);
    return PLUGIN_HANDLED;
}

public cmd_auth_user(id)
{
    if (!is_user_connected(id))
    {
        return PLUGIN_HANDLED;
    }

    read_args(g_pending_user[id], charsmax(g_pending_user[]));
    remove_quotes(g_pending_user[id]);
    trim(g_pending_user[id]);

    if (g_pending_user[id][0] == EOS)
    {
        client_print(id, print_center, "Enter an account name.");
        client_cmd(id, "messagemode arpg_auth_user");
        return PLUGIN_HANDLED;
    }

    client_print(id, print_center, "Enter password.");
    client_cmd(id, "messagemode arpg_auth_pass");
    return PLUGIN_HANDLED;
}

public cmd_auth_pass(id)
{
    if (!is_user_connected(id))
    {
        return PLUGIN_HANDLED;
    }

    new password[64];
    read_args(password, charsmax(password));
    remove_quotes(password);
    trim(password);

    if (password[0] == EOS)
    {
        client_print(id, print_center, "Enter a password.");
        client_cmd(id, "messagemode arpg_auth_pass");
        return PLUGIN_HANDLED;
    }

    if (g_pending_action[id] == Auth_None || g_pending_user[id][0] == EOS)
    {
        show_auth_menu(id);
        return PLUGIN_HANDLED;
    }

    copy(g_account_name[id], charsmax(g_account_name[]), g_pending_user[id]);
    g_logged_in[id] = true;
    g_pending_action[id] = Auth_None;
    g_pending_user[id][0] = EOS;

    client_print(id, print_center, "Ako RPG account ready.");
    show_main_menu(id);
    return PLUGIN_HANDLED;
}

show_auth_menu(id)
{
    new menu = menu_create("Ako RPG", "handle_auth_menu");
    menu_additem(menu, "Register", "1");
    menu_additem(menu, "Login", "2");
    menu_additem(menu, "Close", "0");
    menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
    menu_display(id, menu);
}

public handle_auth_menu(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[8];
    new access;
    new callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
    menu_destroy(menu);

    switch (str_to_num(info))
    {
        case 1:
        {
            g_pending_action[id] = Auth_Register;
            g_pending_user[id][0] = EOS;
            client_print(id, print_center, "Choose account name.");
            client_cmd(id, "messagemode arpg_auth_user");
        }
        case 2:
        {
            g_pending_action[id] = Auth_Login;
            g_pending_user[id][0] = EOS;
            client_print(id, print_center, "Enter account name.");
            client_cmd(id, "messagemode arpg_auth_user");
        }
    }

    return PLUGIN_HANDLED;
}

show_main_menu(id)
{
    new title[96];
    formatex(title, charsmax(title), "Ako RPG^nAccount: %s", g_account_name[id]);

    new menu = menu_create(title, "handle_main_menu");
    menu_additem(menu, "Character", "1");
    menu_additem(menu, "Inventory", "2");
    menu_additem(menu, "Skills", "3");
    menu_additem(menu, "Boss", "4");
    menu_addblank(menu, 0);
    menu_additem(menu, "Logout", "9");
    menu_setprop(menu, MPROP_EXITNAME, "Close");
    menu_display(id, menu);
}

public handle_main_menu(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[8];
    new access;
    new callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
    menu_destroy(menu);

    switch (str_to_num(info))
    {
        case 1: client_print(id, print_center, "Character menu is next.");
        case 2: client_print(id, print_center, "Inventory menu is next.");
        case 3: client_print(id, print_center, "Skill menu is next.");
        case 4: client_print(id, print_center, "Boss menu is next.");
        case 9:
        {
            g_logged_in[id] = false;
            g_account_name[id][0] = EOS;
            show_auth_menu(id);
        }
    }

    return PLUGIN_HANDLED;
}

reset_client(id)
{
    g_logged_in[id] = false;
    g_pending_action[id] = Auth_None;
    g_pending_user[id][0] = EOS;
    g_account_name[id][0] = EOS;
}
