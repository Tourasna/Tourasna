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
import { AuthGuard } from '@nestjs/passport';
import { AgendaService } from './agenda.service';
import { CreateAgendaDto } from './dto/create-agenda.dto';
import { UpdateAgendaDto } from './dto/update-agenda.dto';

@Controller('api/agenda')
@UseGuards(AuthGuard)
export class AgendaController {
  constructor(private readonly agenda: AgendaService) {}

  @Get()
  list(@Req() req, @Query('from') from: string, @Query('to') to: string) {
    return this.agenda.list(req.user.uid, from, to);
  }

  @Post()
  create(@Req() req, @Body() dto: CreateAgendaDto) {
    return this.agenda.create(req.user.uid, dto);
  }

  @Put(':id')
  update(@Req() req, @Param('id') id: string, @Body() dto: UpdateAgendaDto) {
    return this.agenda.update(req.user.uid, Number(id), dto);
  }

  @Delete(':id')
  remove(@Req() req, @Param('id') id: string) {
    return this.agenda.delete(req.user.uid, Number(id));
  }
}
