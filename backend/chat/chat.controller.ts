// src/chat/chat.controller.ts
import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ChatService } from './chat.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';

@Controller('chat')
@UseGuards(FirebaseAuthGuard)
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Post('start')
  async start(@Req() req) {
    const userId = req.user.uid;
    const sessionId = await this.chat.startSession(userId);
    return { session_id: sessionId };
  }

  @Post('message')
  async sendMessage(
    @Req() req,
    @Body() body: { session_id: string; message: string },
  ) {
    const userId = req.user.uid;
    const { session_id, message } = body;

    // Ensure session belongs to user
    await this.chat.getSession(session_id, userId);

    // Save user message
    await this.chat.addMessage(session_id, 'user', message);

    // Placeholder assistant reply (AI comes later)
    const reply = 'I understand. Tell me more.';

    await this.chat.addMessage(session_id, 'assistant', reply);

    return { reply };
  }

  @Get(':sessionId')
  async history(@Req() req, @Param('sessionId') sessionId: string) {
    const userId = req.user.uid;

    await this.chat.getSession(sessionId, userId);
    return this.chat.getHistory(sessionId);
  }
}
