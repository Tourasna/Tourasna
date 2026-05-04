// src/places-search/places-search.controller.ts

import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { PlacesSearchService } from './places-search.service';
import { FirebaseAuthGuard } from '../../auth/firebase-auth.guard';

@UseGuards(FirebaseAuthGuard)
@Controller('places')
export class PlacesSearchController {
  constructor(private readonly placesSearchService: PlacesSearchService) {}

  @Get('search')
  async search(
    @Query('q') q: string,
    @Query('city') city: string,
  ) {
    if (!q || !city) {
      return [];
    }

    return this.placesSearchService.search(q, city);
  }
}
