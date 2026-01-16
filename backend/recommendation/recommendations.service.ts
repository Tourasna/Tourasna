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

    // 1️⃣ CACHE FIRST
    const [cached]: any = await this.db.pool.query(
      `
      SELECT ri.*, rc.score
      FROM recommendations_cache rc
      JOIN recommendation_items ri ON ri.id = rc.item_id
      WHERE rc.user_id = ?
      ORDER BY rc.score DESC
      `,
      [userId],
    );

    if (cached.length > 0) {
      console.log('✅ RETURNING CACHED:', cached.length);
      return cached;
    }

    // 2️⃣ LOAD PROFILE (IDENTITY DATA ONLY)
    const [profiles]: any = await this.db.pool.query(
      `SELECT * FROM profiles WHERE id = ?`,
      [userId],
    );

    const profile = profiles[0];
    if (!profile) {
      throw new InternalServerErrorException('Profile not found');
    }

    // 3️⃣ LOAD USER CONTEXT (TRIP INTENT)
    const [contexts]: any = await this.db.pool.query(
      `
      SELECT budget, travel_type
      FROM user_context
      WHERE user_id = ?
      `,
      [userId],
    );

    const budget = contexts[0]?.budget ?? 'medium';
    const travelType = contexts[0]?.travel_type ?? 'solo';

    console.log('📦 PROFILE LOADED');
    console.log('🧭 CONTEXT:', { budget, travelType });

    // 4️⃣ BUILD AI PAYLOAD
    const payload = this.buildAIPayload(profile, budget, travelType);
    console.log('🧠 AI PAYLOAD:', payload);

    // 5️⃣ CALL AI
    let aiResults: any[];

    try {
      const res = await axios.post(
        `${process.env.AI_SERVICE_URL}/recommendations`,
        payload,
      );

      aiResults = res.data?.recommendations;

      if (!Array.isArray(aiResults)) {
        throw new Error('Invalid AI response format');
      }

      console.log('🤖 AI RESULTS COUNT:', aiResults.length);
    } catch (err) {
      console.error('❌ AI CALL FAILED:', err);
      throw new InternalServerErrorException('Recommendation AI failed');
    }

    // 6️⃣ RESOLVE NAMES → IDS + CACHE
    for (const r of aiResults) {
      const [items]: any = await this.db.pool.query(
        `
        SELECT id
        FROM recommendation_items
        WHERE LOWER(name) LIKE CONCAT('%', LOWER(?), '%')
        LIMIT 1
        `,
        [r.name],
      );

      const item = items[0];
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

    // 7️⃣ RETURN FINAL RESULTS
    const [finalResults]: any = await this.db.pool.query(
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
  // BUILD AI PAYLOAD (FINAL, CLEAN)
  // ─────────────────────────────────────────────
  private buildAIPayload(
    profile: any,
    budget: string,
    travelType: string,
  ) {
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
      user_budget: budget,
      user_travel_type: travelType,
      user_preferences: preferences,
    };
  }
}
