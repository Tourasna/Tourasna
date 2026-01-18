import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { FirebaseAuthGuard } from 'auth/firebase-auth.guard';


@Controller()
export class AppController {
  @UseGuards(FirebaseAuthGuard)
  @Get('me')
  getMe(@Req() req) {
    return {
      auth0_id: req.user.sub,
      email: req.user.email,
    };
  }
}
