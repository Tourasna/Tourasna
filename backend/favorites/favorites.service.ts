import { Injectable } from '@nestjs/common';
import { MySQLService } from '../database/mysql.service';
import { v4 as uuid } from 'uuid';

@Injectable()
export class FavoritesService {
  constructor(private readonly db: MySQLService) {}

  async add(userId: string, itemId: number) {
    await this.db.pool.query(
      `
      INSERT IGNORE INTO favorites (id, user_id, item_id)
      VALUES (?, ?, ?)
      `,
      [uuid(), userId, itemId],
    );

    return { success: true };
  }

  async remove(userId: string, itemId: number) {
    await this.db.pool.query(
      `
      DELETE FROM favorites
      WHERE user_id = ? AND item_id = ?
      `,
      [userId, itemId],
    );

    return { success: true };
  }

  async list(userId: string) {
    const [rows]: any = await this.db.pool.query(
      `
      SELECT ri.*
      FROM favorites f
      JOIN recommendation_items ri ON ri.id = f.item_id
      WHERE f.user_id = ?
      ORDER BY f.created_at DESC
      `,
      [userId],
    );

    return rows;
  }
}
