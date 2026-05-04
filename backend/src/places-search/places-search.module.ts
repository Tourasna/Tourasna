// src/places-search/places-search.module.ts

import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { PlacesSearchService } from './places-search.service';
import { PlacesSearchController } from './places-search.controller';

@Module({
  imports: [
    DatabaseModule, // 👈 exports MySQLService safely
  ],
  controllers: [PlacesSearchController],
  providers: [PlacesSearchService],
})
export class PlacesSearchModule {}
