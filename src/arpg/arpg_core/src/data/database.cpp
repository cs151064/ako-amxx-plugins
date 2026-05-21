#include "arpg_core.h"

#include "sqlite3.h"

#include <cstring>
#include <filesystem>
#include <string>

namespace arpg
{
namespace
{
sqlite3 *g_db = nullptr;

void set_error(char *error, std::size_t error_size, const std::string &message)
{
    if (!error || error_size == 0)
    {
        return;
    }

    const std::size_t copy_size = message.size() < error_size - 1 ? message.size() : error_size - 1;
    memcpy(error, message.c_str(), copy_size);
    error[copy_size] = '\0';
}

bool exec_sql(const char *sql, char *error, std::size_t error_size)
{
    char *sqlite_error = nullptr;
    const int result = sqlite3_exec(g_db, sql, nullptr, nullptr, &sqlite_error);
    if (result == SQLITE_OK)
    {
        return true;
    }

    std::string message = sqlite_error ? sqlite_error : sqlite3_errmsg(g_db);
    sqlite3_free(sqlite_error);
    set_error(error, error_size, message);
    return false;
}

bool init_schema(char *error, std::size_t error_size)
{
    static const char *kSchemaSql =
        "PRAGMA journal_mode=WAL;"
        "PRAGMA synchronous=NORMAL;"
        "PRAGMA foreign_keys=ON;"
        "CREATE TABLE IF NOT EXISTS schema_meta ("
        "  key TEXT PRIMARY KEY,"
        "  value TEXT NOT NULL"
        ");"
        "INSERT OR REPLACE INTO schema_meta(key, value) VALUES('schema_version', '1');"
        "CREATE TABLE IF NOT EXISTS players ("
        "  steam_id TEXT PRIMARY KEY,"
        "  display_name TEXT NOT NULL DEFAULT '',"
        "  account_id INTEGER DEFAULT 0,"
        "  is_logged_in INTEGER NOT NULL DEFAULT 0,"
        "  class_id INTEGER NOT NULL DEFAULT 0,"
        "  level INTEGER NOT NULL DEFAULT 1,"
        "  exp INTEGER NOT NULL DEFAULT 0,"
        "  created_at INTEGER NOT NULL DEFAULT (unixepoch()),"
        "  last_seen_at INTEGER NOT NULL DEFAULT (unixepoch())"
        ");"
        "CREATE TABLE IF NOT EXISTS accounts ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  username TEXT NOT NULL UNIQUE,"
        "  password_hash TEXT NOT NULL,"
        "  created_at INTEGER NOT NULL DEFAULT (unixepoch()),"
        "  last_login_at INTEGER NOT NULL DEFAULT 0"
        ");";

    return exec_sql(kSchemaSql, error, error_size);
}
}

bool database_initialize(const char *game_dir, const char *relative_path, char *error, std::size_t error_size)
{
    if (g_db)
    {
        return true;
    }

    if (!game_dir || !relative_path || !game_dir[0] || !relative_path[0])
    {
        set_error(error, error_size, "Invalid database path");
        return false;
    }

    std::filesystem::path db_path = std::filesystem::path(game_dir) / relative_path;
    std::filesystem::create_directories(db_path.parent_path());

    const int open_result = sqlite3_open(db_path.string().c_str(), &g_db);
    if (open_result != SQLITE_OK)
    {
        set_error(error, error_size, sqlite3_errmsg(g_db));
        database_shutdown();
        return false;
    }

    if (!init_schema(error, error_size))
    {
        database_shutdown();
        return false;
    }

    return true;
}

void database_shutdown()
{
    if (!g_db)
    {
        return;
    }

    sqlite3_close(g_db);
    g_db = nullptr;
}

bool database_is_open()
{
    return g_db != nullptr;
}

bool database_touch_player(const char *steam_id, const char *name)
{
    if (!g_db || !steam_id || !steam_id[0])
    {
        return false;
    }

    sqlite3_stmt *stmt = nullptr;
    static const char *kSql =
        "INSERT INTO players(steam_id, display_name, last_seen_at) VALUES(?1, ?2, unixepoch()) "
        "ON CONFLICT(steam_id) DO UPDATE SET "
        "display_name=excluded.display_name, "
        "last_seen_at=unixepoch();";

    if (sqlite3_prepare_v2(g_db, kSql, -1, &stmt, nullptr) != SQLITE_OK)
    {
        return false;
    }

    sqlite3_bind_text(stmt, 1, steam_id, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, name ? name : "", -1, SQLITE_TRANSIENT);

    const bool ok = sqlite3_step(stmt) == SQLITE_DONE;
    sqlite3_finalize(stmt);
    return ok;
}
}
