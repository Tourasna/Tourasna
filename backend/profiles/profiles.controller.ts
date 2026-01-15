import {
  Controller,
  Get,
  Put,
  Body,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ProfilesService } from './profiles.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';

@Controller('profiles')
export class ProfilesController {
  constructor(private readonly profiles: ProfilesService) {}

  // ─────────────────────────────────────────────
  // GET CURRENT PROFILE (AUTO-CREATE)
  // ─────────────────────────────────────────────
  @UseGuards(FirebaseAuthGuard)
  @Get('me')
  async getMe(@Req() req) {
    const uid = req.user.uid;

    let profile = await this.profiles.findById(uid);
    if (!profile) {
      profile = await this.profiles.createFromFirebase(req.user);
    }

    return profile;
  }

  // ─────────────────────────────────────────────
  // COMPLETE PROFILE (ONCE – AFTER PREFERENCES)
  // ─────────────────────────────────────────────
  @UseGuards(FirebaseAuthGuard)
  @Put('complete')
  async completeProfile(
    @Req() req,
    @Body()
    body: {
      firstName: string;
      lastName: string;
      username: string;
      gender: string;
      nationality: string;
      dateOfBirth: string;
      preferences: string[];
    },
  ) {
    await this.profiles.completeProfile(req.user.uid, body);
    return { success: true };
  }

@UseGuards(FirebaseAuthGuard)
@Put('update')
async updateProfile(@Req() req, @Body() body) {
  return this.profiles.updateProfile(req.user.uid, body);
}


  // ─────────────────────────────────────────────
  // UPDATE PREFERENCES ONLY (LATER)
  // ─────────────────────────────────────────────
  @UseGuards(FirebaseAuthGuard)
  @Put('preferences')
  async updatePreferences(
    @Req() req,
    @Body() body: { preferences: string[] },
  ) {
    await this.profiles.updatePreferences(
      req.user.uid,
      body.preferences,
    );
    return { success: true };
  }
}
