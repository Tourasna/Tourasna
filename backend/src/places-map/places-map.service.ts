// src/places-map/places-map.service.ts
import { Injectable } from '@nestjs/common';
import { MySQLService } from '../../database/mysql.service';
import { RowDataPacket } from 'mysql2';

interface PlaceRow extends RowDataPacket {
  id: string;
  name: string;
  latitude: string | number;
  longitude: string | number;
  subcategory: string;
}

interface RecommendationRow extends RowDataPacket {
  id: number;
  name: string;
  latitude: string | number;
  longitude: string | number;
  category: string;
}

@Injectable()
export class PlacesMapService {
  constructor(private readonly mysql: MySQLService) {}

  async getPlaceLocation(id: string) {
    const pool = this.mysql.getPool();
    const [rows] = await pool.query<PlaceRow[]>(
      `SELECT id, name, latitude, longitude, subcategory
       FROM places_agenda WHERE id = ? LIMIT 1`,
      [id],
    );
    if (rows.length === 0) return null;
    const r = rows[0];
    return {
      placeId: r.id,
      name: r.name,
      latitude: Number(r.latitude),
      longitude: Number(r.longitude),
      category: r.subcategory,
    };
  }

  async getMultipleLocations(placeIds: string[]) {
    if (!placeIds.length) return [];
    const pool = this.mysql.getPool();
    const [rows] = await pool.query<PlaceRow[]>(
      `SELECT id, name, latitude, longitude, subcategory
       FROM places_agenda WHERE id IN (?)`,
      [placeIds],
    );
    return rows.map((r) => ({
      placeId: r.id,
      name: r.name,
      latitude: Number(r.latitude),
      longitude: Number(r.longitude),
      category: r.subcategory,
    }));
  }

  // ── NEW: for landmark_id from recommendation_items ──
  async getMultipleByLandmarkIds(landmarkIds: number[]) {
    if (!landmarkIds.length) return [];
    const pool = this.mysql.getPool();
    const [rows] = await pool.query<RecommendationRow[]>(
      `SELECT id, name, latitude, longitude, category
       FROM recommendation_items WHERE id IN (?)`,
      [landmarkIds],
    );
    return rows.map((r) => ({
      placeId: String(r.id),
      name: r.name,
      latitude: Number(r.latitude),
      longitude: Number(r.longitude),
      category: r.category,
    }));
  }
}
