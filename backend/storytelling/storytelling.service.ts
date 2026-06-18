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

  async getAllPlacesWithPhotos(): Promise<any[]> {
    const [rows] = await this.db.pool.query<RowDataPacket[]>(
      `SELECT
        p.id,
        p.name,
        p.description,
        p.category,
        p.glb_url,
        (
          SELECT r.photo_urls
          FROM recommendation_items r
          WHERE LOWER(TRIM(r.name)) = LOWER(TRIM(p.name))
          LIMIT 1
        ) AS photo_urls,
        p.photo_url,
        CASE WHEN s.id IS NOT NULL THEN 1 ELSE 0 END AS has_story
       FROM places p
       LEFT JOIN storytelling s ON s.place_id = p.id
       ORDER BY has_story DESC, RAND()`,
    );

    return rows.map((r) => {
      let photos: string[] = [];
      try {
        if (r.photo_urls) {
          photos = typeof r.photo_urls === 'string'
            ? JSON.parse(r.photo_urls)
            : r.photo_urls;
        }
      } catch (_) {}

      return {
        id:          r.id,
        name:        r.name,
        description: r.description,
        category:    r.category,
        glbUrl:      r.glb_url ?? null,
        photoUrl:    photos[0] ?? r.photo_url ?? null,
        hasStory:    r.has_story === 1,
      };
    });
  }

  async getStory(placeId: string): Promise<{ story: string }> {
    const [cached] = await this.db.pool.query<RowDataPacket[]>(
      'SELECT story FROM storytelling WHERE place_id = ?',
      [placeId],
    );
    if (cached.length > 0) return { story: cached[0].story as string };

    const [places] = await this.db.pool.query<RowDataPacket[]>(
      'SELECT name, description FROM places WHERE id = ?',
      [placeId],
    );
    if (places.length === 0) throw new NotFoundException('Place not found');

    const name        = places[0].name as string;
    const description = places[0].description as string;

    const aiServiceUrl = this.config.get<string>('AI_SERVICE_URL');
    if (!aiServiceUrl) throw new Error('AI_SERVICE_URL is not configured');

    const aiRes = await firstValueFrom(
      this.http.post(
        `${aiServiceUrl}/storytelling`,
        { name, description },
        { timeout: 60_000 },
      ),
    );
    const story: string | undefined = aiRes.data?.story;
    if (!story) throw new Error('AI storytelling service returned no story');

    try {
      await this.db.pool.query(
        'INSERT INTO storytelling (id, place_id, story) VALUES (?, ?, ?)',
        [randomUUID(), placeId, story],
      );
    } catch (err: any) {
      if (err?.code !== 'ER_DUP_ENTRY') throw err;
    }

    return { story };
  }
}
