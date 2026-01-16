import { Controller, Put, Get, Body, Req, UseGuards } from '@nestjs/common';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { ContextService } from './context.service';

@Controller('context')
@UseGuards(FirebaseAuthGuard)
export class ContextController {
  constructor(private readonly contextService: ContextService) {}

  // ─────────────────────────────────────────────
  // UPSERT USER CONTEXT (TRIP INTENT)
  // ─────────────────────────────────────────────
  @Put()
  async upsertContext(
    @Req() req: any,
    @Body()
    body: {
      budget: 'low' | 'medium' | 'high';
      travel_type: 'solo' | 'couple' | 'family' | 'luxury';
    },
  ) {
    const userId = req.user.uid;
    await this.contextService.upsert(userId, body);
    return { success: true };
  }

  // ─────────────────────────────────────────────
  // GET CURRENT USER CONTEXT
  // ─────────────────────────────────────────────
  @Get()
  async getContext(@Req() req: any) {
    const userId = req.user.uid;
    return this.contextService.get(userId);
  }
}
