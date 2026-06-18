import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { ProfilesService } from './profiles.service';
import { ProfilesController } from './profiles.controller';
import { AvatarService } from './avatar.service';

@Module({
  imports: [DatabaseModule],
  controllers: [ProfilesController],
  providers: [ProfilesService, AvatarService],
})
export class ProfilesModule {}
