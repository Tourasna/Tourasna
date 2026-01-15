// src/ai/ai.service.ts
import { Injectable, InternalServerErrorException } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class AIService {
  async generateStory(payload: any): Promise<string> {
    try {
      const res = await axios.post(
        `${process.env.AI_SERVICE_URL}/story`,
        payload,
      );
      return res.data.story;
    } catch {
      throw new InternalServerErrorException('AI story generation failed');
    }
  }
}
