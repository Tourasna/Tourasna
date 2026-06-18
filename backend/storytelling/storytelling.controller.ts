import { Controller, Get, Param, UseGuards, NotFoundException } from '@nestjs/common';
import { StorytellingService } from './storytelling.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';

// Whitelisted place UUIDs for the public website demo
const DEMO_PLACE_IDS = new Set([
  '8e745670-8146-4440-b390-146bcd2e46c3', // Great Sphinx of Giza
  '4237588a-75d3-4d2e-9842-01bfa14ea440', // Great Pyramids of Giza
  'c635c843-3a9f-418c-b8f5-a42c50319cc8', // Citadel of Saladin
  '6caaa654-2f18-45b2-b6c9-ee6fa5be920a', // Khufu's Solar Boat
]);

@Controller('storytelling')
export class StorytellingController {
  constructor(private readonly service: StorytellingService) {}

  // ── PUBLIC — no auth guard ─────────────────────────────────────────────────

  @Get('demo/:placeId')
  async getDemoStory(@Param('placeId') placeId: string) {
    if (!DEMO_PLACE_IDS.has(placeId)) {
      throw new NotFoundException('Not a demo place');
    }
    return this.service.getStory(placeId);
  }

  // ── PROTECTED — Firebase auth required ────────────────────────────────────

  @Get('places')
  @UseGuards(FirebaseAuthGuard)
  async getAllPlaces() {
    return this.service.getAllPlacesWithPhotos();
  }

  @Get(':placeId')
  @UseGuards(FirebaseAuthGuard)
  async getStory(@Param('placeId') placeId: string) {
    return this.service.getStory(placeId);
  }
}