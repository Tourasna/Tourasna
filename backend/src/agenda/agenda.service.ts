import {
  Injectable,
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { MySQLService } from '../../database/mysql.service';
import { CreateAgendaDto } from './dto/create-agenda.dto';
import { UpdateAgendaDto } from './dto/update-agenda.dto';

@Injectable()
export class AgendaService {
  constructor(private readonly mysql: MySQLService) {}

  private get pool() {
    return this.mysql.getPool();
  }

  async list(userId: string, from: string, to: string) {
    const [rows] = await this.pool.query(
      `
      SELECT
        a.*,
        r.latitude,
        r.longitude,
        r.name AS landmark_name
      FROM agenda_items a
      LEFT JOIN recommendation_items r ON a.landmark_id = r.id
      WHERE a.user_id = ?
        AND a.start_datetime < ?
        AND a.end_datetime > ?
      ORDER BY a.start_datetime ASC
      `,
      [userId, `${to} 00:00:00`, `${from} 00:00:00`],
    );

    return rows;
  }

  async create(userId: string, dto: CreateAgendaDto) {
    if (dto.startDateTime >= dto.endDateTime) {
      throw new BadRequestException('startDateTime must be before endDateTime');
    }

    await this.ensureNoOverlap(userId, new Date(dto.startDateTime).toISOString().slice(0, 19).replace("T", " "), new Date(dto.endDateTime).toISOString().slice(0, 19).replace("T", " "));

    const [result] = await this.pool.query(
      `
      INSERT INTO agenda_items
      (user_id, title, start_datetime, end_datetime, place_id, landmark_id, notes)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      `,
      [
        userId,
        dto.title,
        new Date(dto.startDateTime).toISOString().slice(0, 19).replace("T", " "),
        new Date(dto.endDateTime).toISOString().slice(0, 19).replace("T", " "),
        dto.placeId ?? null,
        dto.landmarkId ?? null,
        dto.notes ?? null,
      ],
    );

    return { id: (result as any).insertId };
  }

  async update(userId: string, id: number, dto: UpdateAgendaDto) {
    const [rows] = await this.pool.query(
      `SELECT * FROM agenda_items WHERE id = ? AND user_id = ?`,
      [id, userId],
    );

    if ((rows as any[]).length === 0) {
      throw new NotFoundException('Agenda item not found');
    }

    const current = (rows as any)[0];

    const start = dto.startDateTime ?? current.start_datetime;
    const end   = dto.endDateTime   ?? current.end_datetime;

    if (start >= end) {
      throw new BadRequestException('Invalid time range');
    }

    await this.ensureNoOverlap(userId, new Date(start).toISOString().slice(0, 19).replace("T", " "), new Date(end).toISOString().slice(0, 19).replace("T", " "), id);

    await this.pool.query(
      `
      UPDATE agenda_items
      SET
        title      = COALESCE(?, title),
        start_datetime = ?,
        end_datetime   = ?,
        place_id       = ?,
        landmark_id    = ?,
        notes          = ?
      WHERE id = ? AND user_id = ?
      `,
      [
        dto.title    ?? null,
        new Date(start).toISOString().slice(0, 19).replace("T", " "),
        new Date(end).toISOString().slice(0, 19).replace("T", " "),
        dto.placeId    ?? current.place_id,
        dto.landmarkId ?? current.landmark_id,
        dto.notes      ?? current.notes,
        id,
        userId,
      ],
    );
  }

  async delete(userId: string, id: number) {
    const [res] = await this.pool.query(
      `DELETE FROM agenda_items WHERE id = ? AND user_id = ?`,
      [id, userId],
    );

    if ((res as any).affectedRows === 0) {
      throw new NotFoundException('Agenda item not found');
    }
  }

  private async ensureNoOverlap(
    userId: string,
    start: string,
    end: string,
    ignoreId?: number,
  ) {
    const [rows] = await this.pool.query(
      `
      SELECT 1
      FROM agenda_items
      WHERE user_id = ?
        AND start_datetime < ?
        AND end_datetime > ?
        ${ignoreId ? 'AND id != ?' : ''}
      LIMIT 1
      `,
      ignoreId ? [userId, end, start, ignoreId] : [userId, end, start],
    );

    if ((rows as any[]).length > 0) {
      throw new ConflictException('Agenda item overlaps with existing event');
    }
  }
}
