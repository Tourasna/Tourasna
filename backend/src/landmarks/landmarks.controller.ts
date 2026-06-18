import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { FirebaseAuthGuard } from '../../auth/firebase-auth.guard';
import { LandmarksService } from './landmarks.service';

@UseGuards(FirebaseAuthGuard)
@Controller('landmarks')
export class LandmarksController {
  constructor(private readonly landmarksService: LandmarksService) {}

  @Get('search')
  async search(
    @Query('q') q: string = '',
    @Query('category') category: string = '',
    @Query('page') page: string = '1',
    @Query('limit') limit: string = '20',
    @Query('sort') sort: string = 'POPULAR',
  ): Promise<any> {
    const pageNum = Math.max(1, parseInt(page) || 1);
    const limitNum = Math.min(50, parseInt(limit) || 20);
    return this.landmarksService.search(q, category, pageNum, limitNum, sort);
  }

  @Get('categories')
  async getCategories(): Promise<any> {
    const categories = await this.landmarksService.getCategories();
    return { categories };
  }
}
