import { Controller, Get, Req } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  check(@Req() req) {
    return {
      status: 'ok',
      user: req.auth?.sub ?? null,
    };
  }
}
