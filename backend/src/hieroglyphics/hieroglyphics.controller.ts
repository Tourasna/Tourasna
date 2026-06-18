import {
  Controller,
  Post,
  Get,
  Body,
  UploadedFile,
  UseInterceptors,
  UseGuards,
  Request,
  Query,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { HieroglyphicsService } from './hieroglyphics.service';
import { FirebaseAuthGuard } from '../../auth/firebase-auth.guard';

// Whitelisted S3 sample keys → actual S3 URLs
const DEMO_SAMPLES: Record<string, string> = {
  ramesses:    'https://tourasna-assets.s3.eu-north-1.amazonaws.com/samples/ramesses.jpg',
  tutankhamun: 'https://tourasna-assets.s3.eu-north-1.amazonaws.com/samples/tutankhamun.jpg',
};

@Controller('hieroglyphics')
export class HieroglyphicsController {
  constructor(private readonly hieroglyphicsService: HieroglyphicsService) {}

  // ── PUBLIC — no auth guard ─────────────────────────────────────────────────
  @Get('health')
  health() {
    return this.hieroglyphicsService.health();
  }

  @Post('demo')
  async demo(@Body() body: { sample: string }) {
    const url = DEMO_SAMPLES[body?.sample];
    if (!url) {
      throw new HttpException(
        `Invalid sample key. Valid keys: ${Object.keys(DEMO_SAMPLES).join(', ')}`,
        HttpStatus.BAD_REQUEST,
      );
    }
    return this.hieroglyphicsService.translateFromUrl(url);
  }

  // ── PROTECTED — Firebase auth required ────────────────────────────────────
  @Post('translate')
  @UseGuards(FirebaseAuthGuard)
  @UseInterceptors(FileInterceptor('image', { limits: { fileSize: 20 * 1024 * 1024 } }))
  async translate(
    @UploadedFile() file: Express.Multer.File,
    @Query('reading_direction') readingDirection: string = 'auto',
    @Request() req,
  ) {
    if (!file) {
      throw new HttpException('No image file provided', HttpStatus.BAD_REQUEST);
    }
    return this.hieroglyphicsService.translate(
      file.buffer,
      file.mimetype,
      readingDirection,
    );
  }

  @Post('translate-codes')
  @UseGuards(FirebaseAuthGuard)
  async translateCodes(
    @Body() body: { codes: string[] },
    @Request() req,
  ) {
    if (!body.codes || !Array.isArray(body.codes) || body.codes.length === 0) {
      throw new HttpException('codes array is required', HttpStatus.BAD_REQUEST);
    }
    return this.hieroglyphicsService.translateCodes(body.codes);
  }
}