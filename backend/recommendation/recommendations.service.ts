// src/recommendations/recommendations.service.ts
import { Injectable } from '@nestjs/common';
import { MySQLService } from '../database/mysql.service';
import axios from 'axios';

@Injectable()
export class RecommendationsService {
  constructor(private readonly db: MySQLService) {}

  async getRecommendations(userId: string) {
    // 1. Check cache (fresh = last 24h)
    const [cached] = await this.db.pool.query(
      `SELECT place_id, score
       FROM recommendations_cache
       WHERE user_id = ?
       AND created_at > NOW() - INTERVAL 1 DAY
       ORDER BY score DESC`,
      [userId],
    );

    if ((cached as any[]).length > 0) {
      return this.enrichPlaces(cached as any[]);
    }

    // 2. Load user profile
    const [[profile]]: any = await this.db.pool.query(
      'SELECT preferences, budget, travel_type FROM profiles WHERE id = ?',
      [userId],
    );

    // 3. Load places
    const [places]: any = await this.db.pool.query(
      'SELECT id, category FROM places',
    );

    // 4. Call Python ML
    const res = await axios.post(
      `${process.env.AI_SERVICE_URL}/recommend/recommendations`,
      {
        user: {
          ...profile,
          preferences: JSON.parse(profile.preferences || '{}'),
        },
        places,
      },
    );

    const recommendations = res.data.recommendations;

    // 5. Save cache
    for (const rec of recommendations) {
      await this.db.pool.query(
        `INSERT INTO recommendations_cache (user_id, place_id, score)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE score = VALUES(score), created_at = NOW()`,
        [userId, rec.place_id, rec.score],
      );
    }

    return this.enrichPlaces(recommendations);
  }

  async enrichPlaces(recommendations: any[]) {
    const ids = recommendations.map((r) => r.place_id);

    if (ids.length === 0) return [];

    const [places]: any = await this.db.pool.query(
      `SELECT * FROM places WHERE id IN (?)`,
      [ids],
    );

    return places;
  }
}
