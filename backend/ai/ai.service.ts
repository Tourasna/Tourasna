// src/ai/ai.service.ts
import {
  Injectable,
  InternalServerErrorException,
} from '@nestjs/common';
import axios, { AxiosInstance } from 'axios';

@Injectable()
export class AIService {
  private readonly client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: process.env.AI_SERVICE_URL,
      timeout: 15000,
    });
  }

  // ===== Storytelling =====
  async generateStory(payload: any): Promise<string> {
    try {
      const res = await this.client.post('/story', payload);
      return res.data.story;
    } catch (err) {
      throw new InternalServerErrorException(
        'AI story generation failed',
      );
    }
  }

  // ===== Chatbot =====
  async generateChatReply(payload: {
    system: any;
    messages: { role: 'user' | 'assistant'; content: string }[];
  }): Promise<string> {
    try {
      const res = await this.client.post('/chat', payload);
      return res.data.reply;
    } catch (err) {
      throw new InternalServerErrorException(
        'AI chat generation failed',
      );
    }
  }
}
