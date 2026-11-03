#using scripts\common\utility;
#using scripts\common\callbacks;
#using scripts\common\weapon;
#using script_4e3b2b1d9542e66b;

// Kronos custom-script transport. No retail addresses or process hooks.
autoexec codex_solo_trainer_init()
{
    if (isdefined(level.codex_solo_trainer_registered))
        return;
    level.codex_solo_trainer_registered = 1;
    level callback::add(#"player_spawned", &codex_solo_trainer_spawned);
}

codex_solo_trainer_spawned(params)
{
    if (!isdefined(self) || !isplayer(self) || !self ishost())
        return;
    level.codex_trainer_player = self;
    if (isdefined(level.codex_solo_trainer_started))
        return;
    level.codex_solo_trainer_started = 1;
    level thread codex_solo_trainer_loop();
}

codex_solo_trainer_release(player)
{
    codex_solo_trainer_release_ammo(player);
    codex_solo_trainer_release_god(player);
    codex_solo_trainer_viewkick_release(player);
    codex_solo_trainer_rapid_fire_release(player);
    codex_solo_trainer_damage_release(player);
    codex_solo_trainer_game_speed_release();
    codex_solo_trainer_fov_release(player);
    codex_solo_trainer_move_speed_release(player);
}

codex_solo_trainer_release_god(player)
{
    codex_solo_trainer_god_gate_release();
}

codex_solo_trainer_release_ammo(player)
{
    if (isdefined(player) && isplayer(player) && isdefined(player.codex_trainer_ammo_owned))
    {
        if (player.codex_trainer_ammo_owned)
            player setinfiniteammo(0);
        player.codex_trainer_ammo_owned = 0;
    }
}

codex_solo_trainer_loop()
{
    codex_trainer_actions_init();
    codex_solo_trainer_god_gate_init();
    codex_solo_trainer_equipment_init();
    codex_solo_trainer_damage_init();
    codex_solo_trainer_game_speed_init();
    codex_solo_trainer_move_speed_init();
    level.codex_trainer_jetpack = 0;
    level.codex_trainer_jetpack_value = 30000;
    level.codex_trainer_jetpack_ticks = 0;
    level.codex_trainer_move_speed = 0;
    level.codex_trainer_move_speed_value = 150;
    level.codex_trainer_game_speed = 0;
    level.codex_trainer_game_speed_value = 100;
    level.codex_trainer_fov = 0;
    level.codex_trainer_fov_value = 10000;
    level.codex_trainer_damage = 0;
    level.codex_trainer_damage_multiplier = 0;
    level.codex_trainer_damage_multiplier_value = 200;
    level.codex_trainer_owner = undefined;
    level.codex_trainer_session = "";
    level.codex_trainer_lastlease = 0;
    level.codex_trainer_revision = 0;
    level.codex_trainer_leaseage = 100;
    level.codex_trainer_fresh = 0;
    level.codex_trainer_valid = 0;
    level.codex_trainer_ammo = 0;
    level.codex_trainer_no_reload = 0;
    level.codex_trainer_godmode = 0;
    level.codex_trainer_no_recoil = 0;
    level.codex_trainer_rapid_fire = 0;
    level.codex_trainer_points_nonce = 0;
    level.codex_trainer_last_points_nonce = 0;
    level.codex_trainer_points_amount = 10000;
    level.codex_trainer_points_result = "none";
    level.codex_trainer_tick = 0;
    level.codex_trainer_io_count = 9;
    // Only simulation time advances this loop; 100 waits = 5 seconds.
    for (;;)
    {
        level.codex_trainer_io_count = level.codex_trainer_io_count + 1;
        level.codex_trainer_io_tick = 0;
        if (level.codex_trainer_io_count >= 10)
        {
            level.codex_trainer_io_count = 0;
            level.codex_trainer_io_tick = 1;
        }
        if (level.codex_trainer_leaseage < 100)
            level.codex_trainer_leaseage = level.codex_trainer_leaseage + 1;
        if (level.codex_trainer_io_tick)
        {
            level.codex_trainer_valid = 0;
            if (nengine_store_load("codexcmd", "command"))
            {
                level.codex_trainer_protocol = nengine_store_get("codexcmd", "protocol");
                level.codex_trainer_incoming_session = nengine_store_get("codexcmd", "session");
                level.codex_trainer_incoming_lease = nengine_store_get("codexcmd", "lease");
                level.codex_trainer_incoming_revision = nengine_store_get("codexcmd", "revision");
                level.codex_trainer_incoming_ammo = nengine_store_get("codexcmd", "ammo");
                level.codex_trainer_incoming_no_reload = nengine_store_get("codexcmd", "no_reload");
                level.codex_trainer_incoming_godmode = nengine_store_get("codexcmd", "godmode");
                level.codex_trainer_incoming_no_recoil = nengine_store_get("codexcmd", "no_recoil");
                level.codex_trainer_incoming_rapid_fire = nengine_store_get("codexcmd", "rapid_fire");
                level.codex_trainer_incoming_game_speed = nengine_store_get("codexcmd", "game_speed");
                level.codex_trainer_incoming_game_speed_value = nengine_store_get("codexcmd", "game_speed_value");
                level.codex_trainer_incoming_fov = nengine_store_get("codexcmd", "fov");
                level.codex_trainer_incoming_fov_value = nengine_store_get("codexcmd", "fov_value");
                level.codex_trainer_incoming_jetpack = nengine_store_get("codexcmd", "jetpack");
                level.codex_trainer_incoming_jetpack_value = nengine_store_get("codexcmd", "jetpack_value");
                level.codex_trainer_incoming_move_speed = nengine_store_get("codexcmd", "move_speed");
                level.codex_trainer_incoming_move_speed_value = nengine_store_get("codexcmd", "move_speed_value");
                level.codex_trainer_incoming_damage = nengine_store_get("codexcmd", "damage");
                level.codex_trainer_incoming_damage_multiplier = nengine_store_get("codexcmd", "damage_multiplier");
                level.codex_trainer_incoming_damage_multiplier_value = nengine_store_get("codexcmd", "damage_multiplier_value");
                level.codex_trainer_incoming_equipment = nengine_store_get("codexcmd", "equipment");
                level.codex_trainer_incoming_field_upgrade = nengine_store_get("codexcmd", "field_upgrade");
                level.codex_trainer_incoming_points_nonce = nengine_store_get("codexcmd", "points_nonce");
                level.codex_trainer_incoming_points_amount = nengine_store_get("codexcmd", "points_amount");
                level.codex_trainer_incoming_action_nonce = nengine_store_get("codexcmd", "action_nonce");
                level.codex_trainer_incoming_action_kind = nengine_store_get("codexcmd", "action_kind");
                level.codex_trainer_incoming_action_value = nengine_store_get("codexcmd", "action_value");
                level.codex_trainer_incoming_action_level = nengine_store_get("codexcmd", "action_level");
                if (isint(level.codex_trainer_protocol) && level.codex_trainer_protocol == 5
                    && isint(level.codex_trainer_incoming_action_nonce) && level.codex_trainer_incoming_action_nonce >= 0
                    && isstring(level.codex_trainer_incoming_action_kind)
                    && isstring(level.codex_trainer_incoming_action_value)
                    && isint(level.codex_trainer_incoming_action_level) && level.codex_trainer_incoming_action_level >= 0 && level.codex_trainer_incoming_action_level <= 3
                    && isstring(level.codex_trainer_incoming_session) && level.codex_trainer_incoming_session != ""
                    && isint(level.codex_trainer_incoming_lease) && level.codex_trainer_incoming_lease > 0
                    && isint(level.codex_trainer_incoming_revision) && level.codex_trainer_incoming_revision >= 0
                    && isint(level.codex_trainer_incoming_ammo) && (level.codex_trainer_incoming_ammo == 0 || level.codex_trainer_incoming_ammo == 1)
                    && isint(level.codex_trainer_incoming_no_reload) && (level.codex_trainer_incoming_no_reload == 0 || level.codex_trainer_incoming_no_reload == 1)
                    && isint(level.codex_trainer_incoming_godmode) && (level.codex_trainer_incoming_godmode == 0 || level.codex_trainer_incoming_godmode == 1)
                    && isint(level.codex_trainer_incoming_no_recoil) && (level.codex_trainer_incoming_no_recoil == 0 || level.codex_trainer_incoming_no_recoil == 1)
                    && isint(level.codex_trainer_incoming_rapid_fire) && (level.codex_trainer_incoming_rapid_fire == 0 || level.codex_trainer_incoming_rapid_fire == 1)
                    && isint(level.codex_trainer_incoming_game_speed) && (level.codex_trainer_incoming_game_speed == 0 || level.codex_trainer_incoming_game_speed == 1)
                    && isint(level.codex_trainer_incoming_game_speed_value) && level.codex_trainer_incoming_game_speed_value >= 20 && level.codex_trainer_incoming_game_speed_value <= 500
                    && isint(level.codex_trainer_incoming_fov) && (level.codex_trainer_incoming_fov == 0 || level.codex_trainer_incoming_fov == 1)
                    && isint(level.codex_trainer_incoming_fov_value) && level.codex_trainer_incoming_fov_value >= 6000 && level.codex_trainer_incoming_fov_value <= 11000
                    && isint(level.codex_trainer_incoming_jetpack) && (level.codex_trainer_incoming_jetpack == 0 || level.codex_trainer_incoming_jetpack == 1)
                    && isint(level.codex_trainer_incoming_jetpack_value) && level.codex_trainer_incoming_jetpack_value >= 15000 && level.codex_trainer_incoming_jetpack_value <= 80000
                    && isint(level.codex_trainer_incoming_move_speed) && (level.codex_trainer_incoming_move_speed == 0 || level.codex_trainer_incoming_move_speed == 1)
                    && isint(level.codex_trainer_incoming_move_speed_value) && level.codex_trainer_incoming_move_speed_value >= 50 && level.codex_trainer_incoming_move_speed_value <= 500
                    && isint(level.codex_trainer_incoming_damage) && (level.codex_trainer_incoming_damage == 0 || level.codex_trainer_incoming_damage == 1)
                    && isint(level.codex_trainer_incoming_damage_multiplier) && (level.codex_trainer_incoming_damage_multiplier == 0 || level.codex_trainer_incoming_damage_multiplier == 1)
                    && isint(level.codex_trainer_incoming_damage_multiplier_value) && level.codex_trainer_incoming_damage_multiplier_value >= 100 && level.codex_trainer_incoming_damage_multiplier_value <= 5000
                    && isint(level.codex_trainer_incoming_equipment) && (level.codex_trainer_incoming_equipment == 0 || level.codex_trainer_incoming_equipment == 1)
                    && isint(level.codex_trainer_incoming_field_upgrade) && (level.codex_trainer_incoming_field_upgrade == 0 || level.codex_trainer_incoming_field_upgrade == 1)
                    && isint(level.codex_trainer_incoming_points_nonce) && level.codex_trainer_incoming_points_nonce >= 0
                    && isint(level.codex_trainer_incoming_points_amount) && level.codex_trainer_incoming_points_amount >= 1 && level.codex_trainer_incoming_points_amount <= 999999)
                {
                    level.codex_trainer_valid = 1;
                    if (level.codex_trainer_session != level.codex_trainer_incoming_session)
                    {
                        if (isdefined(level.codex_trainer_owner))
                            level.codex_trainer_owner notify(#"codex_action_cancel");
                        level.codex_trainer_action_busy = 0;
                        level.codex_trainer_last_action_nonce = level.codex_trainer_incoming_action_nonce;
                        level.codex_trainer_action_result = "none";
                        level.codex_trainer_action_detail = "";
                        // First snapshot of each controller level.codex_trainer_session is only a baseline.
                        level.codex_trainer_session = level.codex_trainer_incoming_session;
                        level.codex_trainer_lastlease = level.codex_trainer_incoming_lease;
                        level.codex_trainer_leaseage = 100;
                        level.codex_trainer_fresh = 0;
                        level.codex_trainer_last_points_nonce = level.codex_trainer_incoming_points_nonce;
                        level.codex_trainer_points_result = "none";
                    }
                    else if (level.codex_trainer_incoming_lease > level.codex_trainer_lastlease)
                    {
                        level.codex_trainer_lastlease = level.codex_trainer_incoming_lease;
                        level.codex_trainer_leaseage = 0;
                        level.codex_trainer_fresh = 1;
                    }
                    else if (level.codex_trainer_incoming_lease < level.codex_trainer_lastlease)
                    {
                        level.codex_trainer_valid = 0;
                        level.codex_trainer_fresh = 0;
                        level.codex_trainer_leaseage = 100;
                    }
                    level.codex_trainer_action_nonce = level.codex_trainer_incoming_action_nonce;
                    level.codex_trainer_action_kind = level.codex_trainer_incoming_action_kind;
                    level.codex_trainer_action_value = level.codex_trainer_incoming_action_value;
                    level.codex_trainer_action_level = level.codex_trainer_incoming_action_level;
                    level.codex_trainer_revision = level.codex_trainer_incoming_revision;
                    level.codex_trainer_ammo = level.codex_trainer_incoming_ammo;
                    level.codex_trainer_no_reload = level.codex_trainer_incoming_no_reload;
                    level.codex_trainer_godmode = level.codex_trainer_incoming_godmode;
                    level.codex_trainer_no_recoil = level.codex_trainer_incoming_no_recoil;
                    level.codex_trainer_rapid_fire = level.codex_trainer_incoming_rapid_fire;
                    level.codex_trainer_game_speed = level.codex_trainer_incoming_game_speed;
                    level.codex_trainer_game_speed_value = level.codex_trainer_incoming_game_speed_value;
                    level.codex_trainer_fov = level.codex_trainer_incoming_fov;
                    level.codex_trainer_fov_value = level.codex_trainer_incoming_fov_value;
                    level.codex_trainer_jetpack = level.codex_trainer_incoming_jetpack;
                    level.codex_trainer_jetpack_value = level.codex_trainer_incoming_jetpack_value;
                    level.codex_trainer_move_speed = level.codex_trainer_incoming_move_speed;
                    level.codex_trainer_move_speed_value = level.codex_trainer_incoming_move_speed_value;
                    level.codex_trainer_damage = level.codex_trainer_incoming_damage;
                    level.codex_trainer_damage_multiplier = level.codex_trainer_incoming_damage_multiplier;
                    level.codex_trainer_damage_multiplier_value = level.codex_trainer_incoming_damage_multiplier_value;
                    level.codex_trainer_equipment = level.codex_trainer_incoming_equipment;
                    level.codex_trainer_field_upgrade = level.codex_trainer_incoming_field_upgrade;
                    level.codex_trainer_points_nonce = level.codex_trainer_incoming_points_nonce;
                    level.codex_trainer_points_amount = level.codex_trainer_incoming_points_amount;
                }
            }
        }

        level.codex_trainer_count = 0;
        level.codex_trainer_candidate = level.codex_trainer_player;
        if (isdefined(level.players))
            level.codex_trainer_count = level.players.size;

        level.codex_trainer_reason = "ready";
        level.codex_trainer_ready = 1;
        if (level.codex_trainer_game_speed_ended)
        {
            level.codex_trainer_ready = 0;
            level.codex_trainer_reason = "match_ended";
        }
        else if (!utility::iszm())
        {
            level.codex_trainer_ready = 0;
            level.codex_trainer_reason = "zombies_required";
        }
        else if (level.codex_trainer_count == 0)
        {
            level.codex_trainer_ready = 0;
            level.codex_trainer_reason = "waiting_player";
        }
        else if (level.codex_trainer_count != 1)
        {
            level.codex_trainer_ready = 0;
            level.codex_trainer_reason = "solo_required";
        }
        else if (!isdefined(level.codex_trainer_candidate) || !isplayer(level.codex_trainer_candidate))
        {
            level.codex_trainer_ready = 0;
            level.codex_trainer_reason = "waiting_player";
        }
        else if (!level.codex_trainer_candidate ishost())
        {
            level.codex_trainer_ready = 0;
            level.codex_trainer_reason = "host_required";
        }
        else if (!isalive(level.codex_trainer_candidate) || !isdefined(level.codex_trainer_candidate.sessionstate) || level.codex_trainer_candidate.sessionstate != "playing")
        {
            level.codex_trainer_ready = 0;
            level.codex_trainer_reason = "waiting_player";
        }
        else if (!level.codex_trainer_valid || !level.codex_trainer_fresh || level.codex_trainer_leaseage >= 100)
        {
            level.codex_trainer_ready = 0;
            level.codex_trainer_reason = "lease_expired";
        }

        if (isdefined(level.codex_trainer_owner))
        {
            if (!level.codex_trainer_ready || !isdefined(level.codex_trainer_candidate) || level.codex_trainer_owner != level.codex_trainer_candidate)
            {
                codex_solo_trainer_release(level.codex_trainer_owner);
                level.codex_trainer_equipment_countdown = 0;
                level.codex_trainer_equipment_applied = 0;
                level.codex_trainer_field_countdown = 0;
                level.codex_trainer_field_upgrade_applied = 0;
                level.codex_trainer_owner = undefined;
            }
        }

        level.codex_trainer_ammo_applied = 0;
        level.codex_trainer_clip_applied = 0;
        level.codex_trainer_clip = -1;
        level.codex_trainer_stock = -1;
        level.codex_trainer_god_applied = 0;
        level.codex_trainer_god_available = 0;
        level.codex_trainer_god_flag = 0;
        level.codex_trainer_god_field_defined = 0;
        level.codex_trainer_god_damage_value = -1;
        level.codex_trainer_no_recoil_applied = 0;
        level.codex_trainer_no_recoil_available = 0;
        level.codex_trainer_rapid_fire_applied = 0;
        level.codex_trainer_rapid_fire_available = 0;
        level.codex_trainer_damage_applied = 0;
        level.codex_trainer_damage_multiplier_applied = 0;
        level.codex_trainer_damage_available = 0;
        level.codex_trainer_game_speed_applied = 0;
        level.codex_trainer_game_speed_available = 0;
        level.codex_trainer_fov_applied = 0;
        level.codex_trainer_fov_available = 0;
        level.codex_trainer_move_speed_applied = 0;
        level.codex_trainer_move_speed_available = 0;
        level.codex_trainer_jetpack_applied = 0;
        level.codex_trainer_jetpack_available = 0;
        level.codex_trainer_jetpack_thrust = 0;
        level.codex_trainer_jetpack_z = 0;
        level.codex_trainer_jetpack_x = 0;
        level.codex_trainer_jetpack_y = 0;
        level.codex_trainer_jetpack_forward = 0;
        level.codex_trainer_jetpack_right = 0;
        level.codex_trainer_points_available = 0;
        level.codex_trainer_health = -1;
        level.codex_trainer_essence = -1;
        if (level.codex_trainer_ready)
        {
            level.codex_trainer_owner = level.codex_trainer_candidate;
            codex_solo_trainer_viewkick_update();
            codex_solo_trainer_rapid_fire_update();
            codex_solo_trainer_damage_apply(level.codex_trainer_owner);
            codex_solo_trainer_game_speed_apply();
            codex_solo_trainer_fov_update();
            codex_solo_trainer_move_speed_apply(level.codex_trainer_owner);
            codex_solo_trainer_jetpack_apply(level.codex_trainer_owner);
            if (level.codex_trainer_ammo == 1)
            {
                level.codex_trainer_owner setinfiniteammo(1);
                level.codex_trainer_owner.codex_trainer_ammo_owned = 1;
                level.codex_trainer_ammo_applied = 1;
            }
            else
                codex_solo_trainer_release_ammo(level.codex_trainer_owner);

            if (isdefined(level.var_c998633bab11f3f8) && level.var_c998633bab11f3f8)
                level.codex_trainer_god_flag = 1;
            if (isdefined(level.codex_trainer_owner.takedamage))
            {
                level.codex_trainer_god_field_defined = 1;
                if (isint(level.codex_trainer_owner.takedamage) || isfloat(level.codex_trainer_owner.takedamage))
                    level.codex_trainer_god_damage_value = level.codex_trainer_owner.takedamage;
            }
            codex_solo_trainer_god_gate_apply(level.codex_trainer_owner);
            if (isdefined(level.codex_trainer_owner.health) && isint(level.codex_trainer_owner.health))
                level.codex_trainer_health = level.codex_trainer_owner.health;

            if (isdefined(level.var_9e5c1a9e0a29d3ce) && isdefined(level.var_9e5c1a9e0a29d3ce[#"points"])
                && utility::issharedfuncdefined(#"points", #"get_points")
                && utility::issharedfuncdefined(#"points", #"add_points"))
            {
                level.codex_trainer_points_available = 1;
                level.codex_trainer_essence = level.codex_trainer_owner utility::callsharedfunc(#"points", #"get_points");
            }
            if (level.codex_trainer_points_nonce > 0 && level.codex_trainer_points_nonce > level.codex_trainer_last_points_nonce)
            {
                // Consume once, even if unavailable; heartbeat never repeats a grant.
                level.codex_trainer_last_points_nonce = level.codex_trainer_points_nonce;
                level.codex_trainer_points_result = "unavailable";
                if (level.codex_trainer_points_available && isint(level.codex_trainer_essence)
                    && level.codex_trainer_essence >= 0 && level.codex_trainer_essence <= 2147483647 - level.codex_trainer_points_amount)
                {
                    level.codex_trainer_owner utility::callsharedfunc(#"points", #"add_points", level.codex_trainer_points_amount);
                    level.codex_trainer_essence = level.codex_trainer_owner utility::callsharedfunc(#"points", #"get_points");
                    level.codex_trainer_points_result = "applied";
                }
            }

            level.codex_trainer_weapon = level.codex_trainer_owner getcurrentweapon();
            if (isdefined(level.codex_trainer_weapon) && !isnullweapon(level.codex_trainer_weapon))
            {
                if (level.codex_trainer_no_reload == 1)
                {
                    level.codex_trainer_capacity = weaponclipsize(level.codex_trainer_weapon);
                    if (isdefined(level.codex_trainer_capacity) && level.codex_trainer_capacity > 0)
                    {
                        level.codex_trainer_owner setweaponammoclip(level.codex_trainer_weapon, level.codex_trainer_capacity);
                        level.codex_trainer_clip_applied = 1;
                    }
                }
                if (level.codex_trainer_io_tick)
                {
                    level.codex_trainer_clip = level.codex_trainer_owner getweaponammoclip(level.codex_trainer_weapon);
                    level.codex_trainer_stock = level.codex_trainer_owner getweaponammostock(level.codex_trainer_weapon);
                }
            }
        }

        codex_trainer_actions_poll();
        codex_solo_trainer_equipment();
        codex_solo_trainer_field_upgrade();

        if (level.codex_trainer_io_tick)
        {
            // Acks mean GSC calls returned, not gameplay validation.
            nengine_store_set("codexack", "protocol", 5);
            nengine_store_set("codexack", "action_nonce", level.codex_trainer_last_action_nonce);
            nengine_store_set("codexack", "action_result", level.codex_trainer_action_result);
            nengine_store_set("codexack", "action_detail", level.codex_trainer_action_detail);
            nengine_store_set("codexack", "weapon_requested", level.codex_trainer_weapon_requested);
            nengine_store_set("codexack", "weapon_resolved", level.codex_trainer_weapon_resolved);
            nengine_store_set("codexack", "game_time", gettime());
            nengine_store_set("codexack", "game_speed_current", level.codex_trainer_game_speed_current);
            nengine_store_set("codexack", "current_weapon", level.codex_trainer_weapon_name);
            nengine_store_set("codexack", "pap_level", level.codex_trainer_pap_level);
            nengine_store_set("codexack", "ammo_mod", level.codex_trainer_ammo_mod_name);
            nengine_store_set("codexack", "session", level.codex_trainer_session);
            nengine_store_set("codexack", "lease", level.codex_trainer_lastlease);
            nengine_store_set("codexack", "revision", level.codex_trainer_revision);
            nengine_store_set("codexack", "ready", level.codex_trainer_ready);
            nengine_store_set("codexack", "players", level.codex_trainer_count);
            nengine_store_set("codexack", "ammo", level.codex_trainer_ammo_applied);
            nengine_store_set("codexack", "no_reload", level.codex_trainer_clip_applied);
            nengine_store_set("codexack", "godmode", level.codex_trainer_god_applied);
            nengine_store_set("codexack", "god_available", level.codex_trainer_god_available);
            nengine_store_set("codexack", "god_flag", level.codex_trainer_god_flag);
            nengine_store_set("codexack", "god_field_defined", level.codex_trainer_god_field_defined);
            nengine_store_set("codexack", "god_damage_value", level.codex_trainer_god_damage_value);
            nengine_store_set("codexack", "god_blocks", level.codex_trainer_god_blocks);
            nengine_store_set("codexack", "god_gate_calls", level.codex_trainer_god_gate_calls);
            nengine_store_set("codexack", "god_last_damage", level.codex_trainer_god_last_damage);
            nengine_store_set("codexack", "god_last_health", level.codex_trainer_god_last_health);
            nengine_store_set("codexack", "godmode_conflict", level.codex_trainer_god_gate_conflict);
            nengine_store_set("codexack", "no_recoil", level.codex_trainer_no_recoil_applied);
            nengine_store_set("codexack", "no_recoil_available", level.codex_trainer_no_recoil_available);
            nengine_store_set("codexack", "rapid_fire", level.codex_trainer_rapid_fire_applied);
            nengine_store_set("codexack", "rapid_fire_available", level.codex_trainer_rapid_fire_available);
            nengine_store_set("codexack", "game_speed", level.codex_trainer_game_speed_applied);
            nengine_store_set("codexack", "game_speed_available", level.codex_trainer_game_speed_available);
            nengine_store_set("codexack", "game_speed_conflict", level.codex_trainer_game_speed_conflict);
            nengine_store_set("codexack", "fov", level.codex_trainer_fov_applied);
            nengine_store_set("codexack", "fov_available", level.codex_trainer_fov_available);
            nengine_store_set("codexack", "jetpack", level.codex_trainer_jetpack_applied);
            nengine_store_set("codexack", "jetpack_available", level.codex_trainer_jetpack_available);
            nengine_store_set("codexack", "jetpack_thrust", level.codex_trainer_jetpack_thrust);
            nengine_store_set("codexack", "jetpack_ticks", level.codex_trainer_jetpack_ticks);
            nengine_store_set("codexack", "jetpack_z", level.codex_trainer_jetpack_z);
            nengine_store_set("codexack", "jetpack_x", level.codex_trainer_jetpack_x);
            nengine_store_set("codexack", "jetpack_y", level.codex_trainer_jetpack_y);
            nengine_store_set("codexack", "jetpack_forward", level.codex_trainer_jetpack_forward);
            nengine_store_set("codexack", "jetpack_right", level.codex_trainer_jetpack_right);
            nengine_store_set("codexack", "move_speed", level.codex_trainer_move_speed_applied);
            nengine_store_set("codexack", "move_speed_available", level.codex_trainer_move_speed_available);
            nengine_store_set("codexack", "move_speed_conflict", level.codex_trainer_move_speed_conflict);
            nengine_store_set("codexack", "damage", level.codex_trainer_damage_applied);
            nengine_store_set("codexack", "damage_multiplier", level.codex_trainer_damage_multiplier_applied);
            nengine_store_set("codexack", "damage_available", level.codex_trainer_damage_available);
            nengine_store_set("codexack", "damage_multiplier_available", level.codex_trainer_damage_available);
            nengine_store_set("codexack", "damage_hits", level.codex_trainer_damage_hits);
            nengine_store_set("codexack", "damage_last_in", level.codex_trainer_damage_last_in);
            nengine_store_set("codexack", "damage_last_out", level.codex_trainer_damage_last_out);
            nengine_store_set("codexack", "points_available", level.codex_trainer_points_available);
            nengine_store_set("codexack", "equipment", level.codex_trainer_equipment_applied);
            nengine_store_set("codexack", "equipment_available", level.codex_trainer_equipment_available);
            nengine_store_set("codexack", "equipment_items", level.codex_trainer_equipment_items);
            nengine_store_set("codexack", "field_upgrade", level.codex_trainer_field_upgrade_applied);
            nengine_store_set("codexack", "field_upgrade_available", level.codex_trainer_field_upgrade_available);
            nengine_store_set("codexack", "health", level.codex_trainer_health);
            nengine_store_set("codexack", "essence", level.codex_trainer_essence);
            nengine_store_set("codexack", "points_nonce", level.codex_trainer_last_points_nonce);
            nengine_store_set("codexack", "points_result", level.codex_trainer_points_result);
            nengine_store_set("codexack", "clip", level.codex_trainer_clip);
            nengine_store_set("codexack", "stock", level.codex_trainer_stock);
            nengine_store_set("codexack", "tick", level.codex_trainer_tick);
            nengine_store_set("codexack", "reason", level.codex_trainer_reason);
            nengine_store_save("codexack", "status");
        }
        wait 0.05;
        level.codex_trainer_tick = level.codex_trainer_tick + 1;
    }
}


// Integrate into the existing guarded Solo loop, not a separate thread.
// Call _init once. Set *_equipment and *_field_upgrade from validated 0/1 commands.
// Call equipment()/field_upgrade() on each 0.05-second simulation iteration
// AFTER ready/owner resolution. Both helpers independently check ready too.
codex_solo_trainer_equipment_init()
{
    level.codex_trainer_equipment = 0;
    level.codex_trainer_field_upgrade = 0;
    level.codex_trainer_equipment_countdown = 0;
    level.codex_trainer_field_countdown = 0;
    level.codex_trainer_equipment_applied = 0;
    level.codex_trainer_equipment_available = 0;
    level.codex_trainer_equipment_items = 0;
    level.codex_trainer_field_upgrade_applied = 0;
    level.codex_trainer_field_upgrade_available = 0;
}

codex_solo_trainer_equipment()
{
    if (!level.codex_trainer_ready || !isdefined(level.codex_trainer_owner))
    {
        level.codex_trainer_equipment_applied = 0;
        level.codex_trainer_equipment_available = 0;
        level.codex_trainer_equipment_items = 0;
        level.codex_trainer_equipment_countdown = 0;
        return;
    }

    if (level.codex_trainer_equipment != 1)
    {
        level.codex_trainer_equipment_applied = 0;
        level.codex_trainer_equipment_countdown = 0;
    }
    else if (level.codex_trainer_equipment_countdown <= 0)
    {
        level.codex_trainer_equipment_countdown = 4;
        level.codex_trainer_equipment_applied = 0;
        level.codex_trainer_equipment_available = 0;
        level.codex_trainer_equipment_items = 0;
        level.codex_trainer_offhands = level.codex_trainer_owner getweaponslistoffhands();
        if (isdefined(level.codex_trainer_offhands))
        {
            level.codex_trainer_offhand_index = 0;
            while (level.codex_trainer_offhand_index < level.codex_trainer_offhands.size)
            {
                level.codex_trainer_offhand = level.codex_trainer_offhands[level.codex_trainer_offhand_index];
                if (isdefined(level.codex_trainer_offhand) && !isnullweapon(level.codex_trainer_offhand))
                {
                    level.codex_trainer_equipment_available = 1;
                    level.codex_trainer_owner givemaxammo(level.codex_trainer_offhand);
                    level.codex_trainer_equipment_items = level.codex_trainer_equipment_items + 1;
                    level.codex_trainer_equipment_applied = 1;
                }
                level.codex_trainer_offhand_index = level.codex_trainer_offhand_index + 1;
            }
        }
        level.codex_trainer_offhands = undefined;
        level.codex_trainer_offhand = undefined;
    }
    if (level.codex_trainer_equipment_countdown > 0)
        level.codex_trainer_equipment_countdown = level.codex_trainer_equipment_countdown - 1;
}

codex_solo_trainer_field_upgrade()
{
    if (!level.codex_trainer_ready || !isdefined(level.codex_trainer_owner))
    {
        level.codex_trainer_field_upgrade_applied = 0;
        level.codex_trainer_field_upgrade_available = 0;
        level.codex_trainer_field_countdown = 0;
        return;
    }
    level.codex_trainer_field_upgrade_available = 0;
    if (isdefined(level.var_9e5c1a9e0a29d3ce) && isdefined(level.var_9e5c1a9e0a29d3ce[#"full_power"])
        && utility::issharedfuncdefined(#"full_power", #"give_power"))
        level.codex_trainer_field_upgrade_available = 1;
    if (level.codex_trainer_field_upgrade != 1 || !level.codex_trainer_field_upgrade_available)
    {
        level.codex_trainer_field_upgrade_applied = 0;
        level.codex_trainer_field_countdown = 0;
    }
    else if (level.codex_trainer_field_countdown <= 0)
    {
        level.codex_trainer_field_countdown = 20;
        level.codex_trainer_owner utility::callsharedfunc(#"full_power", #"give_power");
        level.codex_trainer_field_upgrade_applied = 1;
    }
    if (level.codex_trainer_field_countdown > 0)
        level.codex_trainer_field_countdown = level.codex_trainer_field_countdown - 1;
}

// No inventory/charge rollback: OFF stops refilling, preserving legitimately
// acquired/consumed stock and charge. No persistent native flag is changed.
// *_applied=1 only means a supported call returned for the current scope.
// Field Upgrade's underlying wrapper can return early while the ability is active.

// Candidate helper for the existing Kronos Solo scope/lease loop.
// Static contract: native getter and setter read/write the same float.
// No live gameplay validation yet. This changes view kick, not weapon spread.
// Integration: call update only after owner/scope validation; call release
// with the old owner from every OFF, owner-change and lease/scope-loss path.
// Requested field: level.codex_trainer_no_recoil (0/1).
// Reset applied/available before owner validation each tick if called conditionally.

codex_solo_trainer_viewkick_update()
{
    level.codex_trainer_no_recoil_applied = 0;
    level.codex_trainer_no_recoil_available = 0;
    if (!isdefined(level.codex_trainer_owner) || !isplayer(level.codex_trainer_owner))
        return;

    level.codex_trainer_viewkick_current = level.codex_trainer_owner getviewkickscale();
    if (isdefined(level.codex_trainer_viewkick_current) && level.codex_trainer_viewkick_current >= 0)
        level.codex_trainer_no_recoil_available = 1;

    if (level.codex_trainer_no_recoil == 1 && level.codex_trainer_no_recoil_available)
    {
        if (!isdefined(level.codex_trainer_owner.codex_trainer_viewkick_owned) || !level.codex_trainer_owner.codex_trainer_viewkick_owned)
        {
            level.codex_trainer_owner.codex_trainer_viewkick_before = level.codex_trainer_viewkick_current;
            level.codex_trainer_owner.codex_trainer_viewkick_owned = 1;
        }
        else if (level.codex_trainer_viewkick_current != 0)
            level.codex_trainer_owner.codex_trainer_viewkick_before = level.codex_trainer_viewkick_current;
        level.codex_trainer_owner setviewkickscale(0.0);
        level.codex_trainer_viewkick_current = level.codex_trainer_owner getviewkickscale();
        if (isdefined(level.codex_trainer_viewkick_current) && level.codex_trainer_viewkick_current == 0)
            level.codex_trainer_no_recoil_applied = 1;
    }
    else
        codex_solo_trainer_viewkick_release(level.codex_trainer_owner);
}

codex_solo_trainer_viewkick_release(player)
{
    if (isdefined(player) && isplayer(player) && isdefined(player.codex_trainer_viewkick_owned) && player.codex_trainer_viewkick_owned)
    {
        // Avoid overwriting an intervening value set by another game system.
        // Native getter returns a float; saved value comes only from that getter.
        if (isdefined(player.codex_trainer_viewkick_before) && player.codex_trainer_viewkick_before >= 0 && player getviewkickscale() == 0)
            player setviewkickscale(player.codex_trainer_viewkick_before);
        player.codex_trainer_viewkick_owned = 0;
        player.codex_trainer_viewkick_before = undefined;
    }
}



// Static candidate for integration into codex_solo_trainer.gsc. Not installed.
// Caller supplies level.codex_trainer_damage (0/1),
// level.codex_trainer_damage_multiplier (0/1), and
// level.codex_trainer_damage_multiplier_value (100..5000 percent).
// The main loop owns lease/scope. Call init once, apply(player) while ready,
// release(player) during normal cleanup. Read *_applied and *_available ACKs.
codex_solo_trainer_damage_init()
{
    level.codex_trainer_damage_applied = 0;
    level.codex_trainer_damage_multiplier_applied = 0;
    level.codex_trainer_damage_available = 0;
    level.codex_trainer_damage_factor = 1;
    level.codex_trainer_damage_hits = 0;
    level.codex_trainer_damage_last_in = 0;
    level.codex_trainer_damage_last_out = 0;
}

codex_solo_trainer_damage_available()
{
    return isdefined(level.var_9e5c1a9e0a29d3ce)
        && isdefined(level.var_9e5c1a9e0a29d3ce[#"hash_f56e61560d84261d"])
        && utility::issharedfuncdefined(#"hash_f56e61560d84261d", #"hash_a3d14072d6914a72")
        && utility::issharedfuncdefined(#"hash_f56e61560d84261d", #"hash_632d2cdf31504cf3");
}

codex_solo_trainer_damage_attach(player)
{
    if (!isdefined(player) || !isplayer(player) || !codex_solo_trainer_damage_available())
        return 0;
    if (!isdefined(player.codex_trainer_damage_hook) || !player.codex_trainer_damage_hook)
    {
        player utility::callsharedfunc(#"hash_f56e61560d84261d", #"hash_a3d14072d6914a72", &codex_solo_trainer_damage_callback);
        player.codex_trainer_damage_hook = 1;
    }
    return 1;
}

codex_solo_trainer_damage_apply(player)
{
    level.codex_trainer_damage_applied = 0;
    level.codex_trainer_damage_multiplier_applied = 0;
    level.codex_trainer_damage_available = codex_solo_trainer_damage_available();
    level.codex_trainer_damage_factor = 1;
    if (isdefined(level.codex_trainer_damage_multiplier_value)
        && isint(level.codex_trainer_damage_multiplier_value)
        && level.codex_trainer_damage_multiplier_value >= 100
        && level.codex_trainer_damage_multiplier_value <= 5000)
        level.codex_trainer_damage_factor = level.codex_trainer_damage_multiplier_value / 100.0;
    if (level.codex_trainer_damage_available
        && (level.codex_trainer_damage == 1 || level.codex_trainer_damage_multiplier == 1))
    {
        if (codex_solo_trainer_damage_attach(player))
        {
            level.codex_trainer_damage_applied = level.codex_trainer_damage;
            // One-hit takes priority; report multiplier OFF until it can apply.
            if (level.codex_trainer_damage != 1)
                level.codex_trainer_damage_multiplier_applied = level.codex_trainer_damage_multiplier;
        }
    }
    else
        codex_solo_trainer_damage_release(player);
}

codex_solo_trainer_damage_release(player)
{
    level.codex_trainer_damage_applied = 0;
    level.codex_trainer_damage_multiplier_applied = 0;
    if (isdefined(player) && isplayer(player) && isdefined(player.codex_trainer_damage_hook) && player.codex_trainer_damage_hook)
    {
        if (codex_solo_trainer_damage_available())
        {
            player utility::callsharedfunc(#"hash_f56e61560d84261d", #"hash_632d2cdf31504cf3", &codex_solo_trainer_damage_callback);
            player.codex_trainer_damage_hook = 0;
        }
    }
}

codex_solo_trainer_damage_callback(params)
{
    // The engine invokes this with self=victim, even though registered on owner.
    // Never change other players, another attacker's damage, or a stale session.
    if (!isdefined(level.codex_trainer_ready) || !level.codex_trainer_ready
        || !isdefined(level.codex_trainer_owner) || !isdefined(params)
        || !isdefined(params.eAttacker) || params.eAttacker != level.codex_trainer_owner
        || !isdefined(self) || isplayer(self) || !isalive(self))
        return -1;
    if (!isdefined(level.codex_trainer_count) || level.codex_trainer_count != 1
        || !isdefined(level.codex_trainer_valid) || !level.codex_trainer_valid
        || !isdefined(level.codex_trainer_fresh) || !level.codex_trainer_fresh
        || !isdefined(level.codex_trainer_leaseage) || level.codex_trainer_leaseage >= 100)
        return -1;
    if (!isdefined(params.iDamage) || (!isint(params.iDamage) && !isfloat(params.iDamage)) || params.iDamage <= 0)
        return -1;
    if (isdefined(level.codex_trainer_damage) && level.codex_trainer_damage == 1)
    {
        // Reproduces ordinary Insta-Kill's health-sized damage at the modifier
        // stage. Boss immunity/armor/late callbacks may still alter the result.
        if (isdefined(self.health) && isint(self.health) && self.health > 0 && self.health > params.iDamage)
        {
            codex_solo_trainer_damage_record(params.iDamage, self.health);
            return self.health;
        }
        codex_solo_trainer_damage_record(params.iDamage, params.iDamage);
        return params.iDamage;
    }
    if (isdefined(level.codex_trainer_damage_multiplier) && level.codex_trainer_damage_multiplier == 1
        && isdefined(level.codex_trainer_damage_factor)
        && (isint(level.codex_trainer_damage_factor) || isfloat(level.codex_trainer_damage_factor))
        && level.codex_trainer_damage_factor >= 1 && level.codex_trainer_damage_factor <= 50)
    {
        // Bound before integer conversion. No health write or delayed kill loop.
        if (params.iDamage > 1000000000 / level.codex_trainer_damage_factor)
        {
            codex_solo_trainer_damage_record(params.iDamage, 1000000000);
            return 1000000000;
        }
        codex_solo_trainer_damage_record(params.iDamage, int(params.iDamage * level.codex_trainer_damage_factor));
        return int(params.iDamage * level.codex_trainer_damage_factor);
    }
    return -1;
}

codex_solo_trainer_damage_record(before, after)
{
    if (!isdefined(level.codex_trainer_damage_hits))
        level.codex_trainer_damage_hits = 0;
    level.codex_trainer_damage_hits = level.codex_trainer_damage_hits + 1;
    level.codex_trainer_damage_last_in = before;
    level.codex_trainer_damage_last_out = after;
}

// Kronos Solo candidate: halve the native firing-time scale to 50%.
// Hash calls are native methods observed in shipped global modifier wrapper.
// Native range is integer 1..255, zero is reset and getter reports it as -1.
// Consumer multiplies current weapon timing by byte * 0.01.
// This is not a gameplay benchmark; weapon animations/other limits may remain.
// Integrate update after Solo/player/host/lease guards; release on OFF/scope loss.

codex_solo_trainer_rapid_fire_update()
{
    level.codex_trainer_rapid_fire_applied = 0;
    level.codex_trainer_rapid_fire_available = 0;
    if (!isdefined(level.codex_trainer_owner) || !isplayer(level.codex_trainer_owner))
        return;
    level.codex_trainer_firetime_current = level.codex_trainer_owner getfiretimescale();
    if (isint(level.codex_trainer_firetime_current) && (level.codex_trainer_firetime_current == -1 || (level.codex_trainer_firetime_current >= 1 && level.codex_trainer_firetime_current <= 255)))
        level.codex_trainer_rapid_fire_available = 1;
    if (level.codex_trainer_rapid_fire == 1 && level.codex_trainer_rapid_fire_available)
    {
        if (!isdefined(level.codex_trainer_owner.codex_trainer_firetime_owned) || !level.codex_trainer_owner.codex_trainer_firetime_owned)
        {
            level.codex_trainer_owner.codex_trainer_firetime_before = level.codex_trainer_firetime_current;
            level.codex_trainer_owner.codex_trainer_firetime_owned = 1;
        }
        else if (level.codex_trainer_firetime_current != 50)
            level.codex_trainer_owner.codex_trainer_firetime_before = level.codex_trainer_firetime_current;
        level.codex_trainer_owner function_987f05c69396b6be(50);
        level.codex_trainer_firetime_current = level.codex_trainer_owner getfiretimescale();
        if (isint(level.codex_trainer_firetime_current) && level.codex_trainer_firetime_current == 50)
            level.codex_trainer_rapid_fire_applied = 1;
    }
    else
        codex_solo_trainer_rapid_fire_release(level.codex_trainer_owner);
}

codex_solo_trainer_rapid_fire_release(player)
{
    if (isdefined(player) && isplayer(player) && isdefined(player.codex_trainer_firetime_owned) && player.codex_trainer_firetime_owned)
    {
        // Only restore while the value still matches this trainer's write.
        if (isdefined(player.codex_trainer_firetime_before) && isint(player.codex_trainer_firetime_before) && player getfiretimescale() == 50)
        {
            if (player.codex_trainer_firetime_before == -1)
                player function_f5ed5bb6944d6bc0();
            else if (player.codex_trainer_firetime_before >= 1 && player.codex_trainer_firetime_before <= 255)
                player function_987f05c69396b6be(player.codex_trainer_firetime_before);
        }
        player.codex_trainer_firetime_owned = 0;
        player.codex_trainer_firetime_before = undefined;
    }
}



// Protocol values: game_speed=0/1, game_speed_value=20..500 (percent).
// Use the same common builtin as the original Zombies slow-motion events.
// com_timescale is reset by this runtime and does not change simulation speed.
codex_solo_trainer_game_speed_init()
{
    level.codex_trainer_game_speed_owned = 0;
    level.codex_trainer_game_speed_applied = 0;
    level.codex_trainer_game_speed_available = 0;
    level.codex_trainer_game_speed_before = undefined;
    level.codex_trainer_game_speed_last = undefined;
    level.codex_trainer_game_speed_current = -1;
    level.codex_trainer_game_speed_settle_until = 0;
    level.codex_trainer_game_speed_ended = 0;
    level.codex_trainer_game_speed_conflict = 0;
    if (!isdefined(level.codex_trainer_game_speed_callbacks))
    {
        level.codex_trainer_game_speed_callbacks = 1;
        level callback::add(#"game_ended", &codex_solo_trainer_game_speed_ended);
        level callback::add(#"player_disconnect", &codex_solo_trainer_game_speed_disconnect);
        level thread codex_solo_trainer_game_speed_end_notify();
    }
}

codex_solo_trainer_game_speed_ended(params)
{
    level.codex_trainer_game_speed_ended = 1;
    level.codex_trainer_ready = 0;
    if (isdefined(level.codex_trainer_owner))
        codex_solo_trainer_release(level.codex_trainer_owner);
    codex_solo_trainer_game_speed_release();
}

codex_solo_trainer_game_speed_end_notify()
{
    level waittill(#"game_ended");
    level.codex_trainer_game_speed_ended = 1;
    level.codex_trainer_ready = 0;
    if (isdefined(level.codex_trainer_owner))
        codex_solo_trainer_release(level.codex_trainer_owner);
    codex_solo_trainer_game_speed_release();
}

codex_solo_trainer_game_speed_disconnect(params)
{
    if (isdefined(self) && isdefined(level.codex_trainer_player) && self == level.codex_trainer_player)
    {
        level.codex_trainer_game_speed_ended = 1;
        level.codex_trainer_ready = 0;
        if (isdefined(level.codex_trainer_owner))
            codex_solo_trainer_release(level.codex_trainer_owner);
        codex_solo_trainer_game_speed_release();
    }
}

codex_solo_trainer_game_speed_apply()
{
    level.codex_trainer_game_speed_applied = 0;
    level.codex_trainer_game_speed_current = gettimescale();
    level.codex_trainer_game_speed_available = 0;
    if ((isint(level.codex_trainer_game_speed_current) || isfloat(level.codex_trainer_game_speed_current))
        && level.codex_trainer_game_speed_current > 0 && level.codex_trainer_game_speed_current <= 1000)
        level.codex_trainer_game_speed_available = 1;
    if (level.codex_trainer_game_speed != 1)
    {
        codex_solo_trainer_game_speed_release();
        level.codex_trainer_game_speed_conflict = 0;
        return;
    }
    if (level.codex_trainer_game_speed_ended || level.codex_trainer_game_speed_conflict
        || !level.codex_trainer_game_speed_available || !level.codex_trainer_ready
        || !isint(level.codex_trainer_game_speed_value)
        || level.codex_trainer_game_speed_value < 20 || level.codex_trainer_game_speed_value > 500)
        return;
    if (!level.codex_trainer_game_speed_owned)
    {
        level.codex_trainer_game_speed_before = level.codex_trainer_game_speed_current;
        level.codex_trainer_game_speed_owned = 1;
    }
    else if (level.codex_trainer_game_speed_current < level.codex_trainer_game_speed_last - 0.0001
        || level.codex_trainer_game_speed_current > level.codex_trainer_game_speed_last + 0.0001)
    {
        // The native transition can become visible on a later engine frame.
        // Do not mistake our own pending write for an external slow-motion event.
        if (gettime() < level.codex_trainer_game_speed_settle_until)
            return;
        // Yield if a native event changed the effective scale we owned.
        level.codex_trainer_game_speed_owned = 0;
        level.codex_trainer_game_speed_conflict = 1;
        return;
    }
    if (!isdefined(level.codex_trainer_game_speed_last)
        || level.codex_trainer_game_speed_last != level.codex_trainer_game_speed_value / 100.0)
    {
        level.codex_trainer_game_speed_last = level.codex_trainer_game_speed_value / 100.0;
        level.codex_trainer_game_speed_settle_until = gettime() + 500;
        setslowmotion(level.codex_trainer_game_speed_current, level.codex_trainer_game_speed_last, 0);
    }
    level.codex_trainer_game_speed_current = gettimescale();
    if (level.codex_trainer_game_speed_current >= level.codex_trainer_game_speed_last - 0.0001
        && level.codex_trainer_game_speed_current <= level.codex_trainer_game_speed_last + 0.0001)
    {
        level.codex_trainer_game_speed_applied = 1;
        level.codex_trainer_game_speed_settle_until = 0;
    }
}

codex_solo_trainer_game_speed_release()
{
    level.codex_trainer_game_speed_applied = 0;
    level.codex_trainer_game_speed_current = gettimescale();
    if (isdefined(level.codex_trainer_game_speed_owned) && level.codex_trainer_game_speed_owned
        && isdefined(level.codex_trainer_game_speed_before) && isdefined(level.codex_trainer_game_speed_last)
        && level.codex_trainer_game_speed_current >= level.codex_trainer_game_speed_last - 0.0001
        && level.codex_trainer_game_speed_current <= level.codex_trainer_game_speed_last + 0.0001)
    {
        setslowmotion(level.codex_trainer_game_speed_current, level.codex_trainer_game_speed_before, 0);
        level.codex_trainer_game_speed_current = gettimescale();
    }
    level.codex_trainer_game_speed_owned = 0;
    level.codex_trainer_game_speed_before = undefined;
    level.codex_trainer_game_speed_last = undefined;
    level.codex_trainer_game_speed_settle_until = 0;
}

// Static-verified cg_fov dvar contract for Kronos local Zombies.
// This is BASE FOV: the game also applies the user's profile multiplier.
// Input: level.codex_trainer_fov (0/1), level.codex_trainer_fov_value int6000..11000.
// The protocol value is hundredths of a degree, divided by100.0 here.
// Caller must retain existing Solo/host/lease/owner guards.
// Network-style local client command is asynchronous; ACK only after readback.

codex_solo_trainer_fov_update()
{
    level.codex_trainer_fov_applied = 0;
    level.codex_trainer_fov_available = 0;
    if (!isdefined(level.codex_trainer_owner) || !isplayer(level.codex_trainer_owner))
        return;
    level.codex_trainer_fov_current = getdvarfloat(@"cg_fov", -1);
    if (level.codex_trainer_fov_current > 0 && level.codex_trainer_fov_current <= 110)
        level.codex_trainer_fov_available = 1;
    if (level.codex_trainer_fov == 1 && level.codex_trainer_fov_available
        && isint(level.codex_trainer_fov_value) && level.codex_trainer_fov_value >= 6000 && level.codex_trainer_fov_value <= 11000)
    {
        level.codex_trainer_fov_target = level.codex_trainer_fov_value / 100.0;
        if (!isdefined(level.codex_trainer_owner.codex_trainer_fov_owned) || !level.codex_trainer_owner.codex_trainer_fov_owned)
        {
            level.codex_trainer_owner.codex_trainer_fov_before = level.codex_trainer_fov_current;
            level.codex_trainer_owner.codex_trainer_fov_owned = 1;
            level.codex_trainer_owner setclientdvar(@"cg_fov", level.codex_trainer_fov_target);
        }
        else if (level.codex_trainer_io_tick && (level.codex_trainer_fov_current < level.codex_trainer_fov_target - 0.01 || level.codex_trainer_fov_current > level.codex_trainer_fov_target + 0.01))
            level.codex_trainer_owner setclientdvar(@"cg_fov", level.codex_trainer_fov_target);
        if (level.codex_trainer_fov_current >= level.codex_trainer_fov_target - 0.01 && level.codex_trainer_fov_current <= level.codex_trainer_fov_target + 0.01)
            level.codex_trainer_fov_applied = 1;
    }
    else
        codex_solo_trainer_fov_release(level.codex_trainer_owner);
}

codex_solo_trainer_fov_release(player)
{
    if (isdefined(player) && isplayer(player) && isdefined(player.codex_trainer_fov_owned) && player.codex_trainer_fov_owned)
    {
        // Always enqueue restoration after this trainer's possible pending command.
        if (isdefined(player.codex_trainer_fov_before) && player.codex_trainer_fov_before > 0 && player.codex_trainer_fov_before <= 110)
            player setclientdvar(@"cg_fov", player.codex_trainer_fov_before);
        player.codex_trainer_fov_owned = 0;
        player.codex_trainer_fov_before = undefined;
    }
}



// Move Speed uses the engine script's existing per-posture override slots.
// These assignments match public function_eb085e20748bf083 from namespace
// bce7aa9cc2eadaf. The shared recalculator applies all current game modifiers.
// Caller owns Solo/lease checks and calls release on every cleanup path.
codex_solo_trainer_move_speed_init()
{
    level.codex_trainer_move_speed_applied = 0;
    level.codex_trainer_move_speed_available = 0;
    level.codex_trainer_move_speed_current = -1;
    level.codex_trainer_move_speed_conflict = 0;
}

codex_solo_trainer_move_speed_api_available()
{
    return isdefined(level.var_9e5c1a9e0a29d3ce)
        && isdefined(level.var_9e5c1a9e0a29d3ce[#"hash_4580fab03b7eb9c0"])
        && utility::issharedfuncdefined(#"hash_4580fab03b7eb9c0", #"hash_804044713d3198ac");
}

codex_solo_trainer_move_speed_slot_owned(player, slot)
{
    if (!isdefined(player.var_7a73125bb658e366)
        || !isdefined(player.var_7a73125bb658e366[slot])
        || !isdefined(player.codex_trainer_move_speed_last))
        return 0;
    player.codex_trainer_move_slot_current = player.var_7a73125bb658e366[slot];
    if (!isint(player.codex_trainer_move_slot_current) && !isfloat(player.codex_trainer_move_slot_current))
        return 0;
    return player.codex_trainer_move_slot_current >= player.codex_trainer_move_speed_last - 0.0001
        && player.codex_trainer_move_slot_current <= player.codex_trainer_move_speed_last + 0.0001;
}

codex_solo_trainer_move_speed_apply(player)
{
    level.codex_trainer_move_speed_applied = 0;
    level.codex_trainer_move_speed_available = 0;
    level.codex_trainer_move_speed_current = -1;
    if (!isdefined(player) || !isplayer(player))
        return;
    if (codex_solo_trainer_move_speed_api_available()
        && isdefined(player.var_10642c4e8e304f16)
        && (isint(player.var_10642c4e8e304f16) || isfloat(player.var_10642c4e8e304f16))
        && player.var_10642c4e8e304f16 >= 0 && player.var_10642c4e8e304f16 <= 5
        && getdvarfloat(@"hash_9333dbd7040164e4", 1) == 1)
        level.codex_trainer_move_speed_available = 1;
    if (level.codex_trainer_move_speed != 1)
    {
        codex_solo_trainer_move_speed_release(player);
        level.codex_trainer_move_speed_conflict = 0;
        return;
    }
    if (!level.codex_trainer_move_speed_available || !level.codex_trainer_ready
        || level.codex_trainer_move_speed_conflict
        || !isint(level.codex_trainer_move_speed_value)
        || level.codex_trainer_move_speed_value < 50 || level.codex_trainer_move_speed_value > 500)
    {
        codex_solo_trainer_move_speed_release(player);
        return;
    }
    if (!isdefined(player.codex_trainer_move_speed_owned) || !player.codex_trainer_move_speed_owned)
    {
        player.codex_trainer_move_speed_before = [];
        player.codex_trainer_move_slot = 2;
        while (player.codex_trainer_move_slot <= 5)
        {
            // Undefined is significant: it means compute from live perks.
            if (isdefined(player.var_7a73125bb658e366)
                && isdefined(player.var_7a73125bb658e366[player.codex_trainer_move_slot]))
                player.codex_trainer_move_speed_before[player.codex_trainer_move_slot] = player.var_7a73125bb658e366[player.codex_trainer_move_slot];
            player.codex_trainer_move_slot = player.codex_trainer_move_slot + 1;
        }
        player.codex_trainer_move_speed_owned = 1;
    }
    else
    {
        player.codex_trainer_move_slot = 2;
        while (player.codex_trainer_move_slot <= 5)
        {
            if (!codex_solo_trainer_move_speed_slot_owned(player, player.codex_trainer_move_slot))
            {
                // Preserve the changed slot and return only our other slots.
                codex_solo_trainer_move_speed_release(player);
                level.codex_trainer_move_speed_conflict = 1;
                return;
            }
            player.codex_trainer_move_slot = player.codex_trainer_move_slot + 1;
        }
    }
    player.codex_trainer_move_speed_last = level.codex_trainer_move_speed_value / 100.0;
    if (!isdefined(player.var_7a73125bb658e366))
        player.var_7a73125bb658e366 = [];
    player.codex_trainer_move_slot = 2;
    while (player.codex_trainer_move_slot <= 5)
    {
        player.var_7a73125bb658e366[player.codex_trainer_move_slot] = player.codex_trainer_move_speed_last;
        player.codex_trainer_move_slot = player.codex_trainer_move_slot + 1;
    }
    player utility::callsharedfunc(#"hash_4580fab03b7eb9c0", #"hash_804044713d3198ac");
    level.codex_trainer_move_speed_current = player.var_10642c4e8e304f16;
    if (isdefined(level.codex_trainer_move_speed_current)
        && level.codex_trainer_move_speed_current >= player.codex_trainer_move_speed_last - 0.0001
        && level.codex_trainer_move_speed_current <= player.codex_trainer_move_speed_last + 0.0001)
        level.codex_trainer_move_speed_applied = 1;
}

codex_solo_trainer_move_speed_release(player)
{
    level.codex_trainer_move_speed_applied = 0;
    if (!isdefined(player) || !isplayer(player)
        || !isdefined(player.codex_trainer_move_speed_owned) || !player.codex_trainer_move_speed_owned)
        return;
    player.codex_trainer_move_slot = 2;
    while (player.codex_trainer_move_slot <= 5)
    {
        if (codex_solo_trainer_move_speed_slot_owned(player, player.codex_trainer_move_slot))
        {
            if (isdefined(player.codex_trainer_move_speed_before[player.codex_trainer_move_slot]))
                player.var_7a73125bb658e366[player.codex_trainer_move_slot] = player.codex_trainer_move_speed_before[player.codex_trainer_move_slot];
            else
                player.var_7a73125bb658e366[player.codex_trainer_move_slot] = undefined;
        }
        player.codex_trainer_move_slot = player.codex_trainer_move_slot + 1;
    }
    player.codex_trainer_move_speed_owned = 0;
    player.codex_trainer_move_speed_before = undefined;
    player.codex_trainer_move_speed_last = undefined;
    if (codex_solo_trainer_move_speed_api_available())
    {
        player utility::callsharedfunc(#"hash_4580fab03b7eb9c0", #"hash_804044713d3198ac");
        level.codex_trainer_move_speed_current = player.var_10642c4e8e304f16;
    }
}

// Existing MP player-damage cancellation callback, before health processing.
// Caller must call init once, apply(player) while scope is valid, release on
// OFF/owner replacement/lease loss/game end. No health or takedamage writes.
codex_solo_trainer_god_gate_init()
{
    level.codex_trainer_god_gate_owned = 0;
    level.codex_trainer_god_gate_conflict = 0;
    level.codex_trainer_god_gate_before = undefined;
    level.codex_trainer_god_gate_owner = undefined;
    level.codex_trainer_god_gate_calls = 0;
    level.codex_trainer_god_gate_forwarded = 0;
    level.codex_trainer_god_blocks = 0;
    level.codex_trainer_god_last_damage = 0;
    level.codex_trainer_god_last_health = -1;
    level.codex_trainer_god_available = 0;
    level.codex_trainer_god_applied = 0;
}

codex_solo_trainer_god_gate_apply(player)
{
    level.codex_trainer_god_applied = 0;
    level.codex_trainer_god_available = 0;
    // The original Zombies callback setup installs this main damage entry.
    // The optional cancellation slot itself may legitimately be undefined.
    if (isdefined(player) && isplayer(player)
        && isdefined(level.var_6870521fb11b27dd)
        && !level.codex_trainer_god_gate_conflict)
        level.codex_trainer_god_available = 1;
    if (level.codex_trainer_godmode != 1 || !level.codex_trainer_ready
        || !level.codex_trainer_god_available)
    {
        codex_solo_trainer_god_gate_release();
        return;
    }
    if (level.codex_trainer_god_gate_owned)
    {
        if (!isdefined(level.var_a44ba6c01eac941)
            || level.var_a44ba6c01eac941 != &codex_solo_trainer_god_gate_callback)
        {
            // Another wrapper may have captured ours. Never rewrap it:
            // that could make a cycle through our previous-function field.
            level.codex_trainer_god_gate_owned = 0;
            level.codex_trainer_god_gate_conflict = 1;
            level.codex_trainer_god_available = 0;
            return;
        }
    }
    else
    {
        if (isdefined(level.var_a44ba6c01eac941)
            && level.var_a44ba6c01eac941 == &codex_solo_trainer_god_gate_callback)
        {
            level.codex_trainer_god_gate_conflict = 1;
            level.codex_trainer_god_available = 0;
            return;
        }
        level.codex_trainer_god_gate_before = level.var_a44ba6c01eac941;
        level.var_a44ba6c01eac941 = &codex_solo_trainer_god_gate_callback;
        level.codex_trainer_god_gate_owned = 1;
    }
    level.codex_trainer_god_gate_owner = player;
    if (isdefined(level.var_a44ba6c01eac941)
        && level.var_a44ba6c01eac941 == &codex_solo_trainer_god_gate_callback)
        level.codex_trainer_god_applied = 1;
}

codex_solo_trainer_god_gate_release()
{
    level.codex_trainer_god_applied = 0;
    if (!isdefined(level.codex_trainer_god_gate_owned) || !level.codex_trainer_god_gate_owned)
        return;
    if (isdefined(level.var_a44ba6c01eac941)
        && level.var_a44ba6c01eac941 == &codex_solo_trainer_god_gate_callback)
        level.var_a44ba6c01eac941 = level.codex_trainer_god_gate_before;
    else
        level.codex_trainer_god_gate_conflict = 1;
    level.codex_trainer_god_gate_owned = 0;
    level.codex_trainer_god_gate_owner = undefined;
    // Keep predecessor available if an external hook retains our wrapper.
}

codex_solo_trainer_god_gate_callback(p1, p2, victim, damage, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16)
{
    level.codex_trainer_god_gate_calls = level.codex_trainer_god_gate_calls + 1;
    if (level.codex_trainer_god_gate_owned && !level.codex_trainer_god_gate_conflict
        && isdefined(level.var_a44ba6c01eac941)
        && level.var_a44ba6c01eac941 == &codex_solo_trainer_god_gate_callback
        && isdefined(level.codex_trainer_ready) && level.codex_trainer_ready
        && isdefined(level.codex_trainer_godmode) && level.codex_trainer_godmode == 1
        && isdefined(level.codex_trainer_owner) && isdefined(level.codex_trainer_god_gate_owner)
        && isdefined(victim) && isplayer(victim) && isalive(victim)
        && victim == level.codex_trainer_god_gate_owner && victim == level.codex_trainer_owner
        && isdefined(level.codex_trainer_count) && level.codex_trainer_count == 1
        && isdefined(level.codex_trainer_valid) && level.codex_trainer_valid
        && isdefined(level.codex_trainer_fresh) && level.codex_trainer_fresh
        && isdefined(level.codex_trainer_leaseage) && level.codex_trainer_leaseage < 100
        && isdefined(damage) && (isint(damage) || isfloat(damage)) && damage > 0)
    {
        level.codex_trainer_god_blocks = level.codex_trainer_god_blocks + 1;
        level.codex_trainer_god_last_damage = damage;
        if (isdefined(victim.health) && isint(victim.health))
            level.codex_trainer_god_last_health = victim.health;
        // The caller returns immediately when this callback returns true.
        return 1;
    }
    if (isdefined(level.codex_trainer_god_gate_before)
        && level.codex_trainer_god_gate_before != &codex_solo_trainer_god_gate_callback)
    {
        level.codex_trainer_god_gate_forwarded = level.codex_trainer_god_gate_forwarded + 1;
        // Same implicit self and exact 16 arguments as the original caller.
        return [[level.codex_trainer_god_gate_before]](p1, p2, victim, damage, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16);
    }
    return 0;
}


// Protocol 4: guarded one-shot weapon actions. Native shared function contracts
// are documented in work/weapon-research and work/ammo-research.
codex_trainer_actions_init()
{
    level.codex_trainer_action_nonce = 0;
    level.codex_trainer_last_action_nonce = 0;
    level.codex_trainer_action_kind = "";
    level.codex_trainer_action_value = "";
    level.codex_trainer_action_level = 0;
    level.codex_trainer_action_result = "none";
    level.codex_trainer_action_detail = "";
    level.codex_trainer_action_busy = 0;
    level.codex_trainer_weapon_requested = "";
    level.codex_trainer_weapon_resolved = "";
    level.codex_trainer_action_age = 0;
    level.codex_trainer_catalog_session = "";
    level.codex_trainer_weapon_name = "";
    level.codex_trainer_pap_level = -1;
    level.codex_trainer_ammo_mod_name = "";
}

codex_trainer_actions_poll()
{
    if (level.codex_trainer_action_busy)
    {
        level.codex_trainer_action_age = level.codex_trainer_action_age + 1;
        if (level.codex_trainer_action_age > 240 || !level.codex_trainer_ready)
        {
            if (isdefined(level.codex_trainer_action_player))
                level.codex_trainer_action_player notify(#"codex_action_cancel");
            level.codex_trainer_action_busy = 0;
            level.codex_trainer_action_result = "failed";
            level.codex_trainer_action_detail = "action_timeout";
        }
    }
    if (level.codex_trainer_io_tick)
    {
        codex_trainer_round_status();
        level.codex_trainer_weapon_name = "";
        level.codex_trainer_pap_level = -1;
        level.codex_trainer_ammo_mod_name = "";
        if (level.codex_trainer_ready && isdefined(level.codex_trainer_owner))
        {
            level.codex_trainer_owner codex_trainer_weapon_status();
            if (level.codex_trainer_catalog_session != level.codex_trainer_session)
                codex_trainer_weapon_catalog();
        }
        if (level.codex_trainer_valid && level.codex_trainer_action_nonce > level.codex_trainer_last_action_nonce)
        {
            // Consume before dispatch. Repeated heartbeats can never grant twice.
            level.codex_trainer_last_action_nonce = level.codex_trainer_action_nonce;
            level.codex_trainer_action_result = "rejected";
            level.codex_trainer_action_detail = "solo_player_required";
            if (level.codex_trainer_action_busy)
            {
                level.codex_trainer_action_result = "busy";
                level.codex_trainer_action_detail = "previous_action_running";
            }
            else if (level.codex_trainer_ready && isdefined(level.codex_trainer_owner))
            {
                level.codex_trainer_action_busy = 1;
                level.codex_trainer_action_player = level.codex_trainer_owner;
                level.codex_trainer_action_age = 0;
                level.codex_trainer_action_result = "pending";
                level.codex_trainer_action_detail = "preparing";
                level.codex_trainer_owner thread codex_trainer_action_worker(level.codex_trainer_session,
                    level.codex_trainer_last_action_nonce, level.codex_trainer_action_kind,
                    level.codex_trainer_action_value, level.codex_trainer_action_level);
            }
        }
    }
}

codex_trainer_action_valid(session, nonce)
{
    return isdefined(self) && isplayer(self) && isalive(self) && self ishost()
        && level.codex_trainer_ready && level.codex_trainer_owner == self
        && level.codex_trainer_session == session && level.codex_trainer_last_action_nonce == nonce
        && level.codex_trainer_action_result == "pending" && level.codex_trainer_action_busy;
}

codex_trainer_action_worker(session, nonce, kind, value, target)
{
    self endon(#"codex_action_cancel");
    self endon(#"disconnect");
    self.codex_action_result = "rejected";
    self.codex_action_detail = "invalid_action";
    if (self codex_trainer_action_valid(session, nonce))
    {
        if (kind == "give_weapon")
            self codex_trainer_give_weapon(session, nonce, value);
        else if (kind == "pap" && target >= 1 && target <= 3)
            self codex_trainer_pack_weapon(session, nonce, target);
        else if (kind == "ammo_mod")
            self codex_trainer_mod_weapon(session, nonce, value);
        else if (kind == "end_round")
            self codex_trainer_end_round(session, nonce);
    }
    if (level.codex_trainer_session == session && level.codex_trainer_last_action_nonce == nonce)
    {
        if (self codex_trainer_action_valid(session, nonce))
        {
            level.codex_trainer_action_result = self.codex_action_result;
            level.codex_trainer_action_detail = self.codex_action_detail;
        }
        else
        {
            level.codex_trainer_action_result = "rejected";
            level.codex_trainer_action_detail = "session_changed";
        }
        level.codex_trainer_action_busy = 0;
    }
}

codex_trainer_weapon_status()
{
    self.codex_status_weapon = self getcurrentweapon();
    if (!isdefined(self.codex_status_weapon) || isnullweapon(self.codex_status_weapon))
        return;
    if (isdefined(self.codex_status_weapon.basename) && isstring(self.codex_status_weapon.basename))
        level.codex_trainer_weapon_name = self.codex_status_weapon.basename;
    if (utility::issharedfuncdefined(#"pack_a_punch", #"get_pap_level"))
    {
        self.codex_status_pap = self utility::callsharedfunc(#"pack_a_punch", #"get_pap_level", self.codex_status_weapon);
        if (isdefined(self.codex_status_pap) && isint(self.codex_status_pap))
            level.codex_trainer_pap_level = self.codex_status_pap;
    }
    if (isdefined(self.ammo_mod) && utility::issharedfuncdefined(#"zombie", #"hash_b69580127adf439"))
    {
        self.codex_status_mod = self utility::callsharedfunc(#"zombie", #"hash_b69580127adf439", self.codex_status_weapon);
        if (isdefined(self.codex_status_mod) && isstring(self.codex_status_mod))
            level.codex_trainer_ammo_mod_name = self.codex_status_mod;
    }
}

codex_trainer_weapon_catalog()
{
    if (!isdefined(level.weaponmapdata))
        return;
    level.codex_trainer_catalog_keys = getarraykeys(level.weaponmapdata);
    level.codex_trainer_catalog_index = 0;
    level.codex_trainer_catalog_count = 0;
    while (level.codex_trainer_catalog_index < level.codex_trainer_catalog_keys.size && level.codex_trainer_catalog_count < 512)
    {
        level.codex_trainer_catalog_name = level.codex_trainer_catalog_keys[level.codex_trainer_catalog_index];
        if (isstring(level.codex_trainer_catalog_name) && isdefined(level.weaponmapdata[level.codex_trainer_catalog_name]))
        {
            nengine_store_set("codexcatalog", "weapon_" + level.codex_trainer_catalog_count, level.codex_trainer_catalog_name);
            level.codex_trainer_catalog_count = level.codex_trainer_catalog_count + 1;
        }
        level.codex_trainer_catalog_index = level.codex_trainer_catalog_index + 1;
    }
    nengine_store_set("codexcatalog", "protocol", 5);
    nengine_store_set("codexcatalog", "session", level.codex_trainer_session);
    nengine_store_set("codexcatalog", "weapon_count", level.codex_trainer_catalog_count);
    if (nengine_store_save("codexcatalog", "catalog"))
        level.codex_trainer_catalog_session = level.codex_trainer_session;
}

codex_trainer_has_weapon(check)
{
    self.codex_inventory = self getweaponslistprimaries();
    if (!isdefined(self.codex_inventory))
        return 0;
    self.codex_inventory_index = 0;
    while (self.codex_inventory_index < self.codex_inventory.size)
    {
        if (self.codex_inventory[self.codex_inventory_index] == check || issameweapon(self.codex_inventory[self.codex_inventory_index], check))
            return 1;
        self.codex_inventory_index = self.codex_inventory_index + 1;
    }
    return 0;
}

codex_trainer_give_weapon(session, nonce, name)
{
    level.codex_trainer_weapon_requested = name;
    level.codex_trainer_weapon_resolved = "";
    self.codex_action_result = "unavailable";
    self.codex_action_detail = "weapon_not_registered";
    self.codex_action_name = name;
    // Match the original common weapon resolver: engine IDs first, map aliases second.
    // Recognition is not proof that a map has the special weapon's scripts/effects.
    if (!weaponexists(self.codex_action_name)
        && (!isdefined(level.weaponmapdata) || !isdefined(level.weaponmapdata[self.codex_action_name]))
        && issubstr(self.codex_action_name, "_mp"))
        self.codex_action_name = removesubstr(self.codex_action_name, "_mp");
    if (!weaponexists(self.codex_action_name)
        && (!isdefined(level.weaponmapdata) || !isdefined(level.weaponmapdata[self.codex_action_name])))
        return;
    self.codex_action_detail = "weapon_build_failed";
    self.codex_action_weapon = weapon::buildweapon(self.codex_action_name, getweapondefaultattachments(self.codex_action_name));
    if (!isdefined(self.codex_action_weapon) || isnullweapon(self.codex_action_weapon))
        return;
    if (isdefined(self.codex_action_weapon.basename))
        level.codex_trainer_weapon_resolved = self.codex_action_weapon.basename;
    self.codex_action_detail = "weapon_root_mismatch";
    if (weapon::getweaponrootname(self.codex_action_weapon) != weapon::getweaponrootname(self.codex_action_name))
        return;
    if (!self codex_trainer_action_valid(session, nonce))
        return;
    self.codex_action_detail = "weapon_loading";
    self loadweaponsforplayer([self.codex_action_weapon], 1);
    self.codex_action_load_ticks = 0;
    while (!self hasloadedviewweapons([self.codex_action_weapon]) && self.codex_action_load_ticks < 40)
    {
        wait 0.1;
        if (!self codex_trainer_action_valid(session, nonce))
            return;
        self.codex_action_load_ticks = self.codex_action_load_ticks + 1;
    }
    self.codex_action_detail = "weapon_assets_not_loaded";
    if (!self hasloadedviewweapons([self.codex_action_weapon]))
        return;
    self.codex_action_previous_weapon = self getcurrentweapon();
    self.codex_action_replaced = 0;
    self giveweapon(self.codex_action_weapon, undefined, 0, -1, 0);
    if (!self codex_trainer_has_weapon(self.codex_action_weapon)
        && isdefined(self.codex_action_previous_weapon) && !isnullweapon(self.codex_action_previous_weapon)
        && self codex_trainer_has_weapon(self.codex_action_previous_weapon))
    {
        // No yield between removal, give and rollback. Keep the exact descriptor,
        // including attachments/upgrades, and both ammo counts for rollback.
        self.codex_action_previous_clip = self getweaponammoclip(self.codex_action_previous_weapon);
        self.codex_action_previous_stock = self getweaponammostock(self.codex_action_previous_weapon);
        self takeweapon(self.codex_action_previous_weapon);
        self giveweapon(self.codex_action_weapon, undefined, 0, -1, 0);
        if (!self codex_trainer_has_weapon(self.codex_action_weapon))
        {
            self giveweapon(self.codex_action_previous_weapon, undefined, 0, -1, 0);
            self assignweaponprimaryslot(self.codex_action_previous_weapon);
            self setweaponammoclip(self.codex_action_previous_weapon, self.codex_action_previous_clip);
            self setweaponammostock(self.codex_action_previous_weapon, self.codex_action_previous_stock);
            self switchtoweapon(self.codex_action_previous_weapon);
            self.codex_action_result = "failed";
            self.codex_action_detail = "weapon_replace_restore_failed";
            if (self codex_trainer_has_weapon(self.codex_action_previous_weapon))
                self.codex_action_detail = "weapon_replace_rolled_back";
            return;
        }
        self.codex_action_replaced = 1;
    }
    self.codex_action_result = "failed";
    self.codex_action_detail = "weapon_not_in_inventory";
    if (!self codex_trainer_has_weapon(self.codex_action_weapon))
        return;
    self assignweaponprimaryslot(self.codex_action_weapon);
    self switchtoweapon(self.codex_action_weapon);
    self givemaxammo(self.codex_action_weapon);
    self.codex_action_detail = "weapon_equip_timeout";
    self.codex_action_equip_ticks = 0;
    while (self.codex_action_equip_ticks < 40)
    {
        wait 0.1;
        if (!self codex_trainer_action_valid(session, nonce))
            return;
        self.codex_action_equipped = self getcurrentweapon();
        if (isdefined(self.codex_action_equipped) && !isnullweapon(self.codex_action_equipped)
            && issameweapon(self.codex_action_equipped, self.codex_action_weapon))
        {
            self.codex_action_result = "applied";
            self.codex_action_detail = "weapon_equipped";
            if (self.codex_action_replaced)
                self.codex_action_detail = "weapon_replaced";
            return;
        }
        self.codex_action_equip_ticks = self.codex_action_equip_ticks + 1;
    }
}

codex_trainer_round_status()
{
    nengine_store_set("codexack", "round_number", -1);
    nengine_store_set("codexack", "round_state", -1);
    nengine_store_set("codexack", "spawner_state", -1);
    nengine_store_set("codexack", "zombies_alive", -1);
    if (isdefined(level.var_6781718da4f78d1c))
    {
        if (isdefined(level.var_6781718da4f78d1c.roundnumber))
            nengine_store_set("codexack", "round_number", level.var_6781718da4f78d1c.roundnumber);
        if (isdefined(level.var_6781718da4f78d1c.state))
            nengine_store_set("codexack", "round_state", level.var_6781718da4f78d1c.state);
    }
    if (isdefined(level.var_a009ab14ee0d3223) && isdefined(level.var_a009ab14ee0d3223.state))
        nengine_store_set("codexack", "spawner_state", level.var_a009ab14ee0d3223.state);
    if (isdefined(level.zombie_team) && isdefined(level.var_a009ab14ee0d3223))
    {
        // Exact live-enemy selector used by the original round death callback.
        // Excludes ambient/non-round AI that can remain alive between rounds.
        enemies = namespace_ea0d69869863f098::function_45bd2c072cb4631a();
        count = 0;
        if (isdefined(enemies))
        {
            foreach (enemy in enemies)
                if (isdefined(enemy) && !isplayer(enemy) && isalive(enemy))
                    count = count + 1;
            nengine_store_set("codexack", "zombies_alive", count);
        }
    }
}

codex_trainer_enemy_protected(enemy)
{
    if ((isdefined(enemy.b_ignore_cleanup) && enemy.b_ignore_cleanup)
        || (isdefined(enemy.magic_bullet_shield) && enemy.magic_bullet_shield)
        || (isdefined(enemy.damageshield) && enemy.damageshield))
        return 1;
    if (isdefined(enemy.values) && isdefined(enemy.values["ignore_cleanup"]))
    {
        states = enemy.values["ignore_cleanup"];
        if (states.size > 0 && isdefined(states[states.size - 1]) && states[states.size - 1])
            return 1;
    }
    return 0;
}

codex_trainer_end_round(session, nonce)
{
    self.codex_action_result = "unavailable";
    self.codex_action_detail = "round_not_active";
    if (!isdefined(level.var_6781718da4f78d1c) || !isdefined(level.var_a009ab14ee0d3223)
        || !isdefined(level.zombie_team))
        return;
    manager = level.var_6781718da4f78d1c;
    spawner = level.var_a009ab14ee0d3223;
    if (manager.state != 1 || spawner.state != 1 || !isint(manager.roundnumber)
        || manager.roundnumber < 1 || manager.roundnumber >= 999)
        return;
    round = manager.roundnumber;
    enemies = namespace_ea0d69869863f098::function_45bd2c072cb4631a();
    if (!isdefined(enemies) || enemies.size > 512)
        return;
    // Preflight the whole snapshot before modifying any enemy.
    foreach (enemy in enemies)
    {
        if (isdefined(enemy) && !isplayer(enemy) && isalive(enemy) && codex_trainer_enemy_protected(enemy))
        {
            self.codex_action_detail = "round_protected_enemy";
            return;
        }
    }
    foreach (enemy in enemies)
    {
        if (!self codex_trainer_action_valid(session, nonce) || manager != level.var_6781718da4f78d1c
            || spawner != level.var_a009ab14ee0d3223 || manager.roundnumber != round)
            return;
        if (isdefined(enemy) && !isplayer(enemy) && isalive(enemy))
        {
            enemy.no_powerups = 1;
            enemy.b_cleaned_up = 1;
            enemy kill();
        }
    }
    // This is the original round-manager timeout path. It clears queued spawns
    // and preserves round callbacks, rather than merely editing the counter.
    if (manager.roundnumber == round && manager.state == 1 && spawner.state == 1)
        spawner.state = 2;
    self.codex_action_result = "failed";
    self.codex_action_detail = "round_transition_timeout";
    ticks = 0;
    while (ticks < 80)
    {
        if (!self codex_trainer_action_valid(session, nonce) || manager != level.var_6781718da4f78d1c
            || spawner != level.var_a009ab14ee0d3223)
            return;
        if (manager.roundnumber == round + 1)
        {
            self.codex_action_result = "applied";
            self.codex_action_detail = "round_finished";
            return;
        }
        if (manager.roundnumber != round)
            return;
        wait 0.1;
        ticks = ticks + 1;
    }
}

codex_trainer_pack_weapon(session, nonce, target)
{
    self.codex_action_result = "unavailable";
    self.codex_action_detail = "pack_a_punch_unavailable";
    if (!utility::issharedfuncdefined(#"pack_a_punch", #"pap_weapon")
        || !utility::issharedfuncdefined(#"pack_a_punch", #"get_pap_level")
        || !utility::issharedfuncdefined(#"pack_a_punch", #"can_pap"))
        return;
    self.codex_action_weapon = self getcurrentweapon();
    if (!isdefined(self.codex_action_weapon) || isnullweapon(self.codex_action_weapon)
        || !self codex_trainer_has_weapon(self.codex_action_weapon))
        return;
    self.codex_action_old_pap = self utility::callsharedfunc(#"pack_a_punch", #"get_pap_level", self.codex_action_weapon);
    if (!isdefined(self.codex_action_old_pap) || !isint(self.codex_action_old_pap))
        return;
    if (self.codex_action_old_pap >= target)
    {
        self.codex_action_result = "applied";
        self.codex_action_detail = "pack_level_already_reached";
        return;
    }
    // Apply successive levels so native callbacks also see current + 1.
    while (self.codex_action_old_pap < target)
    {
        if (!self codex_trainer_action_valid(session, nonce))
            return;
        if (!self utility::callsharedfunc(#"pack_a_punch", #"can_pap", self.codex_action_weapon))
            return;
        self.codex_action_next_pap = self.codex_action_old_pap + 1;
        self.codex_action_new_weapon = self utility::callsharedfunc(#"pack_a_punch", #"pap_weapon",
            self.codex_action_weapon, self.codex_action_old_pap, 0, undefined, undefined, 1, 0, self.codex_action_next_pap);
        self.codex_action_result = "failed";
        self.codex_action_detail = "pack_level_not_confirmed";
        if (!isdefined(self.codex_action_new_weapon) || isnullweapon(self.codex_action_new_weapon)
            || !self codex_trainer_has_weapon(self.codex_action_new_weapon))
            return;
        self.codex_action_new_pap = self utility::callsharedfunc(#"pack_a_punch", #"get_pap_level", self.codex_action_new_weapon);
        if (!isdefined(self.codex_action_new_pap) || self.codex_action_new_pap != self.codex_action_next_pap)
            return;
        self.codex_action_weapon = self.codex_action_new_weapon;
        self.codex_action_old_pap = self.codex_action_new_pap;
        wait 0.1;
    }
    self.codex_action_result = "applied";
    self.codex_action_detail = "pack_level_confirmed";
}

codex_trainer_mod_weapon(session, nonce, name)
{
    self.codex_action_result = "unavailable";
    self.codex_action_detail = "ammo_mod_unavailable";
    if (!utility::issharedfuncdefined(#"ammo_mod", #"hash_24f1a2cf1ed6660d")
        || !utility::issharedfuncdefined(#"ammo_mod", #"hash_4f3b91e6539bb512")
        || !utility::issharedfuncdefined(#"zombie", #"hash_b69580127adf439")
        || !isdefined(self.ammo_mod))
        return;
    self.codex_action_weapon = self getcurrentweapon();
    if (!isdefined(self.codex_action_weapon) || isnullweapon(self.codex_action_weapon)
        || !self codex_trainer_has_weapon(self.codex_action_weapon))
        return;
    if (!self utility::callsharedfunc(#"ammo_mod", #"hash_4f3b91e6539bb512", self.codex_action_weapon))
        return;
    if (name == "none")
    {
        if (!utility::issharedfuncdefined(#"ammo_mod", #"hash_cf1012c4d313de70"))
            return;
        // This helper REMOVES the mod. It is never used by status polling.
        self utility::callsharedfunc(#"ammo_mod", #"hash_cf1012c4d313de70", self.codex_action_weapon, 0);
        self.codex_action_new_weapon = self.codex_action_weapon;
    }
    else
    {
        // Validate against the runtime registration table before the native setter.
        if (!isdefined(level.var_19d17bcdd41b0abc) || !isdefined(level.var_19d17bcdd41b0abc[name])
            || !isdefined(level.var_19d17bcdd41b0abc[name].var_bc922482a6aeb347)
            || level.var_19d17bcdd41b0abc[name].var_bc922482a6aeb347 <= 0)
            return;
        self.codex_action_new_weapon = self utility::callsharedfunc(#"ammo_mod", #"hash_24f1a2cf1ed6660d", self.codex_action_weapon, name);
    }
    if (!self codex_trainer_action_valid(session, nonce))
        return;
    self.codex_action_result = "failed";
    self.codex_action_detail = "ammo_mod_not_confirmed";
    if (!isdefined(self.codex_action_new_weapon) || isnullweapon(self.codex_action_new_weapon))
        return;
    self.codex_action_new_mod = self utility::callsharedfunc(#"zombie", #"hash_b69580127adf439", self.codex_action_new_weapon);
    if ((name == "none" && isdefined(self.codex_action_new_mod) && self.codex_action_new_mod == "")
        || (isdefined(self.codex_action_new_mod) && self.codex_action_new_mod == name))
    {
        self.codex_action_result = "applied";
        self.codex_action_detail = "ammo_mod_confirmed";
    }
}

// Read the game's actual jump binding, including a remapped key or controller.
// Called only by the existing living Solo-host/lease guarded 50 ms loop.
// No gravity, collision, position or permanent movement settings are changed:
// releasing jump, disabling, losing the lease or changing owner stops thrust.
codex_solo_trainer_jetpack_apply(player)
{
    if (!isdefined(player) || !isplayer(player) || !isalive(player)
        || !level.codex_trainer_ready || player islinked())
        return;
    level.codex_trainer_jetpack_available = 1;
    level.codex_trainer_jetpack_z = player.origin[2];
    level.codex_trainer_jetpack_x = player.origin[0];
    level.codex_trainer_jetpack_y = player.origin[1];
    if (level.codex_trainer_jetpack != 1)
        return;
    level.codex_trainer_jetpack_applied = 1;
    if (!player jumpbuttonpressed())
        return;
    player.codex_trainer_jetpack_velocity = player getvelocity();
    player.codex_trainer_jetpack_speed = level.codex_trainer_jetpack_value / 100.0;
    // Native forward/right input respects remapped controls and an analog stick.
    // Use yaw only: looking up/down must not rotate lateral thrust into altitude.
    player.codex_trainer_jetpack_input = player getnormalizedmovement(0.1);
    player.codex_trainer_jetpack_angles = player getplayerangles();
    player.codex_trainer_jetpack_forward = anglestoforward((0, player.codex_trainer_jetpack_angles[1], 0));
    player.codex_trainer_jetpack_right = anglestoright((0, player.codex_trainer_jetpack_angles[1], 0));
    player.codex_trainer_jetpack_direction = player.codex_trainer_jetpack_forward * player.codex_trainer_jetpack_input[0]
        + player.codex_trainer_jetpack_right * player.codex_trainer_jetpack_input[1];
    // Clamp diagonals without discarding partial analog-stick input.
    if (player.codex_trainer_jetpack_direction[0] * player.codex_trainer_jetpack_direction[0]
        + player.codex_trainer_jetpack_direction[1] * player.codex_trainer_jetpack_direction[1] > 1)
        player.codex_trainer_jetpack_direction = vectornormalize(player.codex_trainer_jetpack_direction);
    player.codex_trainer_jetpack_vertical = player.codex_trainer_jetpack_velocity[2];
    if (player.codex_trainer_jetpack_vertical < player.codex_trainer_jetpack_speed)
        player.codex_trainer_jetpack_vertical = player.codex_trainer_jetpack_speed;
    // Zero movement input brakes sideways drift while the jetpack is firing.
    player setvelocity((player.codex_trainer_jetpack_direction[0] * player.codex_trainer_jetpack_speed,
        player.codex_trainer_jetpack_direction[1] * player.codex_trainer_jetpack_speed,
        player.codex_trainer_jetpack_vertical));
    level.codex_trainer_jetpack_forward = player.codex_trainer_jetpack_input[0];
    level.codex_trainer_jetpack_right = player.codex_trainer_jetpack_input[1];
    level.codex_trainer_jetpack_thrust = 1;
    level.codex_trainer_jetpack_ticks = level.codex_trainer_jetpack_ticks + 1;
}
