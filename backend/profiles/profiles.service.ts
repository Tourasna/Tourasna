import { Injectable, ConflictException } from '@nestjs/common';
import { MySQLService } from '../database/mysql.service';

interface FirebaseUserPayload {
  uid: string;
  email?: string;
}

@Injectable()
export class ProfilesService {
  constructor(private readonly db: MySQLService) {}

  async findById(id: string) {
    const [rows] = await this.db.pool.query(
      'SELECT * FROM profiles WHERE id = ?',
      [id],
    );
    const profile = (rows as any[])[0];
    if (!profile) return null;
    return this.normalizeProfile(profile);
  }

  async createFromFirebase(user: FirebaseUserPayload) {
    await this.db.pool.query(
      `INSERT INTO profiles (id, email, preferences)
       VALUES (?, ?, CAST(? AS JSON))`,
      [user.uid, user.email ?? null, JSON.stringify([])],
    );
    return this.findById(user.uid);
  }

  async completeProfile(
    userId: string,
    data: {
      firstName: string;
      lastName: string;
      username: string;
      gender: string;
      nationality: string;
      dateOfBirth: string;
      preferences: string[];
    },
  ) {
    if (
      !Array.isArray(data.preferences) ||
      !data.preferences.every(p => typeof p === 'string')
    ) {
      throw new Error('preferences must be string[]');
    }

    const [rows] = await this.db.pool.query(
      'SELECT first_name FROM profiles WHERE id = ?',
      [userId],
    );

    if ((rows as any[])[0]?.first_name !== null) {
      throw new Error('Profile already completed');
    }

    const dob = data.dateOfBirth.split('T')[0];

    try {
      await this.db.pool.query(
        `UPDATE profiles
         SET first_name = ?, last_name = ?, username = ?,
             gender = ?, nationality = ?, date_of_birth = ?,
             preferences = CAST(? AS JSON)
         WHERE id = ?`,
        [
          data.firstName, data.lastName, data.username,
          data.gender, data.nationality, dob,
          JSON.stringify(data.preferences), userId,
        ],
      );
    } catch (err: any) {
      if (err.code === 'ER_DUP_ENTRY' && err.sqlMessage?.includes('username')) {
        throw new ConflictException('Username already taken. Please choose a different username.');
      }
      throw err;
    }

    return this.findById(userId);
  }

  async updateProfile(
    userId: string,
    data: {
      firstName?: string;
      lastName?: string;
      username?: string;
      budget?: string;
      travelType?: string;
    },
  ) {
    const profileFields: string[] = [];
    const profileValues: any[] = [];

    if (data.firstName !== undefined) {
      profileFields.push('first_name = ?');
      profileValues.push(data.firstName);
    }
    if (data.lastName !== undefined) {
      profileFields.push('last_name = ?');
      profileValues.push(data.lastName);
    }
    if (data.username !== undefined) {
      profileFields.push('username = ?');
      profileValues.push(data.username);
    }
    if (data.budget !== undefined) {
      profileFields.push('budget = ?');
      profileValues.push(data.budget);
    }
    if (data.travelType !== undefined) {
      profileFields.push('travel_type = ?');
      profileValues.push(data.travelType);
    }

    if (profileFields.length > 0) {
      try {
        profileValues.push(userId);
        await this.db.pool.query(
          `UPDATE profiles SET ${profileFields.join(', ')} WHERE id = ?`,
          profileValues,
        );
      } catch (err: any) {
        if (err.code === 'ER_DUP_ENTRY' && err.sqlMessage?.includes('username')) {
          throw new ConflictException('Username already taken. Please choose a different username.');
        }
        throw err;
      }
    }

    if (data.budget !== undefined || data.travelType !== undefined) {
      const contextFields: string[] = [];
      const contextValues: any[] = [];

      if (data.budget !== undefined) {
        contextFields.push('budget = ?');
        contextValues.push(data.budget);
      }
      if (data.travelType !== undefined) {
        contextFields.push('travel_type = ?');
        contextValues.push(data.travelType);
      }

      contextValues.push(userId);

      await this.db.pool.query(
        `INSERT INTO user_context (user_id, budget, travel_type, interaction_count)
         VALUES (?, ?, ?, 0)
         ON DUPLICATE KEY UPDATE ${contextFields.join(', ')}`,
        [userId, data.budget ?? 'medium', data.travelType ?? 'solo', ...contextValues],
      );
    }

    return this.findById(userId);
  }

  async updatePreferences(userId: string, preferences: string[]) {
    if (
      !Array.isArray(preferences) ||
      !preferences.every(p => typeof p === 'string')
    ) {
      throw new Error('preferences must be string[]');
    }

    await this.db.pool.query(
      'UPDATE profiles SET preferences = CAST(? AS JSON) WHERE id = ?',
      [JSON.stringify(preferences), userId],
    );

    return this.findById(userId);
  }

  private normalizeProfile(row: any) {
    return {
      ...row,
      preferences: Array.isArray(row.preferences) ? row.preferences : [],
    };
  }
}
