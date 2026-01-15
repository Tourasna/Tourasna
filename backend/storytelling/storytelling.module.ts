// src/storytelling/storytelling.module.ts
import { Module } from '@nestjs/common';
import { StorytellingController } from './storytelling.controller';
import { StorytellingService } from './storytelling.service';
import { DatabaseModule } from '../database/database.module';
import { AIService } from '../ai/ai.service';

@Module({
  imports: [DatabaseModule],
  controllers: [StorytellingController],
  providers: [StorytellingService, AIService],
})
export class StorytellingModule {}
