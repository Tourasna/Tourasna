import { Injectable } from '@nestjs/common';
import { v4 as uuidv4 } from 'uuid';
import { MySQLService } from '../../database/mysql.service';
import WebSocket from 'ws';

@Injectable()
export class ChatService {
  constructor(private readonly db: MySQLService) {}

  // ─────────────────────────────────────────────
  // SESSION
  // ─────────────────────────────────────────────
  async getOrCreateSession(userId: string): Promise<string> {
    const [rows] = await this.db.pool.query<any[]>(
      `
      SELECT id
      FROM chat_sessions
      WHERE user_id = ?
      ORDER BY created_at DESC
      LIMIT 1
      `,
      [userId],
    );

    if (rows.length > 0) {
      return rows[0].id;
    }

    const sessionId = uuidv4();

    await this.db.pool.query(
      `
      INSERT INTO chat_sessions (id, user_id)
      VALUES (?, ?)
      `,
      [sessionId, userId],
    );

    return sessionId;
  }

  // ─────────────────────────────────────────────
  // SAVE USER MESSAGE
  // ─────────────────────────────────────────────
  async saveUserMessage(userId: string, content: string): Promise<void> {
    const sessionId = await this.getOrCreateSession(userId);

    await this.db.pool.query(
      `
      INSERT INTO chat_messages (id, session_id, sender, content)
      VALUES (?, ?, 'user', ?)
      `,
      [uuidv4(), sessionId, content],
    );
  }

  // ─────────────────────────────────────────────
  // SAVE ASSISTANT MESSAGE
  // ─────────────────────────────────────────────
  async saveAssistantMessage(
    userId: string,
    content: string,
  ): Promise<void> {
    const sessionId = await this.getOrCreateSession(userId);

    await this.db.pool.query(
      `
      INSERT INTO chat_messages (id, session_id, sender, content)
      VALUES (?, ?, 'assistant', ?)
      `,
      [uuidv4(), sessionId, content],
    );
  }

  // ─────────────────────────────────────────────
  // LOAD CHAT HISTORY
  // ─────────────────────────────────────────────
  async getHistory(userId: string, limit = 30) {
    const sessionId = await this.getOrCreateSession(userId);

    const [rows] = await this.db.pool.query<any[]>(
      `
      SELECT sender, content, created_at
      FROM chat_messages
      WHERE session_id = ?
      ORDER BY created_at ASC
      LIMIT ?
      `,
      [sessionId, limit],
    );

    return rows;
  }

  // ─────────────────────────────────────────────
  // PYTHON WS CONNECTION
  // ─────────────────────────────────────────────
  createPythonConnection(userId: string): WebSocket {
  const url = `${process.env.AI_CHAT_WS_URL}/chat/${userId}`;

  const ws = new WebSocket(url);

  ws.on('error', (err) => {
    console.error('❌ Python Chat WS error:', err.message);
  });

  return ws;
}
}
