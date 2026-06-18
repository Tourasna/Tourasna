import {
  Controller, Post, Get, Body, Query, UseGuards, HttpException, HttpStatus,
} from '@nestjs/common';
import { ThreeDService } from './three-d.service';
import { FirebaseAuthGuard } from '../../auth/firebase-auth.guard';

@Controller('3dmodel')
export class ThreeDController {
  constructor(private readonly svc: ThreeDService) {}

  @Post('generate')
  @UseGuards(FirebaseAuthGuard)
  async generate(
    @Body() body: { className?: string; classIndex?: number; imageB64?: string },
  ) {
    const className  = (body?.className  || '').trim();
    const classIndex = body?.classIndex;

    if (!className) {
      throw new HttpException('className is required', HttpStatus.BAD_REQUEST);
    }
    if (classIndex == null || classIndex < 0 || classIndex > 126) {
      throw new HttpException('classIndex must be 0–126', HttpStatus.BAD_REQUEST);
    }
    return this.svc.requestGeneration(className, classIndex, body?.imageB64 || '');
  }

  @Get('status')
  @UseGuards(FirebaseAuthGuard)
  async status(@Query('className') className: string) {
    const name = (className || '').trim();
    if (!name) throw new HttpException('className is required', HttpStatus.BAD_REQUEST);
    return this.svc.getStatus(name);
  }
}