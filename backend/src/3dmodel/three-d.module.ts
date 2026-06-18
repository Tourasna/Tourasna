import { Module } from '@nestjs/common';
import { ThreeDController } from './three-d.controller';
import { ThreeDService } from './three-d.service';

@Module({
  controllers: [ThreeDController],
  providers: [ThreeDService],
})
export class ThreeDModule {}