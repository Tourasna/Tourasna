import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { LandmarksController } from './landmarks.controller';
import { LandmarksService } from './landmarks.service';

@Module({
  imports: [DatabaseModule],
  controllers: [LandmarksController],
  providers: [LandmarksService],
})
export class LandmarksModule {}
