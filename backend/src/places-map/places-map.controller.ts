// src/places-map/places-map.controller.ts
import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  UseGuards,
  NotFoundException,
  HttpCode,
} from '@nestjs/common';
import { PlacesMapService } from './places-map.service';
import { FirebaseAuthGuard } from '../../auth/firebase-auth.guard';

@UseGuards(FirebaseAuthGuard)
@Controller('places-map')
export class PlacesMapController {
  constructor(private readonly placesMapService: PlacesMapService) {}

  @Get(':id/location')
  async getLocation(@Param('id') id: string) {
    const place = await this.placesMapService.getPlaceLocation(id);
    if (!place) throw new NotFoundException('Place not found');
    return place;
  }

  @Post('locations')
  @HttpCode(200)
  async getMultipleLocations(@Body('placeIds') placeIds: string[]) {
    if (!Array.isArray(placeIds) || placeIds.length === 0) return [];
    return this.placesMapService.getMultipleLocations(placeIds);
  }

  // ── NEW: accepts recommendation_items IDs ──────────
  @Post('landmark-locations')
  @HttpCode(200)
  async getLandmarkLocations(@Body('landmarkIds') landmarkIds: number[]) {
    if (!Array.isArray(landmarkIds) || landmarkIds.length === 0) return [];
    return this.placesMapService.getMultipleByLandmarkIds(landmarkIds);
  }
}
