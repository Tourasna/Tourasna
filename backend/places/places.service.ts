import { Injectable, NotFoundException } from '@nestjs/common';
import { MySQLService } from '../database/mysql.service';
import { PlaceResponseDto } from './dto/place-response.dto';
import { RowDataPacket } from 'mysql2';

@Injectable()
export class PlacesService {
  constructor(private readonly db: MySQLService) {}

  async findByMlLabel(mlLabel: string): Promise<PlaceResponseDto> {
    const [rows] = await this.db.pool.query<RowDataPacket[]>(
      `
      SELECT id, name, description, category,
            glb_url, ml_label
      FROM places
      WHERE ml_label = ?
      LIMIT 1
      `,
      [mlLabel]
    );

    if (rows.length === 0) {
      throw new NotFoundException('Place not found');
    }

    return rows[0] as PlaceResponseDto;
  }

  async findById(id: string): Promise<PlaceResponseDto> {
    const [rows] = await this.db.pool.query<RowDataPacket[]>(
      `
      SELECT id, name, description, category,
            glb_url, ml_label
      FROM places
      WHERE id = ?
      LIMIT 1
      `,
      [id]
    );

    if (rows.length === 0) {
      throw new NotFoundException('Place not found');
    }

    return rows[0] as PlaceResponseDto;
  }
}
