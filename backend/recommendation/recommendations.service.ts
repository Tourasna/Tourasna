import {
  Injectable,
  InternalServerErrorException,
  BadRequestException,
} from '@nestjs/common';
import axios from 'axios';
import { MySQLService } from '../database/mysql.service';
import { v4 as uuid } from 'uuid';

@Injectable()
export class RecommendationsService {
  constructor(private readonly db: MySQLService) {}

  // ─────────────────────────────────────────────
  // GET RECOMMENDATIONS
  // ─────────────────────────────────────────────
  async getRecommendations(
    userId: string,
    planType: string = 'DayPlan',
    tripDays: number | null = null,
  ) {
    console.log(`▶️ RECOMMENDATIONS | User: ${userId} | Plan: ${planType} | Days: ${tripDays}`);

    if (planType === 'TripPlan' && (!tripDays || tripDays < 1 || tripDays > 14)) {
      throw new BadRequestException('trip_days must be between 1 and 14 for TripPlan');
    }

    // ── 1. CHECK CACHE ──────────────────────────────────────────────────
    const cacheQuery =
      planType === 'TripPlan'
        ? `SELECT ri.*, rc.score, rc.plan_type, rc.trip_days
           FROM recommendations_cache rc
           JOIN recommendation_items ri ON ri.id = rc.item_id
           WHERE rc.user_id = ? AND rc.plan_type = ? AND rc.trip_days = ?
           ORDER BY rc.score DESC`
        : `SELECT ri.*, rc.score, rc.plan_type
           FROM recommendations_cache rc
           JOIN recommendation_items ri ON ri.id = rc.item_id
           WHERE rc.user_id = ? AND rc.plan_type = ? AND (rc.trip_days IS NULL OR rc.trip_days = 0)
           ORDER BY rc.score DESC`;

    const cacheParams =
      planType === 'TripPlan' ? [userId, planType, tripDays] : [userId, planType];

    const [cached]: any = await this.db.pool.query(cacheQuery, cacheParams);

    if (cached.length > 0) {
      console.log(`✅ CACHE HIT: ${cached.length} items`);
      return planType === 'TripPlan'
        ? this.formatTripPlanResponse(cached, tripDays!)
        : cached;
    }

    // ── 2. LOAD PROFILE ─────────────────────────────────────────────────
    const [profiles]: any = await this.db.pool.query(
      `SELECT * FROM profiles WHERE id = ?`,
      [userId],
    );
    const profile = profiles[0];
    if (!profile) throw new InternalServerErrorException('Profile not found');

    // ── 3. LOAD CONTEXT (budget + travel_type) ───────────────────────────
    const [contexts]: any = await this.db.pool.query(
      `SELECT budget, travel_type, interaction_count FROM user_context WHERE user_id = ?`,
      [userId],
    );
    const budget = contexts[0]?.budget ?? 'medium';
    const travelType = contexts[0]?.travel_type ?? 'solo';
    const interactionCount = contexts[0]?.interaction_count ?? 0;

    // ── 4. LOAD FULL INTERACTION HISTORY (like/dislike only) ─────────────
    const [interactions]: any = await this.db.pool.query(
      `SELECT COALESCE(landmark_category, category) AS category, affinity_signal
       FROM user_interactions
       WHERE user_id = ? AND event_type IN ('like', 'dislike')
       ORDER BY created_at ASC`,
      [userId],
    );

    console.log(`📊 Interaction history: ${interactions.length} records`);

    // ── 5. BUILD AI PAYLOAD ──────────────────────────────────────────────
    const payload = this.buildAIPayload(
      profile,
      budget,
      travelType,
      userId,
      interactionCount,
      interactions,
      planType,
      tripDays,
    );
    console.log('🧠 AI PAYLOAD:', JSON.stringify(payload));

    // ── 6. CALL PYTHON AI ────────────────────────────────────────────────
    let aiResults: any[];
    try {
      const res = await axios.post(
        `${process.env.AI_SERVICE_URL}/recommendations`,
        payload,
      );

      // DayPlan returns flat array, TripPlan returns { days: [...] }
      if (planType === 'TripPlan') {
        aiResults = res.data?.days?.flatMap((d: any) =>
          (d.landmarks ?? []).map((l: any) => ({ ...l, day: d.day })),
        );
      } else {
        aiResults = res.data?.recommendations ?? res.data;
      }

      if (!Array.isArray(aiResults)) throw new Error('Invalid AI response format');
      console.log(`🤖 AI returned ${aiResults.length} items`);
    } catch (err) {
      console.error('❌ AI CALL FAILED:', err.message);
      throw new InternalServerErrorException('Recommendation AI failed');
    }

    // ── 7. CACHE RESULTS ─────────────────────────────────────────────────
    for (const r of aiResults) {
      const [items]: any = await this.db.pool.query(
        `SELECT id FROM recommendation_items
         WHERE LOWER(name) LIKE CONCAT('%', LOWER(?), '%') LIMIT 1`,
        [r.name],
      );
      const item = items[0];
      if (!item) {
        console.warn(`⚠️ No DB match for: ${r.name}`);
        continue;
      }

      const score = r.final_score ?? r.score ?? 0;

      await this.db.pool.query(
        `INSERT INTO recommendations_cache (id, user_id, plan_type, trip_days, item_id, score)
         VALUES (?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE score = VALUES(score)`,
        [uuid(), userId, planType, tripDays ?? null, item.id, score],
      );
    }

    console.log('💾 CACHE SAVED');

    // ── 8. RETURN FROM CACHE ─────────────────────────────────────────────
    const [finalResults]: any = await this.db.pool.query(cacheQuery, cacheParams);

    return planType === 'TripPlan'
      ? this.formatTripPlanResponse(finalResults, tripDays!)
      : finalResults;
  }

  // ─────────────────────────────────────────────
  // SAVE FEEDBACK (like / dislike)
  // ─────────────────────────────────────────────
  async saveFeedback(
    userId: string,
    landmarkName: string,
    eventType: 'like' | 'dislike',
  ) {
    if (!['like', 'dislike'].includes(eventType)) {
      throw new BadRequestException('event_type must be like or dislike');
    }

    const affinitySignal = eventType === 'like' ? 0.8 : -0.3;

    // Look up category from recommendation_items
    const [items]: any = await this.db.pool.query(
      `SELECT category FROM recommendation_items
       WHERE LOWER(name) LIKE CONCAT('%', LOWER(?), '%') LIMIT 1`,
      [landmarkName],
    );
    const landmarkCategory = items[0]?.category ?? 'Unknown';

    // Save interaction
    await this.db.pool.query(
      `INSERT INTO user_interactions
         (id, timestamp, user_id, landmark_name, landmark_category, event_type, affinity_signal)
       VALUES (?, NOW(), ?, ?, ?, ?, ?)`,
      [uuid(), userId, landmarkName, landmarkCategory, eventType, affinitySignal],
    );

    // Increment interaction_count — upsert in case row doesn't exist
    await this.db.pool.query(
      `INSERT INTO user_context (user_id, budget, travel_type, interaction_count)
       VALUES (?, 'medium', 'solo', 1)
       ON DUPLICATE KEY UPDATE interaction_count = interaction_count + 1`,
      [userId],
    );

    // Bust cache for this user (both plan types)
    await this.db.pool.query(
      `DELETE FROM recommendations_cache WHERE user_id = ?`,
      [userId],
    );

    console.log(`✅ FEEDBACK | User: ${userId} | ${eventType} | ${landmarkName} (${landmarkCategory})`);

    return { success: true, landmark: landmarkName, event: eventType };
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  private buildAIPayload(
    profile: any,
    budget: string,
    travelType: string,
    userId: string,
    interactionCount: number,
    interactionHistory: any[],
    planType: string,
    tripDays: number | null,
  ) {
    const age = profile.date_of_birth
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

    const payload: any = {
      plan_type: planType,
      user_id: userId,
      interaction_count: interactionCount,
      user_age: age,
      user_gender: profile.gender ?? 'Male',
      user_budget: budget,
      user_travel_type: travelType,
      user_preferences: preferences.length > 0 ? preferences : ['Museum'],
      interaction_history: interactionHistory,
    };

    if (planType === 'TripPlan' && tripDays) {
      payload.trip_days = tripDays;
    }

    return payload;
  }

  private formatTripPlanResponse(items: any[], tripDays: number) {
    const days: any[] = [];
    for (let d = 1; d <= tripDays; d++) {
      days.push({
        day: d,
        landmarks: items.filter((_, i) => Math.floor(i / 5) + 1 === d),
      });
    }
    return {
      plan_type: 'TripPlan',
      trip_days: tripDays,
      total_landmarks: items.length,
      days,
    };
  }
}