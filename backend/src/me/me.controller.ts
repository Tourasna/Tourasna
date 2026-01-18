import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Controller('me')
export class MeController {
  @UseGuards(AuthGuard('jwt'))
  @Get()
  getMe(@Req() req: any) {
    return {
      auth0_id: req.user.sub,
      email: req.user.email,
    };
  }
}
