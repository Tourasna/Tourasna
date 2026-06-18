import { Controller, Post, Body, Req, UseGuards } from '@nestjs/common';
import { RecommendationsService } from './recommendations.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';

@Controller('recommendations')
@UseGuards(FirebaseAuthGuard)
export class RecommendationsController {
  constructor(private readonly service: RecommendationsService) {}

  @Post()
  async getRecommendations(
    @Req() req,
    @Body() body: { plan_type?: string; trip_days?: number },
  ) {
    return this.service.getRecommendations(
      req.user.uid,
      body.plan_type ?? 'DayPlan',
      body.trip_days ?? null,
    );
  }

  @Post('feedback')
  async feedback(
    @Req() req,
    @Body() body: { landmark_name: string; event_type: 'like' | 'dislike' },
  ) {
    return this.service.saveFeedback(
      req.user.uid,
      body.landmark_name,
      body.event_type,
    );
  }
}