import { Module } from '@nestjs/common';
import { PlacesMapController } from './places-map.controller';
import { PlacesMapService } from './places-map.service';
import { MySQLService } from '../../database/mysql.service';

@Module({
  controllers: [PlacesMapController],
  providers: [PlacesMapService, MySQLService],
})
export class PlacesMapModule {}
