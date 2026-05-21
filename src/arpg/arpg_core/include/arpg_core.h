#ifndef ARPG_CORE_H
#define ARPG_CORE_H

#include <cstddef>

#define ARPG_CORE_VERSION 1
#define ARPG_CORE_VERSION_STRING "0.1.0"

namespace arpg
{
bool core_is_enabled();
bool database_initialize(const char *game_dir, const char *relative_path, char *error, std::size_t error_size);
void database_shutdown();
bool database_is_open();
bool database_touch_player(const char *steam_id, const char *name);
bool hooks_initialize();
void hooks_shutdown();
void hooks_start_frame();
}

#endif
