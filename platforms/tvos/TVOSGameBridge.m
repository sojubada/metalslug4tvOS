#import "TVOSGameBridge.h"
#import <math.h>

static NSString *const kMSOrigPrefsBlobKey = @"com.tvos166.metalslug.original.prefs.v1";

@implementation TVOSGameView

- (BOOL)canBecomeFocused { return YES; }

- (void)loadPreferencesFromDefaults {
    if (!self.gameState) return;
    NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:kMSOrigPrefsBlobKey];
    if (data && data.length >= 12) {
        ms_import_prefs_blob(self.gameState, (const uint8_t *)data.bytes, data.length);
    }
}

- (void)savePreferencesToDefaults {
    if (!self.gameState) return;
    uint8_t buf[16] = {0};
    size_t n = ms_export_prefs_blob(self.gameState, buf, sizeof(buf));
    if (n > 0) {
        NSData *data = [NSData dataWithBytes:buf length:n];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:kMSOrigPrefsBlobKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)applyResolutionSettings {
    ms_game_state_t *st = self.gameState;
    if (!st) return;
    CGFloat desiredScale = (CGFloat)st->effective_render_scale;
    if (st->switches.remaster_tier >= 2 && desiredScale < 1.5 && st->switches.hi_res_upscale) desiredScale = 1.5;
    if (desiredScale > 2.0) desiredScale = 2.0;
    if (desiredScale < 1.0) desiredScale = 1.0;
    self.contentScaleFactor = desiredScale;
    [self setNeedsDisplay];
}

- (void)cycleResolutionScale {
    ms_game_state_t *st = self.gameState;
    if (!st) return;
    int cur = st->switches.render_scale_percent;
    int next = (cur < 150) ? 150 : ((cur < 200) ? 200 : 100);
    st->switches.hi_res_upscale = (next > 100);
    st->switches.render_scale_percent = next;
    ms_recalc_resolution(st);
    [self applyResolutionSettings];
    [self savePreferencesToDefaults];
}

- (uint32_t)pollCombinedInputMask {
    uint32_t mask = self.activeInputMask;
    for (GCController *ctrl in [GCController controllers]) {
        if (ctrl.extendedGamepad) {
            GCExtendedGamepad *gp = ctrl.extendedGamepad;
            if (gp.dpad.left.isPressed || gp.leftThumbstick.xAxis.value < -0.35f)  mask |= MS_INPUT_LEFT;
            if (gp.dpad.right.isPressed || gp.leftThumbstick.xAxis.value > 0.35f)  mask |= MS_INPUT_RIGHT;
            if (gp.dpad.up.isPressed || gp.leftThumbstick.yAxis.value > 0.45f)     mask |= MS_INPUT_UP;
            if (gp.buttonA.isPressed) mask |= MS_INPUT_JUMP;
            if (gp.buttonX.isPressed || gp.rightTrigger.isPressed) mask |= MS_INPUT_FIRE;
            if (gp.buttonB.isPressed) mask |= MS_INPUT_GRENADE;
            if (gp.buttonY.isPressed) mask |= MS_INPUT_SLUG_TOGGLE;
        }
    }
    return mask;
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    for (UIPress *p in presses) {
        UIKey *key = p.key;
        if (key) {
            NSString *ch = key.charactersIgnoringModifiers.lowercaseString;
            if ([ch isEqualToString:@"a"] || key.keyCode == UIKeyboardHIDUsageKeyboardLeftArrow) self.activeInputMask |= MS_INPUT_LEFT;
            else if ([ch isEqualToString:@"d"] || key.keyCode == UIKeyboardHIDUsageKeyboardRightArrow) self.activeInputMask |= MS_INPUT_RIGHT;
            else if (key.keyCode == UIKeyboardHIDUsageKeyboardUpArrow) self.activeInputMask |= MS_INPUT_UP;
            else if ([ch isEqualToString:@"w"] || key.keyCode == UIKeyboardHIDUsageKeyboardSpacebar) self.activeInputMask |= MS_INPUT_JUMP;
            else if ([ch isEqualToString:@"j"] || [ch isEqualToString:@"z"]) self.activeInputMask |= MS_INPUT_FIRE;
            else if ([ch isEqualToString:@"k"] || [ch isEqualToString:@"x"]) self.activeInputMask |= MS_INPUT_GRENADE;
            else if ([ch isEqualToString:@"e"] || key.keyCode == UIKeyboardHIDUsageKeyboardReturnOrEnter) self.activeInputMask |= MS_INPUT_SLUG_TOGGLE;
            else if ([ch isEqualToString:@"r"]) [self cycleResolutionScale];
            else if (key.keyCode == UIKeyboardHIDUsageKeyboardEscape || [ch isEqualToString:@"p"]) self.activeInputMask |= MS_INPUT_PAUSE;
        } else if (p.type == UIPressTypeSelect) self.activeInputMask |= MS_INPUT_FIRE;
        else if (p.type == UIPressTypePlayPause) self.activeInputMask |= MS_INPUT_PAUSE;
    }
    [super pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    for (UIPress *p in presses) {
        UIKey *key = p.key;
        if (key) {
            NSString *ch = key.charactersIgnoringModifiers.lowercaseString;
            if ([ch isEqualToString:@"a"] || key.keyCode == UIKeyboardHIDUsageKeyboardLeftArrow) self.activeInputMask &= ~MS_INPUT_LEFT;
            else if ([ch isEqualToString:@"d"] || key.keyCode == UIKeyboardHIDUsageKeyboardRightArrow) self.activeInputMask &= ~MS_INPUT_RIGHT;
            else if (key.keyCode == UIKeyboardHIDUsageKeyboardUpArrow) self.activeInputMask &= ~MS_INPUT_UP;
            else if ([ch isEqualToString:@"w"] || key.keyCode == UIKeyboardHIDUsageKeyboardSpacebar) self.activeInputMask &= ~MS_INPUT_JUMP;
            else if ([ch isEqualToString:@"j"] || [ch isEqualToString:@"z"]) self.activeInputMask &= ~MS_INPUT_FIRE;
            else if ([ch isEqualToString:@"k"] || [ch isEqualToString:@"x"]) self.activeInputMask &= ~MS_INPUT_GRENADE;
            else if ([ch isEqualToString:@"e"] || key.keyCode == UIKeyboardHIDUsageKeyboardReturnOrEnter) self.activeInputMask &= ~MS_INPUT_SLUG_TOGGLE;
            else if (key.keyCode == UIKeyboardHIDUsageKeyboardEscape || [ch isEqualToString:@"p"]) self.activeInputMask &= ~MS_INPUT_PAUSE;
        } else if (p.type == UIPressTypeSelect) self.activeInputMask &= ~MS_INPUT_FIRE;
        else if (p.type == UIPressTypePlayPause) self.activeInputMask &= ~MS_INPUT_PAUSE;
    }
    [super pressesEnded:presses withEvent:event];
}

- (void)drawCrispBullets:(CGContextRef)ctx state:(ms_game_state_t *)st sx:(float)sx sy:(float)sy {
    CGFloat s = MAX(1.0f, sx);
    CGContextSaveGState(ctx);
    CGContextSetLineCap(ctx, kCGLineCapRound);

    for (int i = 0; i < MS_MAX_BULLETS; ++i) {
        ms_bullet_t *b = &st->bullets[i];
        if (!b->active) continue;
        CGFloat bx = (b->x - st->camera_x) * sx;
        CGFloat by = b->y * sy;

        if (b->is_grenade) {
            CGRect gr = CGRectMake(bx - 8.0 * s, by - 8.0 * s, 16.0 * s, 16.0 * s);
            [[UIColor blackColor] setFill];
            CGContextFillEllipseInRect(ctx, CGRectInset(gr, -2.0 * s, -2.0 * s));
            [[UIColor colorWithRed:0.35 green:0.80 blue:0.30 alpha:1.0] setFill];
            CGContextFillEllipseInRect(ctx, gr);
            continue;
        }

        if (b->from_player) {
            float spd = sqrtf(b->vx * b->vx + b->vy * b->vy);
            float ux = (spd > 1.0f) ? (b->vx / spd) : 1.0f;
            float uy = (spd > 1.0f) ? (b->vy / spd) : 0.0f;
            CGFloat tx = bx - ux * 26.0 * s;
            CGFloat ty = by - uy * 26.0 * s;

            CGContextSetStrokeColorWithColor(ctx, [[UIColor blackColor] colorWithAlphaComponent:0.85].CGColor);
            CGContextSetLineWidth(ctx, 9.0 * s);
            CGContextBeginPath(ctx); CGContextMoveToPoint(ctx, tx, ty); CGContextAddLineToPoint(ctx, bx, by); CGContextStrokePath(ctx);

            CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:1.0 green:0.82 blue:0.12 alpha:1.0].CGColor);
            CGContextSetLineWidth(ctx, 5.5 * s);
            CGContextBeginPath(ctx); CGContextMoveToPoint(ctx, tx, ty); CGContextAddLineToPoint(ctx, bx, by); CGContextStrokePath(ctx);

            CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:1.0 green:1.0 blue:0.85 alpha:1.0].CGColor);
            CGContextSetLineWidth(ctx, 2.5 * s);
            CGContextBeginPath(ctx); CGContextMoveToPoint(ctx, bx - ux * 10.0 * s, by - uy * 10.0 * s); CGContextAddLineToPoint(ctx, bx, by); CGContextStrokePath(ctx);
        } else {
            CGRect er = CGRectMake(bx - 6.5 * s, by - 6.5 * s, 13.0 * s, 13.0 * s);
            [[UIColor blackColor] setFill];
            CGContextFillEllipseInRect(ctx, CGRectInset(er, -2.0 * s, -2.0 * s));
            [[UIColor colorWithRed:1.0 green:0.35 blue:0.15 alpha:1.0] setFill];
            CGContextFillEllipseInRect(ctx, er);
        }
    }
    CGContextRestoreGState(ctx);
}

- (void)drawHighResHUD:(ms_game_state_t *)st viewBounds:(CGRect)rect {
    CGFloat baseAspectScale = MIN(rect.size.width / 1920.0, rect.size.height / 1080.0);
    CGFloat uiScale = ((CGFloat)st->switches.ui_scale_percent / 100.0) * MAX(1.0, baseAspectScale);
    UIFont *hudFont = [UIFont monospacedSystemFontOfSize:24.0 * uiScale weight:UIFontWeightBold];
    NSString *hudText = [NSString stringWithFormat:@"HP:%d  SLUG:%d  GRN:%d  SCORE:%d  BEST:%d  RES:%dx%d (T%d)",
                         st->player.hp, st->player.slug_hp, st->player.grenade_count,
                         st->score, st->best_score, st->target_width, st->target_height,
                         st->switches.remaster_tier];
    NSDictionary *attrs = @{
        NSFontAttributeName: hudFont,
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSBackgroundColorAttributeName: [[UIColor blackColor] colorWithAlphaComponent:0.80]
    };
    [hudText drawAtPoint:CGPointMake(28.0 * uiScale, 24.0 * uiScale) withAttributes:attrs];
}

- (void)drawRect:(CGRect)rect {
    ms_game_state_t *st = self.gameState;
    if (!st || !st->initialized) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    float sx = rect.size.width / 1920.0f;
    float sy = rect.size.height / 1080.0f;

    /* 다층 사막 노을 배경 (그래픽 향상) */
    [[UIColor colorWithRed:0.34 green:0.42 blue:0.52 alpha:1.0] setFill];
    CGContextFillRect(ctx, CGRectMake(0, 0, rect.size.width, 280.0f * sy));
    [[UIColor colorWithRed:0.78 green:0.58 blue:0.38 alpha:1.0] setFill];
    CGContextFillRect(ctx, CGRectMake(0, 280.0f * sy, rect.size.width, (MS_GROUND_Y - 280.0f) * sy));
    [[UIColor colorWithRed:0.65 green:0.48 blue:0.28 alpha:1.0] setFill];
    CGContextFillRect(ctx, CGRectMake(0, MS_GROUND_Y * sy, rect.size.width, rect.size.height - (MS_GROUND_Y * sy)));

    float px = (st->player.x - st->camera_x) * sx;
    float py = (st->player.y - st->player.h) * sy;
    UIColor *pColor = st->player.in_slug
        ? [UIColor colorWithRed:0.95 green:0.75 blue:0.15 alpha:1.0]
        : [UIColor colorWithRed:0.22 green:0.68 blue:0.34 alpha:1.0];
    [pColor setFill];
    CGContextFillRect(ctx, CGRectMake(px, py, st->player.w * sx, st->player.h * sy));

    for (int i = 0; i < MS_MAX_ENEMIES; ++i) {
        ms_enemy_t *en = &st->enemies[i];
        if (!en->active) continue;
        float ew = (en->kind == MS_ENEMY_TANK || en->kind == MS_ENEMY_HELI) ? 72.0f : 48.0f;
        float eh = 56.0f;
        float ex = (en->x - st->camera_x) * sx;
        float ey = (en->y - eh) * sy;

        if (en->kind == MS_ENEMY_TOWER_GUARD) {
            [[UIColor colorWithRed:0.42 green:0.30 blue:0.18 alpha:1.0] setFill];
            CGContextFillRect(ctx, CGRectMake(ex + 6.0f * sx, en->y * sy, (ew - 12.0f) * sx, (MS_GROUND_Y - en->y) * sy));
        } else if (en->kind == MS_ENEMY_BUNKER_GUARD) {
            [[UIColor colorWithRed:0.48 green:0.43 blue:0.32 alpha:1.0] setFill];
            CGContextFillRect(ctx, CGRectMake(ex - 16.0f * sx, en->y * sy, (ew + 32.0f) * sx, (MS_GROUND_Y - en->y) * sy));
        } else if (en->kind == MS_ENEMY_PARATROOPER) {
            [[UIColor colorWithRed:0.55 green:0.65 blue:0.45 alpha:1.0] setFill];
            CGContextFillEllipseInRect(ctx, CGRectMake(ex - 14.0f * sx, ey - 34.0f * sy, (ew + 28.0f) * sx, 30.0f * sy));
        }

        [[UIColor colorWithRed:0.84 green:0.22 blue:0.20 alpha:1.0] setFill];
        CGContextFillRect(ctx, CGRectMake(ex, ey, ew * sx, eh * sy));
    }

    for (int i = 0; i < MS_MAX_PARTICLES; ++i) {
        ms_particle_t *pt = &st->particles[i];
        if (!pt->active) continue;
        [[UIColor colorWithRed:1.0 green:0.75 blue:0.2 alpha:1.0] setFill];
        CGContextFillRect(ctx, CGRectMake((pt->x - st->camera_x) * sx, pt->y * sy, 7.0f * sx, 7.0f * sy));
    }

    /* 각도 표기·십자 과녁 없이 순수 탄환과 HUD만 렌더링 */
    [self drawCrispBullets:ctx state:st sx:sx sy:sy];
    [self drawHighResHUD:st viewBounds:rect];
}

@end
