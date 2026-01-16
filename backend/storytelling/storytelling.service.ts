import { Injectable, NotFoundException } from '@nestjs/common';
import { MySQLService } from '../database/mysql.service';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { randomUUID } from 'crypto';
import { RowDataPacket } from 'mysql2';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class StorytellingService {
  constructor(
    private readonly db: MySQLService,
    private readonly http: HttpService,
    private readonly config: ConfigService,
  ) {}

  async getStory(placeId: string): Promise<{ story: string }> {
    // 1️⃣ Cache check
    const [cached] = await this.db.pool.query<RowDataPacket[]>(
      'SELECT story FROM storytelling WHERE place_id = ?',
      [placeId],
    );

    if (cached.length > 0) {
      return { story: cached[0].story as string };
    }

    // 2️⃣ Fetch place
    const [places] = await this.db.pool.query<RowDataPacket[]>(
      'SELECT name, description FROM places WHERE id = ?',
      [placeId],
    );

    if (places.length === 0) {
      throw new NotFoundException('Place not found');
    }

    const name = places[0].name as string;
    const description = places[0].description as string;

    // 3️⃣ Resolve AI service URL (STRICT)
    const aiServiceUrl = this.config.get<string>('AI_SERVICE_URL');

    if (!aiServiceUrl) {
      throw new Error('AI_SERVICE_URL is not configured');
    }

    // 4️⃣ Call Python AI (Groq)
    const aiRes = await firstValueFrom(
      this.http.post(
        `${aiServiceUrl}/storytelling`,
        { name, description },
        { timeout: 60_000 },
      ),
    );

    const story: string | undefined = aiRes.data?.story;

    if (!story) {
      throw new Error('AI storytelling service returned no story');
    }

    // 5️⃣ Persist (race-safe)
    try {
      await this.db.pool.query(
        'INSERT INTO storytelling (id, place_id, story) VALUES (?, ?, ?)',
        [randomUUID(), placeId, story],
      );
    } catch (err: any) {
      // Duplicate entry → another request already inserted it
      if (err?.code !== 'ER_DUP_ENTRY') {
        throw err;
      }
    }

    return { story };
  }
}
