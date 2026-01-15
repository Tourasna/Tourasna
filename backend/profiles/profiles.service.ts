import { Injectable } from '@nestjs/common';
import { MySQLService } from '../database/mysql.service';

interface FirebaseUserPayload {
  uid: string;
  email?: string;
}

@Injectable()
export class ProfilesService {
  constructor(private readonly db: MySQLService) {}

  // ─────────────────────────────────────────────
  // FIND PROFILE
  // ─────────────────────────────────────────────
  async findById(id: string) {
    const [rows] = await this.db.pool.query(
      'SELECT * FROM profiles WHERE id = ?',
      [id],
    );

    const profile = (rows as any[])[0];
    if (!profile) return null;

    return this.normalizeProfile(profile);
  }

  // ─────────────────────────────────────────────
  // CREATE PROFILE (FIRST LOGIN ONLY)
  // ─────────────────────────────────────────────
  async createFromFirebase(user: FirebaseUserPayload) {
  await this.db.pool.query(
    `
    INSERT INTO profiles (id, email, preferences)
    VALUES (?, ?, CAST(? AS JSON))
    `,
    [
      user.uid,
      user.email ?? null,
      JSON.stringify([]), // ✅ explicit JSON
    ],
  );

  return this.findById(user.uid);
}



  // ─────────────────────────────────────────────
  // COMPLETE PROFILE (ONBOARDING)
  // ─────────────────────────────────────────────
  async completeProfile(userId: string, data: {
  firstName: string;
  lastName: string;
  username: string;
  gender: string;
  nationality: string;
  dateOfBirth: string;
  preferences: string[];
}) {
  // 1️⃣ Validate preferences HARD
  if (
    !Array.isArray(data.preferences) ||
    !data.preferences.every(p => typeof p === 'string')
  ) {
    throw new Error('preferences must be string[]');
  }

  // 2️⃣ Prevent overwrite
  const [rows] = await this.db.pool.query(
    'SELECT first_name FROM profiles WHERE id = ?',
    [userId],
  );

  if ((rows as any[])[0]?.first_name !== null) {
    throw new Error('Profile already completed');
  }

  // 3️⃣ Normalize date
  const dob = data.dateOfBirth.split('T')[0];

  await this.db.pool.query(
    `
    UPDATE profiles
    SET
      first_name = ?,
      last_name = ?,
      username = ?,
      gender = ?,
      nationality = ?,
      date_of_birth = ?,
      preferences = ?
    WHERE id = ?
    `,
    [
      data.firstName,
      data.lastName,
      data.username,
      data.gender,
      data.nationality,
      dob,
      JSON.stringify(data.preferences), // ✅ JSON
      userId,
    ],
  );
}

async updateProfile(
  userId: string,
  data: {
    firstName?: string;
    lastName?: string;
    username?: string;
  },
) {
  await this.db.pool.query(
    `
    UPDATE profiles
    SET
      first_name = ?,
      last_name = ?,
      username = ?
    WHERE id = ?
    `,
    [
      data.firstName ?? null,
      data.lastName ?? null,
      data.username ?? null,
      userId,
    ],
  );
}

  // ─────────────────────────────────────────────
  // UPDATE PREFERENCES ONLY
  // ─────────────────────────────────────────────
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
}

  // ─────────────────────────────────────────────
  // NORMALIZER
  // ─────────────────────────────────────────────
  private normalizeProfile(row: any) {
  return {
    ...row,
    preferences: Array.isArray(row.preferences)
      ? row.preferences
      : [],
  };

  }
}
