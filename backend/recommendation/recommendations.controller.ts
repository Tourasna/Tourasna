// src/recommendations/recommendations.controller.ts
import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { RecommendationsService } from './recommendations.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';

@Controller('recommendations')
@UseGuards(FirebaseAuthGuard)
export class RecommendationsController {
  constructor(private readonly recommendations: RecommendationsService) {}

  @Get()
  async get(@Req() req) {
    const userId = req.user.uid;
    return this.recommendations.getRecommendations(userId);
  }
}
