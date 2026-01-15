// src/places/places.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { MySQLService } from '../database/mysql.service';

@Injectable()
export class PlacesService {
  constructor(private readonly db: MySQLService) {}

  async findByMlLabel(mlLabel: string) {
    const [rows] = await this.db.pool.query(
      'SELECT * FROM places WHERE ml_label = ?',
      [mlLabel],
    );

    const place = (rows as any[])[0];
    if (!place) {
      throw new NotFoundException('Place not found');
    }

    return place;
  }
}
