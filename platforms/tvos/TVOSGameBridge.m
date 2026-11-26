#import "TVOSGameBridge.h"
#import "MSSprite.h"
#import "MSLog.h"
#import <math.h>

static NSString *const kMSOrigPrefsBlobKey = @"com.tvos166.metalslug.original.prefs.v1";

/* 화면 구성
 *
 * 게임 세계는 1920x1080 을 기준으로 짜여 있고 지면은 y=540 이다. 그대로 그리면
 * 지면이 화면 한가운데에 와서 아래쪽 절반이 빈 모래밭이 된다. 그래서 지면을
 * 화면 높이의 78% 지점에 놓고 그만큼 확대한다. 1080p 에서 배율은 1.56 이 되고
 * 가로로 보이는 세계는 약 1230 단위가 된다.
 */
static const CGFloat kGroundScreenRatio = 0.78;

@implementation TVOSGameView {
    MSSpriteSheet *_shRun, *_shJump, *_shFire, *_shHit;
    MSSpriteSheet *_shEnemyRun, *_shEnemyAttack, *_shEnemyDeath, *_shGrenadier, *_shPara;
    MSSpriteSheet *_shTank, *_shHeli, *_shSlug, *_shBunker;
    MSSpriteSheet *_shExplosion, *_shMuzzle, *_shBullets, *_shSmoke, *_shImpact;
    MSSpriteSheet *_shGround, *_shBGFar, *_shBGMid, *_shDigits, *_shIcons;
    BOOL _sheetsReady;
}

- (BOOL)canBecomeFocused { return YES; }

- (void)loadSheetsIfNeeded {
    if (_sheetsReady) return;
    MSSpriteStore *st = [MSSpriteStore shared];
    _shRun         = [st sheet:@"Character/Player/Run" frames:6];
    _shJump        = [st sheet:@"Character/Player/Jump" frames:3];
    _shFire        = [st sheet:@"Character/Player/Fire" frames:4];
    _shHit         = [st sheet:@"Character/Player/Hit" frames:4];
    _shEnemyRun    = [st sheet:@"Character/Enemy/Soldier/Soldier_Run" frames:4];
    _shEnemyAttack = [st sheet:@"Character/Enemy/Soldier/Soldier_Attack" frames:3];
    _shEnemyDeath  = [st sheet:@"Character/Enemy/Soldier/Soldier_Death" frames:4];
    _shGrenadier   = [st sheet:@"Character/Enemy/Soldier/Grenadier" frames:3];
    _shPara        = [st sheet:@"Character/Enemy/Soldier/Paratrooper" frames:2];
    _shTank        = [st sheet:@"Character/Enemy/Vehicle/Tank" frames:1];
    _shHeli        = [st sheet:@"Character/Enemy/Vehicle/Heli" frames:2];
    _shSlug        = [st sheet:@"Vehicle/Player/Slug" frames:1];
    _shBunker      = [st sheet:@"Map/Bunker" frames:1];
    _shExplosion   = [st sheet:@"WeaponSFX/Explosion" frames:6];
    _shMuzzle      = [st sheet:@"WeaponSFX/Muzzle" frames:3];
    _shBullets     = [st sheet:@"WeaponSFX/Bullets" frames:4];
    _shSmoke       = [st sheet:@"WeaponSFX/Smoke" frames:5];
    _shImpact      = [st sheet:@"WeaponSFX/Impact" frames:4];
    _shGround      = [st sheet:@"Map/Ground_Tile" frames:1];
    _shBGFar       = [st sheet:@"Map/BG_Far" frames:1];
    _shBGMid       = [st sheet:@"Map/BG_Mid" frames:6];
    _shDigits      = [st sheet:@"UI/Font_Numbers" frames:10];
    _shIcons       = [st sheet:@"UI/HUD_Icons" frames:5];
    _sheetsReady = YES;
}

#pragma mark - 설정 저장

- (void)loadPreferencesFromDefaults {
    if (!self.gameState) return;
    NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:kMSOrigPrefsBlobKey];
    if (data && data.length >= 12) {
        BOOL ok = ms_import_prefs_blob(self.gameState, (const uint8_t *)data.bytes, data.length);
        [MSLog info:MSLogCatPrefs fmt:@"설정 복원 len=%lu ok=%d", (unsigned long)data.length, ok];
    } else {
        [MSLog info:MSLogCatPrefs fmt:@"저장된 설정이 없다 — 기본값으로 시작"];
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
        [MSLog info:MSLogCatPrefs fmt:@"설정 저장 len=%zu best=%d", n, self.gameState->best_score];
    } else {
        [MSLog error:MSLogCatPrefs domain:@"MSPrefs" code:1 msg:@"설정 직렬화 실패 (0바이트)"];
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
    [MSLog info:MSLogCatRender fmt:@"렌더 배율 %.2f (%dx%d, tier=%d)",
          desiredScale, st->target_width, st->target_height, st->switches.remaster_tier];
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
    [MSLog info:MSLogCatInput fmt:@"해상도 배율 전환 %d%% -> %d%%", cur, next];
}

#pragma mark - 입력

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

#pragma mark - 좌표 변환

/// 세계 좌표를 화면 좌표로 바꾸는 배율
- (CGFloat)worldScaleForRect:(CGRect)rect {
    return (rect.size.height * kGroundScreenRatio) / MS_GROUND_Y;
}

/// 발밑 중심을 기준으로 스프라이트를 놓는다. 높이를 주면 가로는 비율대로 따라간다.
- (void)drawSheet:(MSSpriteSheet *)sheet frame:(NSInteger)frame
              ctx:(CGContextRef)ctx footX:(CGFloat)fx footY:(CGFloat)fy
           height:(CGFloat)h flip:(BOOL)flip tint:(UIColor *)tint alpha:(CGFloat)alpha {
    if (!sheet.valid) return;
    CGFloat aspect = sheet.frameWidth / MAX(1.0, sheet.frameHeight);
    CGFloat w = h * aspect;
    CGRect dest = CGRectMake(fx - w * 0.5, fy - h, w, h);
    MSDrawSpriteFrame(ctx, sheet, frame, dest, flip, tint, alpha);
}

#pragma mark - 배경

- (void)drawBackground:(CGContextRef)ctx rect:(CGRect)rect scale:(CGFloat)k camera:(CGFloat)camX {
    CGFloat groundY = rect.size.height * kGroundScreenRatio;

    // 하늘 — 위는 짙은 청보라, 아래는 사막 노을
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat comps[] = { 0.17, 0.21, 0.38, 1.0,
                        0.52, 0.42, 0.46, 1.0,
                        0.93, 0.66, 0.37, 1.0 };
    CGFloat locs[] = { 0.0, 0.55, 1.0 };
    CGGradientRef grad = CGGradientCreateWithColorComponents(cs, comps, locs, 3);
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, CGRectMake(0, 0, rect.size.width, groundY));
    CGContextDrawLinearGradient(ctx, grad, CGPointMake(0, 0), CGPointMake(0, groundY), 0);
    CGContextRestoreGState(ctx);
    CGGradientRelease(grad);
    CGColorSpaceRelease(cs);

    // 해
    CGFloat sunR = rect.size.height * 0.13;
    CGFloat sunX = rect.size.width * 0.72 - fmodf(camX * 0.06f, rect.size.width);
    [[UIColor colorWithRed:1.0 green:0.80 blue:0.42 alpha:1.0] setFill];
    CGContextFillEllipseInRect(ctx, CGRectMake(sunX - sunR, groundY - sunR * 2.1, sunR * 2, sunR * 2));

    // 원경 능선 — 시차 0.25 로 천천히 흐른다
    if (_shBGFar.valid) {
        CGFloat h = rect.size.height * 0.26;
        CGFloat w = h * (_shBGFar.frameWidth / MAX(1.0, _shBGFar.frameHeight));
        CGFloat off = fmodf(camX * 0.25f * k, w);
        for (CGFloat x = -off - w; x < rect.size.width + w; x += w) {
            MSDrawSpriteFrame(ctx, _shBGFar, 0, CGRectMake(x, groundY - h, w + 1, h), NO, nil, 1.0);
        }
    }

    // 중경 소품 — 시차 0.6. 위치는 좌표 해시로 정하므로 매 프레임 같은 자리에 선다.
    if (_shBGMid.valid) {
        CGFloat h = rect.size.height * 0.20;
        CGFloat spacing = 520.0;
        CGFloat px = camX * 0.6f;
        long first = (long)floor(px / spacing) - 1;
        for (long i = first; i < first + 8; i++) {
            unsigned long hash = (unsigned long)(i * 2654435761u);
            NSInteger kind = (NSInteger)(hash % 6);
            CGFloat jitter = (CGFloat)((hash >> 8) % 160) - 80.0;
            CGFloat sx = ((CGFloat)i * spacing + jitter - px) * k;
            if (sx < -300 || sx > rect.size.width + 300) continue;
            CGFloat hh = h * (0.8 + (CGFloat)((hash >> 16) % 40) / 100.0);
            [self drawSheet:_shBGMid frame:kind ctx:ctx footX:sx footY:groundY + 4
                     height:hh flip:((hash >> 24) & 1) tint:nil alpha:1.0];
        }
    }

    // 지면 — 타일을 가로로 반복해 깐다
    CGFloat belowH = rect.size.height - groundY;
    if (_shGround.valid) {
        CGFloat th = MAX(belowH, rect.size.height * 0.24);
        CGFloat tw = th * (_shGround.frameWidth / MAX(1.0, _shGround.frameHeight));
        CGFloat off = fmodf(camX * k, tw);
        for (CGFloat x = -off - tw; x < rect.size.width + tw; x += tw) {
            MSDrawSpriteFrame(ctx, _shGround, 0,
                              CGRectMake(x, groundY, tw + 1, th), NO, nil, 1.0);
        }
        if (th < belowH) {
            [[UIColor colorWithRed:0.55 green:0.40 blue:0.24 alpha:1.0] setFill];
            CGContextFillRect(ctx, CGRectMake(0, groundY + th, rect.size.width, belowH - th));
        }
    } else {
        [[UIColor colorWithRed:0.78 green:0.62 blue:0.41 alpha:1.0] setFill];
        CGContextFillRect(ctx, CGRectMake(0, groundY, rect.size.width, belowH));
    }
}

#pragma mark - 캐릭터

- (void)drawPlayer:(CGContextRef)ctx state:(ms_game_state_t *)st scale:(CGFloat)k {
    ms_player_t *p = &st->player;
    CGFloat fx = (p->x + p->w * 0.5f - st->camera_x) * k;
    CGFloat fy = p->y * k;
    BOOL flip = (p->facing < 0);

    if (p->in_slug) {
        CGFloat h = p->h * 1.15 * k;
        [self drawSheet:_shSlug frame:0 ctx:ctx footX:fx footY:fy height:h flip:flip tint:nil alpha:1.0];
        return;
    }

    MSSpriteSheet *sheet = _shRun;
    NSInteger frame = 0;
    switch (p->anim_state) {
        case MS_ANIM_RUN:     sheet = _shRun;  frame = (p->anim_timer / 5) % 6; break;
        case MS_ANIM_JUMP:    sheet = _shJump; frame = 1; break;
        case MS_ANIM_FALL:    sheet = _shJump; frame = 2; break;
        case MS_ANIM_FIRE:    sheet = _shFire; frame = (p->muzzle_timer > 3) ? 0 : 1; break;
        case MS_ANIM_FIRE_UP: sheet = _shFire; frame = 2; break;
        case MS_ANIM_HIT:     sheet = _shHit;  frame = MIN(1, p->anim_timer / 6); break;
        case MS_ANIM_DEAD:    sheet = _shHit;  frame = MIN(3, 1 + p->anim_timer / 10); break;
        case MS_ANIM_IDLE:
        default:              sheet = _shRun;  frame = 0; break;
    }

    // 무적 시간에는 깜빡인다
    CGFloat alpha = 1.0;
    if (p->invuln_frames > 0 && (st->tick_count / 3) % 2 == 0) alpha = 0.45;

    CGFloat h = p->h * 1.12 * k;
    [self drawSheet:sheet frame:frame ctx:ctx footX:fx footY:fy height:h flip:flip tint:nil alpha:alpha];

    if (!sheet.valid) {   // 스프라이트가 없을 때의 대체 표시
        [[UIColor colorWithRed:0.22 green:0.68 blue:0.34 alpha:1.0] setFill];
        CGContextFillRect(ctx, CGRectMake(fx - p->w * 0.5 * k, fy - h, p->w * k, h));
    }
}

- (void)drawEnemies:(CGContextRef)ctx state:(ms_game_state_t *)st scale:(CGFloat)k {
    for (int i = 0; i < MS_MAX_ENEMIES; ++i) {
        ms_enemy_t *en = &st->enemies[i];
        if (!en->active) continue;

        CGFloat fx = (en->x + 24.0f - st->camera_x) * k;
        CGFloat fy = en->y * k;
        if (fx < -260 || fx > CGRectGetWidth(self.bounds) + 260) continue;

        BOOL flip = (en->facing > 0);     // 스프라이트는 좌향 기준으로 그려져 있다
        UIColor *tint = (en->hit_flash > 0)
            ? [UIColor colorWithWhite:1.0 alpha:0.75] : nil;

        MSSpriteSheet *sheet = _shEnemyRun;
        NSInteger frame = 0;
        CGFloat h = 62.0 * k;

        if (en->death_timer > 0) {
            sheet = _shEnemyDeath;
            frame = MIN(3, en->anim_timer / 6);
            if (en->kind == MS_ENEMY_TANK || en->kind == MS_ENEMY_HELI) continue;  // 폭발로 대체
        } else {
            switch (en->kind) {
                case MS_ENEMY_TANK:
                    sheet = _shTank; frame = 0; h = 86.0 * k; break;
                case MS_ENEMY_HELI:
                    sheet = _shHeli; frame = (st->tick_count / 3) % 2; h = 74.0 * k; break;
                case MS_ENEMY_BUNKER_GUARD:
                    sheet = _shGrenadier; frame = (en->anim_timer / 10) % 3; break;
                case MS_ENEMY_TOWER_GUARD:
                    sheet = _shEnemyAttack; frame = (en->ai_timer < 14) ? 1 : 0; break;
                case MS_ENEMY_PARATROOPER:
                    sheet = _shPara; frame = (en->vy > 0.0f) ? 0 : 1;
                    h = (en->vy > 0.0f) ? 100.0 * k : 62.0 * k; break;
                case MS_ENEMY_INFANTRY:
                default:
                    sheet = _shEnemyRun; frame = (en->anim_timer / 6) % 4; break;
            }
        }

        // 벙커·망루는 구조물을 먼저 깔고 그 위에 병사를 놓는다
        if (en->kind == MS_ENEMY_BUNKER_GUARD && _shBunker.valid && en->death_timer == 0) {
            [self drawSheet:_shBunker frame:0 ctx:ctx footX:fx footY:MS_GROUND_Y * k
                     height:(MS_GROUND_Y - en->y + 62.0f) * k flip:NO tint:nil alpha:1.0];
        } else if (en->kind == MS_ENEMY_TOWER_GUARD && en->death_timer == 0) {
            CGFloat postW = 16.0 * k;
            [[UIColor colorWithRed:0.42 green:0.30 blue:0.18 alpha:1.0] setFill];
            CGContextFillRect(ctx, CGRectMake(fx - postW * 0.5, fy, postW, (MS_GROUND_Y - en->y) * k));
            [[UIColor colorWithRed:0.52 green:0.38 blue:0.23 alpha:1.0] setFill];
            CGContextFillRect(ctx, CGRectMake(fx - postW * 2.2, fy - 4 * k, postW * 4.4, 8 * k));
        }

        [self drawSheet:sheet frame:frame ctx:ctx footX:fx footY:fy
                 height:h flip:flip tint:tint alpha:1.0];

        if (!sheet.valid) {
            [[UIColor colorWithRed:0.84 green:0.22 blue:0.20 alpha:1.0] setFill];
            CGContextFillRect(ctx, CGRectMake(fx - 24 * k, fy - h, 48 * k, h));
        }
    }
}

#pragma mark - 탄환·이펙트

- (void)drawBullets:(CGContextRef)ctx state:(ms_game_state_t *)st scale:(CGFloat)k {
    for (int i = 0; i < MS_MAX_BULLETS; ++i) {
        ms_bullet_t *b = &st->bullets[i];
        if (!b->active) continue;
        CGFloat bx = (b->x - st->camera_x) * k;
        CGFloat by = b->y * k;

        NSInteger frame = b->is_grenade ? 2 : (b->from_player ? 0 : 1);
        CGFloat h = (b->is_grenade ? 22.0 : 16.0) * k;

        if (_shBullets.valid) {
            CGFloat aspect = _shBullets.frameWidth / MAX(1.0, _shBullets.frameHeight);
            CGFloat w = h * aspect;
            CGRect dest = CGRectMake(bx - w * 0.5, by - h * 0.5, w, h);
            CGContextSaveGState(ctx);
            // 날아가는 방향으로 돌려 그린다
            CGFloat ang = atan2f(b->vy, b->vx);
            CGContextTranslateCTM(ctx, bx, by);
            CGContextRotateCTM(ctx, ang);
            CGContextTranslateCTM(ctx, -bx, -by);
            MSDrawSpriteFrame(ctx, _shBullets, frame, dest, NO, nil, 1.0);
            CGContextRestoreGState(ctx);
        } else {
            [[UIColor colorWithRed:1.0 green:0.82 blue:0.12 alpha:1.0] setFill];
            CGContextFillEllipseInRect(ctx, CGRectMake(bx - 5 * k, by - 5 * k, 10 * k, 10 * k));
        }
    }
}

- (void)drawEffects:(CGContextRef)ctx state:(ms_game_state_t *)st scale:(CGFloat)k {
    for (int i = 0; i < MS_MAX_EFFECTS; ++i) {
        ms_effect_t *fx = &st->effects[i];
        if (!fx->active) continue;
        MSSpriteSheet *sheet = nil;
        CGFloat base = 60.0;
        switch (fx->kind) {
            case MS_FX_EXPLOSION: sheet = _shExplosion; base = 96.0; break;
            case MS_FX_IMPACT:    sheet = _shImpact;    base = 44.0; break;
            case MS_FX_SMOKE:     sheet = _shSmoke;     base = 40.0; break;
            case MS_FX_MUZZLE:    sheet = _shMuzzle;    base = 42.0; break;
            default: break;
        }
        if (!sheet.valid) continue;
        CGFloat h = base * fx->scale * k;
        CGFloat cx = (fx->x - st->camera_x) * k;
        CGFloat cy = fx->y * k;
        CGFloat aspect = sheet.frameWidth / MAX(1.0, sheet.frameHeight);
        CGRect dest = CGRectMake(cx - h * aspect * 0.5, cy - h * 0.5, h * aspect, h);
        MSDrawSpriteFrame(ctx, sheet, fx->frame, dest, NO, nil, 1.0);
    }

    // 불똥
    for (int i = 0; i < MS_MAX_PARTICLES; ++i) {
        ms_particle_t *pt = &st->particles[i];
        if (!pt->active) continue;
        CGFloat a = MIN(1.0, pt->life / 12.0);
        [[UIColor colorWithRed:1.0 green:0.75 blue:0.2 alpha:a] setFill];
        CGContextFillRect(ctx, CGRectMake((pt->x - st->camera_x) * k, pt->y * k, 5 * k, 5 * k));
    }
}

#pragma mark - HUD

/// 숫자를 도트 폰트로 찍는다. 오른쪽 끝 기준.
- (CGFloat)drawNumber:(int)value ctx:(CGContextRef)ctx rightX:(CGFloat)rightX
                topY:(CGFloat)topY height:(CGFloat)h {
    if (!_shDigits.valid) return rightX;
    CGFloat dw = h * (_shDigits.frameWidth / MAX(1.0, _shDigits.frameHeight));
    char buf[16];
    snprintf(buf, sizeof(buf), "%d", MAX(0, value));
    NSInteger n = (NSInteger)strlen(buf);
    CGFloat x = rightX - dw * n;
    for (NSInteger i = 0; i < n; i++) {
        NSInteger d = buf[i] - '0';
        MSDrawSpriteFrame(ctx, _shDigits, d, CGRectMake(x + dw * i, topY, dw, h), NO, nil, 1.0);
    }
    return x;
}

- (void)drawHUD:(CGContextRef)ctx state:(ms_game_state_t *)st rect:(CGRect)rect {
    CGFloat uiScale = MAX(1.0, rect.size.height / 1080.0) * ((CGFloat)st->switches.ui_scale_percent / 150.0);
    CGFloat h = 46.0 * uiScale;
    CGFloat pad = 34.0 * uiScale;
    CGFloat y = pad;

    // 반투명 띠 — 밝은 하늘 위에서도 숫자가 읽히도록
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.0 alpha:0.42].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, rect.size.width, h + pad * 1.7));

    CGFloat x = pad;
    CGFloat iconH = h;
    CGFloat iconW = _shIcons.valid ? iconH * (_shIcons.frameWidth / MAX(1.0, _shIcons.frameHeight)) : iconH;

    // 체력
    if (_shIcons.valid) MSDrawSpriteFrame(ctx, _shIcons, 0, CGRectMake(x, y, iconW, iconH), NO, nil, 1.0);
    x += iconW + 6 * uiScale;
    x = [self drawNumber:st->player.hp ctx:ctx rightX:x + h * 1.4 topY:y height:h] + h * 1.4 + pad * 0.7;

    // 수류탄
    if (_shIcons.valid) MSDrawSpriteFrame(ctx, _shIcons, 1, CGRectMake(x, y, iconW, iconH), NO, nil, 1.0);
    x += iconW + 6 * uiScale;
    x = [self drawNumber:st->player.grenade_count ctx:ctx rightX:x + h * 1.4 topY:y height:h] + h * 1.4 + pad * 0.7;

    // 장갑차 내구도 (탑승 중일 때만)
    if (st->player.in_slug) {
        if (_shIcons.valid) MSDrawSpriteFrame(ctx, _shIcons, 2, CGRectMake(x, y, iconW, iconH), NO, nil, 1.0);
        x += iconW + 6 * uiScale;
        x = [self drawNumber:st->player.slug_hp ctx:ctx rightX:x + h * 1.4 topY:y height:h] + h * 1.4 + pad * 0.7;
    }

    // 점수는 오른쪽 끝
    [self drawNumber:st->score ctx:ctx rightX:rect.size.width - pad topY:y height:h];

    if (st->paused || st->game_over) {
        NSString *msg = st->game_over ? @"GAME OVER" : @"PAUSED";
        UIFont *f = [UIFont monospacedSystemFontOfSize:72.0 * uiScale weight:UIFontWeightHeavy];
        NSDictionary *attrs = @{ NSFontAttributeName: f,
                                 NSForegroundColorAttributeName: [UIColor whiteColor],
                                 NSStrokeColorAttributeName: [UIColor blackColor],
                                 NSStrokeWidthAttributeName: @(-5.0) };
        CGSize sz = [msg sizeWithAttributes:attrs];
        [msg drawAtPoint:CGPointMake((rect.size.width - sz.width) * 0.5,
                                     (rect.size.height - sz.height) * 0.42)
          withAttributes:attrs];
    }
}

#pragma mark - 그리기

- (void)drawRect:(CGRect)rect {
    ms_game_state_t *st = self.gameState;
    if (!st || !st->initialized) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        [MSLog throttled:MSLogCatRender key:@"no-ctx" fmt:@"그리기 컨텍스트를 얻지 못했다"];
        return;
    }
    [self loadSheetsIfNeeded];

    CGFloat k = [self worldScaleForRect:rect];

    [self drawBackground:ctx rect:rect scale:k camera:st->camera_x];
    [self drawEnemies:ctx state:st scale:k];
    [self drawPlayer:ctx state:st scale:k];
    [self drawBullets:ctx state:st scale:k];
    [self drawEffects:ctx state:st scale:k];
    [self drawHUD:ctx state:st rect:rect];
}

@end
