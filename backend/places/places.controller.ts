import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { PlacesService } from './places.service';
import { PlaceResponseDto } from './dto/place-response.dto';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';

@Controller('places')
@UseGuards(FirebaseAuthGuard)
export class PlacesController {
  constructor(private readonly placesService: PlacesService) {}

  // AI Lens → resolve place
  @Get('by-ml-label/:mlLabel')
  getByMlLabel(
    @Param('mlLabel') mlLabel: string
  ): Promise<PlaceResponseDto> {
    return this.placesService.findByMlLabel(mlLabel);
  }

  // Details page → 3D viewer / storytelling
  @Get(':id')
  getById(
    @Param('id') id: string
  ): Promise<PlaceResponseDto> {
    return this.placesService.findById(id);
  }
}
