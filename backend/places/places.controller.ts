// src/places/places.controller.ts
import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { PlacesService } from './places.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';

@Controller('places')
export class PlacesController {
  constructor(private readonly places: PlacesService) {}

  @UseGuards(FirebaseAuthGuard)
  @Get('by-ml-label/:mlLabel')
  async getByMlLabel(@Param('mlLabel') mlLabel: string) {
    return this.places.findByMlLabel(mlLabel);
  }
}
