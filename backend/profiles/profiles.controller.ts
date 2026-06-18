import {
  Controller,
  Get,
  Put,
  Post,
  Delete,
  Body,
  Req,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ProfilesService } from './profiles.service';
import { AvatarService } from './avatar.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
@Controller('profiles')
export class ProfilesController {
  constructor(
    private readonly profiles: ProfilesService,
    private readonly avatar: AvatarService,
  ) {}
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
  @UseGuards(FirebaseAuthGuard)
  @Put('complete')
  async completeProfile(@Req() req, @Body() body) {
    await this.profiles.completeProfile(req.user.uid, body);
    return { success: true };
  }
  @UseGuards(FirebaseAuthGuard)
  @Put('update')
  async updateProfile(@Req() req, @Body() body) {
    return this.profiles.updateProfile(req.user.uid, body);
  }
  @UseGuards(FirebaseAuthGuard)
  @Put('preferences')
  async updatePreferences(@Req() req, @Body() body: { preferences: string[] }) {
    await this.profiles.updatePreferences(req.user.uid, body.preferences);
    return { success: true };
  }
  @UseGuards(FirebaseAuthGuard)
  @Post('avatar')
  @UseInterceptors(FileInterceptor('file', {
    limits: { fileSize: 5 * 1024 * 1024 },
  }))
  async uploadAvatar(@Req() req, @UploadedFile() file: Express.Multer.File) {
    if (!file) throw new BadRequestException('No file provided');
    const allowed = ['image/jpeg', 'image/png', 'image/webp'];
    if (!allowed.includes(file.mimetype)) {
      throw new BadRequestException('Only JPEG, PNG, and WebP images are allowed');
    }
    const url = await this.avatar.uploadAvatar(
      req.user.uid,
      file.buffer,
      file.mimetype,
    );
    return { avatar_url: url };
  }
  @UseGuards(FirebaseAuthGuard)
  @Delete('avatar')
  async removeAvatar(@Req() req) {
    await this.avatar.removeAvatar(req.user.uid);
    return { success: true };
  }
}
