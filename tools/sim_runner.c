#include "ms_game.h"
#include <stdio.h>
#include <string.h>

int main(void) {
    ms_game_state_t game;
    ms_switches_t sw = {
        .safe_mode_fallback   = false,
        .high_contrast_hud    = true,
        .sound_enabled        = true,
        .ui_scale_percent     = 150,
        .hi_res_upscale       = true,
        .render_scale_percent = 200,
        .remaster_tier        = 2
    };

    ms_game_init(&game, 1, 0, sw);

    for (int f = 0; f < 180; ++f) {
        uint32_t mask = MS_INPUT_RIGHT | MS_INPUT_FIRE;
        if (f == 20) mask |= MS_INPUT_SLUG_TOGGLE;
        if (f == 90) mask |= MS_INPUT_UP;
        if (f == 110) mask |= MS_INPUT_GRENADE;
        ms_game_step(&game, mask, 1.0f / 60.0f);
    }

    uint8_t blob[16] = {0};
    size_t blob_len = ms_export_prefs_blob(&game, blob, sizeof(blob));
    ms_game_state_t restored;
    memset(&restored, 0, sizeof(restored));
    bool ok = ms_import_prefs_blob(&restored, blob, blob_len);

    printf("[PURE_ORIGINAL] tick=%u score=%d best=%d res=%dx%d tier=%d blob_len=%zu restore_ok=%d diag=\"%s\"\n",
           game.tick_count, game.score, game.best_score,
           game.target_width, game.target_height, game.switches.remaster_tier,
           blob_len, ok ? 1 : 0, game.last_diag_note);

    ms_release_stage_assets(&game);
    return (ok && game.score > 0) ? 0 : 1;
}
