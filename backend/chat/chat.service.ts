// src/chat/chat.service.ts
import {
  Injectable,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { v4 as uuid } from 'uuid';
import { MySQLService } from '../database/mysql.service';
import { AIService } from '../ai/ai.service';

@Injectable()
export class ChatService {
  constructor(
    private readonly db: MySQLService,
    private readonly ai: AIService,
  ) {}

  // Create a new chat session
  async startSession(userId: string): Promise<string> {
    const sessionId = uuid();

    await this.db.pool.query(
      `INSERT INTO chat_sessions (id, user_id) VALUES (?, ?)`,
      [sessionId, userId],
    );

    return sessionId;
  }

  // Resolve session (reuse latest if none provided)
  async resolveSession(userId: string, sessionId?: string) {
    if (sessionId) {
      const [rows] = await this.db.pool.query(
        `SELECT * FROM chat_sessions WHERE id = ?`,
        [sessionId],
      );

      const session = (rows as any[])[0];

      if (!session) {
        throw new NotFoundException('Chat session not found');
      }

      if (session.user_id !== userId) {
        throw new ForbiddenException('Access denied to chat session');
      }

      return session;
    }

    const [rows] = await this.db.pool.query(
      `
      SELECT * FROM chat_sessions
      WHERE user_id = ?
      ORDER BY updated_at DESC
      LIMIT 1
      `,
      [userId],
    );

    if ((rows as any[]).length > 0) {
      return (rows as any[])[0];
    }

    const newSessionId = await this.startSession(userId);
    return { id: newSessionId };
  }

  // Load recent chat history
  async getHistory(sessionId: string, limit = 12) {
    const [rows] = await this.db.pool.query(
      `
      SELECT sender, content
      FROM chat_messages
      WHERE session_id = ?
      ORDER BY created_at ASC
      LIMIT ?
      `,
      [sessionId, limit],
    );

    return rows as { sender: 'user' | 'assistant'; content: string }[];
  }

  // Main chat flow
  async handleMessage(
    userId: string,
    message: string,
    sessionId?: string,
  ) {
    const session = await this.resolveSession(userId, sessionId);

    // Save user message
    await this.addMessage(session.id, 'user', message);

    // Update activity
    await this.touchSession(session.id);

    // Build AI context
    const history = await this.getHistory(session.id);

    const aiPayload = {
      system: {
        app: 'Tourasna cultural tourism assistant for Cairo & Giza',
      },
      messages: history.map((m) => ({
        role: m.sender,
        content: m.content,
      })),
    };

    let reply: string;

    try {
      reply = await this.ai.generateChatReply(aiPayload);

      // Save ONLY successful AI replies
      await this.addMessage(session.id, 'assistant', reply);
      await this.touchSession(session.id);
    } catch {
      reply = 'I am having trouble right now. Please try again.';
    }

    return {
      session_id: session.id,
      reply,
    };
  }

  // Persist a message
  private async addMessage(
    sessionId: string,
    sender: 'user' | 'assistant',
    content: string,
  ) {
    await this.db.pool.query(
      `
      INSERT INTO chat_messages (id, session_id, sender, content)
      VALUES (?, ?, ?, ?)
      `,
      [uuid(), sessionId, sender, content],
    );
  }

  // Update session activity timestamp
  private async touchSession(sessionId: string) {
    await this.db.pool.query(
      `UPDATE chat_sessions SET updated_at = NOW() WHERE id = ?`,
      [sessionId],
    );
  }
}
