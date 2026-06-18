import { Injectable } from '@nestjs/common';
import { MySQLService } from '../../database/mysql.service';
import { RowDataPacket } from 'mysql2';

interface LandmarkRow extends RowDataPacket {
  id: number;
  name: string;
  category: string;
  budget: string;
  rating: number | null;
  description: string | null;
  address: string | null;
  opening_hours: string | null;
  phone: string | null;
  website: string | null;
  photo_urls: string | null;
  latitude: number | null;
  longitude: number | null;
  google_maps_url: string | null;
  price_range: string | null;
  start_price: number | null;
  end_price: number | null;
  review_count: number | null;
  travel_types: string | null;
}

@Injectable()
export class LandmarksService {
  constructor(private readonly mysql: MySQLService) {}

  async search(
    q: string,
    category: string,
    page: number,
    limit: number,
    sort: string = 'POPULAR',
  ): Promise<{ data: LandmarkRow[]; total: number }> {
    const pool = this.mysql.getPool();
    const offset = (page - 1) * limit;

    const conditions: string[] = ['description IS NOT NULL'];
    const params: any[] = [];

    const hasFilter =
      (q && q.trim() !== '') ||
      (category && category.trim() !== '' && category !== 'ALL');

    if (q && q.trim() !== '') {
      conditions.push('LOWER(name) LIKE LOWER(?)');
      params.push(`%${q.trim()}%`);
    }

    if (category && category.trim() !== '' && category !== 'ALL') {
      conditions.push('category = ?');
      params.push(category.trim());
    }

    if (!hasFilter) {
      if (sort === 'POPULAR') {
        conditions.push('review_count >= 1000');
      } else if (sort === 'HIDDEN_GEMS') {
        conditions.push('review_count < 1000');
        conditions.push('rating >= 4.0');
      }
    }

    const where = conditions.join(' AND ');

    const orderBy =
      !hasFilter && sort === 'HIDDEN_GEMS' ? 'rating DESC' : 'review_count DESC';

    const [countRows] = await pool.query<RowDataPacket[]>(
      `SELECT COUNT(*) as total FROM recommendation_items WHERE ${where}`,
      params,
    );
    const total = (countRows[0] as any).total;

    const [rows] = await pool.query<LandmarkRow[]>(
      `SELECT
        id, name, category, budget, rating,
        description, address, opening_hours, phone, website,
        photo_urls, latitude, longitude, google_maps_url,
        price_range, start_price, end_price, review_count, travel_types
       FROM recommendation_items
       WHERE ${where}
       ORDER BY ${orderBy}
       LIMIT ? OFFSET ?`,
      [...params, limit, offset],
    );

    return { data: rows, total };
  }

  async getCategories(): Promise<string[]> {
    const pool = this.mysql.getPool();
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT DISTINCT category FROM recommendation_items
       WHERE description IS NOT NULL
       ORDER BY category ASC`,
    );
    return rows.map((r: any) => r.category);
  }
}
