#ifndef MS_GAME_H
#define MS_GAME_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define MS_MAX_BULLETS      64
#define MS_MAX_ENEMIES      32
#define MS_MAX_PARTICLES    96
#define MS_MAX_EFFECTS      24
#define MS_WORLD_WIDTH      4800.0f
#define MS_GROUND_Y         540.0f
#define MS_BASE_VIEW_WIDTH  1920.0f
#define MS_BASE_VIEW_HEIGHT 1080.0f
#define MS_DIAG_LEN         160

typedef enum {
    MS_ENEMY_INFANTRY     = 1,
    MS_ENEMY_TANK         = 2,
    MS_ENEMY_BUNKER_GUARD = 3,
    MS_ENEMY_TOWER_GUARD  = 4,
    MS_ENEMY_PARATROOPER  = 5,
    MS_ENEMY_HELI         = 6
} ms_enemy_kind_t;

typedef struct {
    bool safe_mode_fallback;
    bool high_contrast_hud;
    bool sound_enabled;
    int  ui_scale_percent;
    bool hi_res_upscale;
    int  render_scale_percent; /* 100 (1080p), 150 (1620p), 200 (2160p/4K) */
    int  remaster_tier;        /* 1: 기본, 2: 고해상도 리마스터 */
} ms_switches_t;

typedef enum {
    MS_INPUT_NONE        = 0,
    MS_INPUT_LEFT        = 1 << 0,
    MS_INPUT_RIGHT       = 1 << 1,
    MS_INPUT_UP          = 1 << 2, /* 원작 방식: 누른 채 사격하면 상단 발사 */
    MS_INPUT_JUMP        = 1 << 3,
    MS_INPUT_FIRE        = 1 << 4,
    MS_INPUT_GRENADE     = 1 << 5,
    MS_INPUT_SLUG_TOGGLE = 1 << 6,
    MS_INPUT_PAUSE       = 1 << 7
} ms_input_mask_t;

/* 애니메이션 상태 — 렌더러가 어떤 스프라이트 시트를 쓸지 고른다 */
typedef enum {
    MS_ANIM_IDLE = 0,
    MS_ANIM_RUN,
    MS_ANIM_JUMP,
    MS_ANIM_FALL,
    MS_ANIM_FIRE,
    MS_ANIM_FIRE_UP,
    MS_ANIM_HIT,
    MS_ANIM_DEAD
} ms_anim_state_t;

/* 한 틱 동안 일어난 소리 이벤트. 렌더러가 읽고 지운다. */
typedef enum {
    MS_SFX_SHOOT     = 1 << 0,
    MS_SFX_GRENADE   = 1 << 1,
    MS_SFX_EXPLOSION = 1 << 2,
    MS_SFX_JUMP      = 1 << 3,
    MS_SFX_HIT       = 1 << 4,
    MS_SFX_PICKUP    = 1 << 5,
    MS_SFX_SLUG      = 1 << 6,
    MS_SFX_GAMEOVER  = 1 << 7
} ms_sfx_bit_t;

typedef enum {
    MS_FX_EXPLOSION = 0,
    MS_FX_IMPACT,
    MS_FX_SMOKE,
    MS_FX_MUZZLE
} ms_effect_kind_t;

typedef struct {
    bool  active;
    int   kind;
    float x, y;
    float scale;
    int   frame;
    int   timer;
} ms_effect_t;

typedef struct {
    float x, y;
    float vx, vy;
    float w, h;
    int   hp;
    int   facing;        /* -1: 좌, 1: 우 */
    bool  on_ground;
    bool  in_slug;
    int   slug_hp;
    int   fire_cooldown;
    int   grenade_count;
    int   invuln_frames;
    int   anim_state;      /* ms_anim_state_t */
    int   anim_timer;      /* 현재 상태로 들어온 뒤 지난 프레임 수 */
    int   muzzle_timer;    /* 총구 화염을 그릴 남은 프레임 */
    bool  fired_up;        /* 마지막 사격이 상단 사격이었나 */
} ms_player_t;

typedef struct {
    bool  active;
    bool  from_player;
    bool  is_grenade;
    float x, y;
    float vx, vy;
    int   damage;
    int   ttl_frames;
} ms_bullet_t;

typedef struct {
    bool  active;
    int   kind;
    float x, y;
    float base_y;
    float vx, vy;
    int   hp;
    int   max_hp;
    int   ai_timer;
    int   score_value;
    int   anim_timer;
    int   facing;          /* -1 좌, 1 우 */
    int   hit_flash;       /* 피격 섬광 남은 프레임 */
    int   death_timer;     /* 0보다 크면 사망 연출 중 */
} ms_enemy_t;

typedef struct {
    bool     active;
    float    x, y;
    float    vx, vy;
    int      life;
    uint32_t color_argb;
} ms_particle_t;

typedef struct {
    bool          initialized;
    bool          paused;
    bool          game_over;
    uint32_t      tick_count;
    int           score;
    int           best_score;
    int           stage_index;
    float         camera_x;
    float         effective_render_scale;
    int           target_width;
    int           target_height;
    size_t        approx_mem_bytes;
    ms_switches_t switches;
    ms_player_t   player;
    ms_bullet_t   bullets[MS_MAX_BULLETS];
    ms_enemy_t    enemies[MS_MAX_ENEMIES];
    ms_particle_t particles[MS_MAX_PARTICLES];
    ms_effect_t   effects[MS_MAX_EFFECTS];
    uint32_t      sfx_events;   /* ms_sfx_bit_t 의 OR */
    char          last_diag_note[MS_DIAG_LEN];
} ms_game_state_t;

void   ms_game_init(ms_game_state_t *st, int stage_index, int saved_best_score, ms_switches_t initial_sw);
void   ms_recalc_resolution(ms_game_state_t *st);
void   ms_game_step(ms_game_state_t *st, uint32_t input_mask, float dt_sec);
void   ms_release_stage_assets(ms_game_state_t *st);
void   ms_spawn_effect(ms_game_state_t *st, int kind, float x, float y, float scale);
size_t ms_export_prefs_blob(const ms_game_state_t *st, uint8_t *out_buf, size_t cap);
bool   ms_import_prefs_blob(ms_game_state_t *st, const uint8_t *in_buf, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* MS_GAME_H */
