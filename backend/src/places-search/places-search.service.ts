import { Injectable } from '@nestjs/common';
import { MySQLService } from '../../database/mysql.service';
import { RowDataPacket } from 'mysql2';

interface PlaceRow extends RowDataPacket {
  id: string;
  city: string;
  name: string;
  subcategory: string;
  rating: number | null;
  ranking: string | null;
  address: string | null;
  latitude: number;
  longitude: number;
}

@Injectable()
export class PlacesSearchService {
  constructor(private readonly mysql: MySQLService) {}

  async search(q: string, city: string): Promise<PlaceRow[]> {
    const pool = this.mysql.getPool();

    const [rows] = await pool.query<PlaceRow[]>(
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

    // Always return array (never throw 404)
    return rows;
  }
}
