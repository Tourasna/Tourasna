// src/storytelling/storytelling.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { MySQLService } from '../database/mysql.service';
import { AIService } from '../ai/ai.service';

@Injectable()
export class StorytellingService {
  constructor(
    private readonly db: MySQLService,
    private readonly ai: AIService,
  ) {}

  async getStory(placeId: string) {
    // 1. Check cache
    const [rows] = await this.db.pool.query(
      'SELECT story FROM storytelling WHERE place_id = ?',
      [placeId],
    );

    if ((rows as any[]).length > 0) {
      return (rows as any[])[0].story;
    }

    // 2. Load place
    const [places] = await this.db.pool.query(
      'SELECT name, category, description FROM places WHERE id = ?',
      [placeId],
    );

    const place = (places as any[])[0];
    if (!place) throw new NotFoundException('Place not found');

    // 3. Generate story
    const story = await this.ai.generateStory({ place });

    // 4. Save
    await this.db.pool.query(
      'INSERT INTO storytelling (place_id, story) VALUES (?, ?)',
      [placeId, story],
    );

    return story;
  }
}
