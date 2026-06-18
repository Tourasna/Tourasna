import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Query,
  Param,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AgendaService } from './agenda.service';
import { CreateAgendaDto } from './dto/create-agenda.dto';
import { UpdateAgendaDto } from './dto/update-agenda.dto';
import { FirebaseAuthGuard } from '../../auth/firebase-auth.guard';

@Controller('agenda')
@UseGuards(FirebaseAuthGuard)
export class AgendaController {
  constructor(private readonly agenda: AgendaService) {}

  @Get()
  async list(
    @Req() req,
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    return this.agenda.list(req.user.uid, from, to);
  }

  @Post()
  async create(@Req() req, @Body() dto: CreateAgendaDto) {
    return this.agenda.create(req.user.uid, dto);
  }

  @Put(':id')
  async update(
    @Req() req,
    @Param('id') id: string,
    @Body() dto: UpdateAgendaDto,
  ) {
    return this.agenda.update(req.user.uid, Number(id), dto);
  }

  @Delete(':id')
  async remove(@Req() req, @Param('id') id: string) {
    await this.agenda.delete(req.user.uid, Number(id));
    return { success: true };
  }
}
