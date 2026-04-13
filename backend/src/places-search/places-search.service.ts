// src/places-search/places-search.service.ts

import { Injectable } from '@nestjs/common';
import { MySQLService } from '../../database/mysql.service';

@Injectable()
export class PlacesSearchService {
  constructor(private readonly mysql: MySQLService) {}

  async search(q: string, city: string) {
    const pool = this.mysql.getPool();

    const [rows] = await pool.query(
      `
      SELECT
        id,
        city,
        name,
        subcategory,
        rating,
        ranking,
        address,
        latitude,
        longitude
      FROM places_agenda
      WHERE city = ?
        AND name LIKE ?
      ORDER BY rating DESC
      LIMIT 20
      `,
      [city, `%${q}%`],
    );

    // IMPORTANT:
    // Return empty array if nothing found
    // DO NOT throw 404 (frontend handles empty results)
    return rows;
  }
}
