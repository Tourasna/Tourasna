import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { RecommendationsService } from './recommendations.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';

@Controller('recommendations')
@UseGuards(FirebaseAuthGuard)
export class RecommendationsController {
  constructor(private readonly service: RecommendationsService) {}

  @Get()
  async getRecommendations(@Req() req) {
    return this.service.getRecommendations(req.user.uid);
  }
}
