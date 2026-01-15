// src/storytelling/storytelling.controller.ts
import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { StorytellingService } from './storytelling.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';

@Controller('storytelling')
export class StorytellingController {
  constructor(private readonly storytelling: StorytellingService) {}

  @UseGuards(FirebaseAuthGuard)
  @Get(':placeId')
  async getStory(@Param('placeId') placeId: string) {
    return {
      story: await this.storytelling.getStory(placeId),
    };
  }
}
