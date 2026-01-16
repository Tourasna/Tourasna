import {
  Controller,
  Post,
  Delete,
  Get,
  Param,
  Req,
  UseGuards,
} from '@nestjs/common';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { FavoritesService } from './favorites.service';

@Controller('favorites')
@UseGuards(FirebaseAuthGuard)
export class FavoritesController {
  constructor(private readonly service: FavoritesService) {}

  @Post(':itemId')
  add(@Req() req: any, @Param('itemId') itemId: string) {
    return this.service.add(req.user.uid, Number(itemId));
  }

  @Delete(':itemId')
  remove(@Req() req: any, @Param('itemId') itemId: string) {
    return this.service.remove(req.user.uid, Number(itemId));
  }

  @Get()
  list(@Req() req: any) {
    return this.service.list(req.user.uid);
  }
}
