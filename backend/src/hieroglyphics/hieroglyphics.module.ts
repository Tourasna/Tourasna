import { Module } from '@nestjs/common';
import { HieroglyphicsController } from './hieroglyphics.controller';
import { HieroglyphicsService } from './hieroglyphics.service';

@Module({
  controllers: [HieroglyphicsController],
  providers: [HieroglyphicsService],
})
export class HieroglyphicsModule {}
