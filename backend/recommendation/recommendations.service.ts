import {
  Injectable,
  InternalServerErrorException,
} from '@nestjs/common';
import axios from 'axios';
import { MySQLService } from '../database/mysql.service';
import { v4 as uuid } from 'uuid';

@Injectable()
export class RecommendationsService {
  constructor(private readonly db: MySQLService) {}

  async getRecommendations(userId: string) {
    console.log('▶️ GET RECOMMENDATIONS FOR USER:', userId);

    // 1️⃣ Cache first
    const [cached] = await this.db.pool.query(
      `
      SELECT ri.*, rc.score
      FROM recommendations_cache rc
      JOIN recommendation_items ri ON ri.id = rc.item_id
      WHERE rc.user_id = ?
      ORDER BY rc.score DESC
      `,
      [userId],
    );

    if ((cached as any[]).length > 0) {
      console.log('✅ RETURNING CACHED:', (cached as any[]).length);
      return cached;
    }

    // 2️⃣ Load profile
    const [profiles] = await this.db.pool.query(
      `SELECT * FROM profiles WHERE id = ?`,
      [userId],
    );

    const profile = (profiles as any[])[0];
    if (!profile) {
      throw new InternalServerErrorException('Profile not found');
    }

    console.log('📦 PROFILE LOADED:', profile);

    // 3️⃣ Build AI payload
    const payload = this.buildAIPayload(profile);
    console.log('🧠 AI PAYLOAD:', payload);

    // 4️⃣ Call AI
    let aiResults: any[];

    try {
      const res = await axios.post(
        `${process.env.AI_SERVICE_URL}/recommendations`,
        payload,
      );

      console.log('🤖 RAW AI RESPONSE:', res.data);

      aiResults = res.data?.recommendations;

      if (!Array.isArray(aiResults)) {
        throw new Error('Invalid AI response format');
      }

      console.log('✅ AI RESULTS COUNT:', aiResults.length);
    } catch (err) {
      console.error('❌ AI CALL FAILED:', err);
      throw new InternalServerErrorException('Recommendation AI failed');
    }

    // 5️⃣ Resolve names → IDs + cache
    for (const r of aiResults) {
      const [items] = await this.db.pool.query(
        `
        SELECT id, name
        FROM recommendation_items
        WHERE LOWER(name) LIKE CONCAT('%', LOWER(?), '%')
        LIMIT 1
        `,
        [r.name],
      );

      const item = (items as any[])[0];

      if (!item) {
        console.warn('⚠️ NO MATCH FOR AI ITEM:', r.name);
        continue;
      }

      await this.db.pool.query(
        `
        INSERT INTO recommendations_cache (id, user_id, item_id, score)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE score = VALUES(score)
        `,
        [uuid(), userId, item.id, r.score],
      );
    }

    console.log('💾 RECOMMENDATIONS CACHED');

    // 6️⃣ Return final results
    const [finalResults] = await this.db.pool.query(
      `
      SELECT ri.*, rc.score
      FROM recommendations_cache rc
      JOIN recommendation_items ri ON ri.id = rc.item_id
      WHERE rc.user_id = ?
      ORDER BY rc.score DESC
      `,
      [userId],
    );

    return finalResults;
  }

  // ─────────────────────────────────────────────

  private buildAIPayload(profile: any) {
    const age =
      profile.date_of_birth
        ? Math.floor(
            (Date.now() - new Date(profile.date_of_birth).getTime()) /
              (365.25 * 24 * 60 * 60 * 1000),
          )
        : 30;

    const preferences =
      typeof profile.preferences === 'string'
        ? JSON.parse(profile.preferences)
        : Array.isArray(profile.preferences)
        ? profile.preferences
        : [];

    return {
      user_age: age,
      user_gender: profile.gender || 'male',
      user_budget: profile.budget || 'medium',
      user_travel_type: profile.travel_type || 'solo',
      user_preferences: preferences,
    };
  }
}
