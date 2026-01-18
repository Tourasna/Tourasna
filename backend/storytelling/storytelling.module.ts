import { Module } from '@nestjs/common';
import { StorytellingController } from './storytelling.controller';
import { StorytellingService } from './storytelling.service';
import { DatabaseModule } from '../database/database.module';
import { AuthModule } from '../auth/auth.module';
import { HttpModule } from '@nestjs/axios';

@Module({
  imports: [DatabaseModule, AuthModule, HttpModule],
  controllers: [StorytellingController],
  providers: [StorytellingService],
})
export class StorytellingModule {}
