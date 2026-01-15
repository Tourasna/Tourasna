// src/places/places.module.ts
import { Module } from '@nestjs/common';
import { PlacesController } from './places.controller';
import { PlacesService } from './places.service';
import { DatabaseModule } from '../database/database.module';

@Module({
  imports: [DatabaseModule],
  controllers: [PlacesController],
  providers: [PlacesService],
})
export class PlacesModule {}
