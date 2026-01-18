import { Injectable } from '@nestjs/common';
import { MySQLService } from '../database/mysql.service';

@Injectable()
export class ContextService {
  constructor(private readonly db: MySQLService) {}

  // ─────────────────────────────────────────────
  // UPSERT CONTEXT + INVALIDATE CACHE
  // ─────────────────────────────────────────────
  async upsert(
    userId: string,
    data: {
      budget: string;
      travel_type: string;
    },
  ) {
    // 1️⃣ UPSERT user_context
    await this.db.pool.query(
      `
      INSERT INTO user_context (user_id, budget, travel_type)
      VALUES (?, ?, ?)
      ON DUPLICATE KEY UPDATE
        budget = VALUES(budget),
        travel_type = VALUES(travel_type)
      `,
      [userId, data.budget, data.travel_type],
    );

    // 2️⃣ INVALIDATE recommendations cache (Option A)
    await this.db.pool.query(
      `DELETE FROM recommendations_cache WHERE user_id = ?`,
      [userId],
    );
  }

  // ─────────────────────────────────────────────
  // GET CONTEXT
  // ─────────────────────────────────────────────
  async get(userId: string) {
    const [rows]: any = await this.db.pool.query(
      `
      SELECT budget, travel_type
      FROM user_context
      WHERE user_id = ?
      `,
      [userId],
    );

    if (!rows || rows.length === 0) {
      return null;
    }

    return {
      budget: rows[0].budget,
      travel_type: rows[0].travel_type,
    };
  }
}
