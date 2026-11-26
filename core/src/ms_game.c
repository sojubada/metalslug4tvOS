#include "ms_game.h"
#include <math.h>
#include <stdio.h>
#include <string.h>

#define MS_GRAVITY         1850.0f
#define MS_MOVE_SPEED      290.0f
#define MS_SLUG_SPEED      220.0f
#define MS_JUMP_VELOCITY   -720.0f
#define MS_BULLET_SPEED    860.0f
#define MS_MEM_BUDGET_WARN (1500ULL * 1024ULL * 1024ULL)

static void set_diag(ms_game_state_t *st, const char *msg) {
    if (!st || !msg) return;
    snprintf(st->last_diag_note, MS_DIAG_LEN, "%s", msg);
}

void ms_recalc_resolution(ms_game_state_t *st) {
    if (!st) return;
    int pct = st->switches.render_scale_percent;
    if (pct < 100) pct = 100;
    if (pct > 200) pct = 200;

    if (!st->switches.hi_res_upscale || st->switches.safe_mode_fallback) {
        pct = 100;
        if (st->switches.safe_mode_fallback && st->switches.remaster_tier > 1) {
            st->switches.remaster_tier = 1;
        }
    }

    st->switches.render_scale_percent = pct;
    st->effective_render_scale = (float)pct / 100.0f;
    st->target_width  = (int)(MS_BASE_VIEW_WIDTH * st->effective_render_scale);
    st->target_height = (int)(MS_BASE_VIEW_HEIGHT * st->effective_render_scale);
}

static size_t calc_core_footprint(const ms_game_state_t *st) {
    if (!st || !st->initialized) return 0ULL;
    size_t base = sizeof(*st);
    size_t tier_mult = (st->switches.remaster_tier >= 2) ? 2ULL : 1ULL;
    double scale_area = (double)st->effective_render_scale * (double)st->effective_render_scale;
    size_t stage_buf = (size_t)((24.0 * (double)tier_mult + 16.0 * scale_area) * 1024.0 * 1024.0);
    return base + stage_buf;
}

static void spawn_particles(ms_game_state_t *st, float x, float y, int count, uint32_t color) {
    if (st->switches.safe_mode_fallback && count > 2) count = 2;
    int spawned = 0;
    for (int i = 0; i < MS_MAX_PARTICLES && spawned < count; ++i) {
        if (!st->particles[i].active) {
            int dir = (i % 2 == 0) ? 1 : -1;
            st->particles[i].active = true;
            st->particles[i].x = x;
            st->particles[i].y = y;
            st->particles[i].vx = (float)(dir * (60 + (i * 29) % 160));
            st->particles[i].vy = (float)(-120 - (i * 37) % 220);
            st->particles[i].life = 18;
            st->particles[i].color_argb = color;
            spawned++;
        }
    }
}

static void spawn_bullet(ms_game_state_t *st, float x, float y, float vx, float vy, int dmg, bool from_player, bool is_grenade) {
    for (int i = 0; i < MS_MAX_BULLETS; ++i) {
        if (!st->bullets[i].active) {
            st->bullets[i].active = true;
            st->bullets[i].from_player = from_player;
            st->bullets[i].is_grenade = is_grenade;
            st->bullets[i].x = x;
            st->bullets[i].y = y;
            st->bullets[i].vx = vx;
            st->bullets[i].vy = vy;
            st->bullets[i].damage = dmg;
            st->bullets[i].ttl_frames = is_grenade ? 110 : 85;
            return;
        }
    }
    set_diag(st, "bullet pool full; dropped new projectile");
}

static bool spawn_enemy_unit(ms_game_state_t *st, ms_enemy_kind_t kind, float x, float y) {
    for (int i = 0; i < MS_MAX_ENEMIES; ++i) {
        if (!st->enemies[i].active) {
            ms_enemy_t *en = &st->enemies[i];
            memset(en, 0, sizeof(*en));
            en->active = true;
            en->kind = (int)kind;
            en->x = x;
            en->y = y;
            en->base_y = y;

            switch (kind) {
                case MS_ENEMY_TANK:
                    en->vx = -25.0f; en->hp = 6; en->score_value = 500; en->ai_timer = 105; break;
                case MS_ENEMY_BUNKER_GUARD:
                    en->vx = 0.0f; en->hp = 3; en->score_value = 250; en->ai_timer = 85; break;
                case MS_ENEMY_TOWER_GUARD:
                    en->vx = 0.0f; en->hp = 3; en->score_value = 300; en->ai_timer = 80; break;
                case MS_ENEMY_PARATROOPER:
                    en->vx = 0.0f; en->vy = 22.0f; en->hp = 2; en->score_value = 200; en->ai_timer = 95; break;
                case MS_ENEMY_HELI:
                    en->vx = -35.0f; en->hp = 5; en->score_value = 450; en->ai_timer = 110; break;
                case MS_ENEMY_INFANTRY:
                default:
                    en->vx = -65.0f; en->hp = 2; en->score_value = 100; en->ai_timer = 75; break;
            }
            en->max_hp = en->hp;
            return true;
        }
    }
    return false;
}

static void populate_stage_enemies(ms_game_state_t *st) {
    memset(st->enemies, 0, sizeof(st->enemies));
    spawn_enemy_unit(st, MS_ENEMY_INFANTRY,     620.0f, MS_GROUND_Y);
    spawn_enemy_unit(st, MS_ENEMY_BUNKER_GUARD, 840.0f, 455.0f);
    spawn_enemy_unit(st, MS_ENEMY_TOWER_GUARD,  1060.0f, 340.0f);
    spawn_enemy_unit(st, MS_ENEMY_TANK,         1260.0f, MS_GROUND_Y);
    spawn_enemy_unit(st, MS_ENEMY_PARATROOPER,  1440.0f, 220.0f);
    spawn_enemy_unit(st, MS_ENEMY_HELI,         1680.0f, 180.0f);

    spawn_enemy_unit(st, MS_ENEMY_INFANTRY,     2020.0f, MS_GROUND_Y);
    spawn_enemy_unit(st, MS_ENEMY_BUNKER_GUARD, 2280.0f, 455.0f);
    spawn_enemy_unit(st, MS_ENEMY_TOWER_GUARD,  2560.0f, 340.0f);
    spawn_enemy_unit(st, MS_ENEMY_TANK,         2860.0f, MS_GROUND_Y);
    spawn_enemy_unit(st, MS_ENEMY_PARATROOPER,  3120.0f, 210.0f);
    spawn_enemy_unit(st, MS_ENEMY_HELI,         3420.0f, 185.0f);
    spawn_enemy_unit(st, MS_ENEMY_TANK,         3950.0f, MS_GROUND_Y);
    spawn_enemy_unit(st, MS_ENEMY_TOWER_GUARD,  4220.0f, 340.0f);
}

void ms_game_init(ms_game_state_t *st, int stage_index, int saved_best_score, ms_switches_t initial_sw) {
    if (!st) return;
    memset(st, 0, sizeof(*st));
    st->stage_index = stage_index > 0 ? stage_index : 1;
    st->best_score = saved_best_score > 0 ? saved_best_score : 0;
    st->switches = initial_sw;
    if (st->switches.ui_scale_percent < 100) st->switches.ui_scale_percent = 150;
    if (st->switches.remaster_tier < 1) st->switches.remaster_tier = 1;

    st->player.x = 220.0f;
    st->player.y = MS_GROUND_Y;
    st->player.w = 44.0f;
    st->player.h = 64.0f;
    st->player.hp = 5;
    st->player.facing = 1;
    st->player.on_ground = true;
    st->player.in_slug = false;
    st->player.slug_hp = 12;
    st->player.grenade_count = 10;

    populate_stage_enemies(st);
    st->initialized = true;
    ms_recalc_resolution(st);
    st->approx_mem_bytes = calc_core_footprint(st);
    set_diag(st, "pure original init ok; hi-res graphics only");
}

void ms_release_stage_assets(ms_game_state_t *st) {
    if (!st) return;
    memset(st->bullets, 0, sizeof(st->bullets));
    memset(st->enemies, 0, sizeof(st->enemies));
    memset(st->particles, 0, sizeof(st->particles));
    st->initialized = false;
    st->approx_mem_bytes = 0;
    set_diag(st, "stage assets released; footprint reduced");
}

static bool aabb_overlap(float ax, float ay, float aw, float ah, float bx, float by, float bw, float bh) {
    return (ax < bx + bw) && (ax + aw > bx) && (ay < by + bh) && (ay + ah > by);
}

void ms_game_step(ms_game_state_t *st, uint32_t input_mask, float dt_sec) {
    if (!st || !st->initialized) return;
    st->approx_mem_bytes = calc_core_footprint(st);

    if (st->approx_mem_bytes > MS_MEM_BUDGET_WARN) {
        st->switches.safe_mode_fallback = true;
        st->switches.hi_res_upscale = false;
        ms_recalc_resolution(st);
        set_diag(st, "memory near limit; fallback to 100% scale");
    }

    if (input_mask & MS_INPUT_PAUSE) st->paused = !st->paused;
    if (st->paused || st->game_over) return;

    if (dt_sec <= 0.0f || dt_sec > 0.05f) dt_sec = 1.0f / 60.0f;
    st->tick_count++;

    ms_player_t *p = &st->player;
    if (p->fire_cooldown > 0) p->fire_cooldown--;
    if (p->invuln_frames > 0) p->invuln_frames--;

    if (input_mask & MS_INPUT_SLUG_TOGGLE) {
        if (p->slug_hp > 0) {
            p->in_slug = !p->in_slug;
            p->w = p->in_slug ? 74.0f : 44.0f;
            p->h = p->in_slug ? 68.0f : 64.0f;
            set_diag(st, p->in_slug ? "boarded metal slug" : "exited metal slug");
        }
    }

    float move_speed = p->in_slug ? MS_SLUG_SPEED : MS_MOVE_SPEED;
    p->vx = 0.0f;
    if (input_mask & MS_INPUT_LEFT)  { p->vx = -move_speed; p->facing = -1; }
    if (input_mask & MS_INPUT_RIGHT) { p->vx =  move_speed; p->facing =  1; }

    if ((input_mask & MS_INPUT_JUMP) && p->on_ground) {
        p->vy = MS_JUMP_VELOCITY;
        p->on_ground = false;
    }

    p->vy += MS_GRAVITY * dt_sec;
    p->x += p->vx * dt_sec;
    p->y += p->vy * dt_sec;

    if (p->x < st->camera_x + 40.0f) p->x = st->camera_x + 40.0f;
    if (p->x > MS_WORLD_WIDTH - p->w) p->x = MS_WORLD_WIDTH - p->w;
    if (p->y >= MS_GROUND_Y) { p->y = MS_GROUND_Y; p->vy = 0.0f; p->on_ground = true; }

    float target_cam = p->x - 420.0f;
    if (target_cam > st->camera_x) st->camera_x = target_cam;
    if (st->camera_x > MS_WORLD_WIDTH - MS_BASE_VIEW_WIDTH) st->camera_x = MS_WORLD_WIDTH - MS_BASE_VIEW_WIDTH;
    if (st->camera_x < 0.0f) st->camera_x = 0.0f;

    /* 원작 순수 사격: 위 방향키를 누른 상태면 상단 발사, 아니면 정면 발사 (각도 스냅/자동 락온 없음) */
    if ((input_mask & MS_INPUT_FIRE) && p->fire_cooldown == 0) {
        int dmg = p->in_slug ? 3 : 1;
        if (input_mask & MS_INPUT_UP) {
            spawn_bullet(st, p->x + p->w * 0.5f, p->y - p->h - 6.0f,
                         0.0f, -MS_BULLET_SPEED, dmg, true, false);
        } else {
            float bx = (p->facing > 0) ? (p->x + p->w + 6.0f) : (p->x - 14.0f);
            float by = p->y - p->h * 0.55f;
            spawn_bullet(st, bx, by, (float)p->facing * MS_BULLET_SPEED, 0.0f, dmg, true, false);
        }
        p->fire_cooldown = p->in_slug ? 7 : 9;
    }

    if ((input_mask & MS_INPUT_GRENADE) && p->grenade_count > 0 && p->fire_cooldown == 0) {
        p->grenade_count--;
        p->fire_cooldown = 18;
        spawn_bullet(st, p->x + p->w * 0.5f, p->y - p->h * 0.7f,
                     (float)p->facing * 360.0f, -460.0f, 6, true, true);
    }

    for (int i = 0; i < MS_MAX_BULLETS; ++i) {
        ms_bullet_t *b = &st->bullets[i];
        if (!b->active) continue;
        if (b->is_grenade) b->vy += MS_GRAVITY * 0.75f * dt_sec;
        b->x += b->vx * dt_sec;
        b->y += b->vy * dt_sec;
        b->ttl_frames--;

        if (b->is_grenade && b->y >= MS_GROUND_Y) {
            b->y = MS_GROUND_Y;
            b->vy = -b->vy * 0.35f;
            b->vx *= 0.65f;
        }

        if (b->ttl_frames <= 0 ||
            b->x < st->camera_x - 200.0f || b->x > st->camera_x + MS_BASE_VIEW_WIDTH + 200.0f ||
            b->y < -120.0f || b->y > MS_BASE_VIEW_HEIGHT + 120.0f) {
            if (b->is_grenade && b->ttl_frames <= 0) spawn_particles(st, b->x, b->y, 8, 0xFFFF9900);
            b->active = false;
            continue;
        }

        if (b->from_player) {
            for (int e = 0; e < MS_MAX_ENEMIES; ++e) {
                ms_enemy_t *en = &st->enemies[e];
                if (!en->active) continue;
                float ew = (en->kind == MS_ENEMY_TANK || en->kind == MS_ENEMY_HELI) ? 72.0f : 48.0f;
                float eh = 56.0f;
                if (aabb_overlap(b->x - 10.0f, b->y - 10.0f, 20.0f, 20.0f,
                                 en->x, en->y - eh, ew, eh)) {
                    en->hp -= b->damage;
                    b->active = false;
                    spawn_particles(st, b->x, b->y, 5, 0xFFFFDD33);
                    if (en->hp <= 0) {
                        en->active = false;
                        st->score += en->score_value;
                        if (st->score > st->best_score) st->best_score = st->score;
                        spawn_particles(st, en->x + ew * 0.5f, en->y - eh * 0.5f, 12, 0xFFFF5522);
                    }
                    break;
                }
            }
        } else {
            if (p->invuln_frames == 0 &&
                aabb_overlap(b->x - 6.0f, b->y - 6.0f, 12.0f, 12.0f,
                             p->x, p->y - p->h, p->w, p->h)) {
                b->active = false;
                p->invuln_frames = 45;
                if (p->in_slug) {
                    p->slug_hp -= b->damage;
                    if (p->slug_hp <= 0) {
                        p->slug_hp = 0; p->in_slug = false; p->w = 44.0f; p->h = 64.0f;
                        spawn_particles(st, p->x + 20.0f, p->y - 30.0f, 12, 0xFFFF3300);
                        set_diag(st, "metal slug destroyed; ejected player");
                    }
                } else {
                    p->hp -= b->damage;
                    if (p->hp <= 0) {
                        p->hp = 0; st->game_over = true;
                        set_diag(st, "player hp reached zero; game over");
                    }
                }
            }
        }
    }

    for (int i = 0; i < MS_MAX_ENEMIES; ++i) {
        ms_enemy_t *en = &st->enemies[i];
        if (!en->active) continue;
        if (en->x < st->camera_x - 160.0f || en->x > st->camera_x + MS_BASE_VIEW_WIDTH + 300.0f) continue;

        if (en->kind == MS_ENEMY_PARATROOPER) {
            en->y += en->vy * dt_sec;
            if (en->y >= MS_GROUND_Y) { en->y = MS_GROUND_Y; en->vy = 0.0f; en->vx = -55.0f; }
        } else if (en->kind == MS_ENEMY_HELI) {
            en->x += en->vx * dt_sec;
            en->y = en->base_y + sinf((float)st->tick_count * 0.08f) * 14.0f;
        } else {
            en->x += en->vx * dt_sec;
        }

        en->ai_timer--;
        if (en->ai_timer <= 0) {
            en->ai_timer = (en->kind == MS_ENEMY_TANK || en->kind == MS_ENEMY_HELI) ? 110 : 90;
            float dx = (p->x + p->w * 0.5f) - (en->x + 24.0f);
            float dy = (p->y - p->h * 0.5f) - (en->y - 28.0f);
            float dist = sqrtf(dx * dx + dy * dy);
            if (dist < 1.0f) dist = 1.0f;
            spawn_bullet(st, en->x + 24.0f, en->y - 28.0f,
                         (dx / dist) * 320.0f, (dy / dist) * 320.0f, 1, false, false);
        }
    }

    for (int i = 0; i < MS_MAX_PARTICLES; ++i) {
        ms_particle_t *pt = &st->particles[i];
        if (!pt->active) continue;
        pt->vy += MS_GRAVITY * 0.5f * dt_sec;
        pt->x += pt->vx * dt_sec;
        pt->y += pt->vy * dt_sec;
        pt->life--;
        if (pt->life <= 0) pt->active = false;
    }
}

size_t ms_export_prefs_blob(const ms_game_state_t *st, uint8_t *out_buf, size_t cap) {
    if (!st || !out_buf || cap < 16) return 0;
    uint32_t magic = 0x4D534F52u; /* "MSOR" Original */
    uint32_t best  = (uint32_t)(st->best_score > 0 ? st->best_score : 0);
    uint8_t flags  = (uint8_t)((st->switches.safe_mode_fallback ? 1 : 0) |
                               (st->switches.high_contrast_hud ? 2 : 0) |
                               (st->switches.sound_enabled ? 4 : 0) |
                               (st->switches.hi_res_upscale ? 8 : 0));
    uint8_t ui_pct  = (uint8_t)(st->switches.ui_scale_percent > 250 ? 250 : st->switches.ui_scale_percent);
    uint8_t rnd_pct = (uint8_t)(st->switches.render_scale_percent > 200 ? 200 : st->switches.render_scale_percent);
    uint8_t tier    = (uint8_t)(st->switches.remaster_tier >= 2 ? 2 : 1);

    memcpy(out_buf + 0, &magic, sizeof(magic));
    memcpy(out_buf + 4, &best, sizeof(best));
    out_buf[8] = flags; out_buf[9] = ui_pct; out_buf[10] = rnd_pct; out_buf[11] = tier;
    out_buf[12] = 0; out_buf[13] = 0; out_buf[14] = 0; out_buf[15] = 0;
    return 16;
}

bool ms_import_prefs_blob(ms_game_state_t *st, const uint8_t *in_buf, size_t len) {
    if (!st || !in_buf || len < 12) return false;
    uint32_t magic = 0, best = 0;
    memcpy(&magic, in_buf + 0, sizeof(magic));
    if (magic != 0x4D534F52u) return false;
    memcpy(&best, in_buf + 4, sizeof(best));
    st->best_score = (int)best;
    st->switches.safe_mode_fallback   = (in_buf[8] & 1) != 0;
    st->switches.high_contrast_hud    = (in_buf[8] & 2) != 0;
    st->switches.sound_enabled        = (in_buf[8] & 4) != 0;
    st->switches.hi_res_upscale       = (in_buf[8] & 8) != 0;
    st->switches.ui_scale_percent     = in_buf[9] >= 100 ? (int)in_buf[9] : 150;
    st->switches.render_scale_percent = in_buf[10] >= 100 ? (int)in_buf[10] : 150;
    st->switches.remaster_tier        = in_buf[11] == 2 ? 2 : 1;
    ms_recalc_resolution(st);
    return true;
}
