import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { StorytellingService } from './storytelling.service';
import { FirebaseAuthGuard } from 'auth/firebase-auth.guard';

@Controller('storytelling')
export class StorytellingController {
  constructor(private readonly service: StorytellingService) {}

  @UseGuards(FirebaseAuthGuard)
  @Get(':placeId')
  async getStory(@Param('placeId') placeId: string) {
    return this.service.getStory(placeId);
  }
}
