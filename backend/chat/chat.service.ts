// src/chat/chat.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { v4 as uuid } from 'uuid';
import { MySQLService } from '../database/mysql.service';

@Injectable()
export class ChatService {
  constructor(private readonly db: MySQLService) {}

  async startSession(userId: string) {
    const sessionId = uuid();

    await this.db.pool.query(
      'INSERT INTO chat_sessions (id, user_id) VALUES (?, ?)',
      [sessionId, userId],
    );

    return sessionId;
  }

  async getSession(sessionId: string, userId: string) {
    const [rows] = await this.db.pool.query(
      'SELECT * FROM chat_sessions WHERE id = ? AND user_id = ?',
      [sessionId, userId],
    );

    if ((rows as any[]).length === 0) {
      throw new NotFoundException('Chat session not found');
    }
  }

  async getHistory(sessionId: string) {
    const [rows] = await this.db.pool.query(
      `SELECT role, content, created_at
       FROM chat_messages
       WHERE session_id = ?
       ORDER BY created_at ASC`,
      [sessionId],
    );

    return rows;
  }

  async addMessage(sessionId: string, role: 'user' | 'assistant', content: string) {
    await this.db.pool.query(
      'INSERT INTO chat_messages (session_id, role, content) VALUES (?, ?, ?)',
      [sessionId, role, content],
    );
  }
}
