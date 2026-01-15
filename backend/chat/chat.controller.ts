// src/chat/chat.controller.ts
import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import { ChatService } from './chat.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';

@Controller('chat')
@UseGuards(FirebaseAuthGuard)
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  // Main chat endpoint (ONLY entry point)
  @Post('message')
  async sendMessage(
    @Req() req,
    @Body() body: { session_id?: string; message: string },
  ) {
    const userId = req.user.uid;
    const { session_id, message } = body;

    if (!message || !message.trim()) {
      throw new BadRequestException('Message cannot be empty');
    }

    return this.chat.handleMessage(
      userId,
      message.trim(),
      session_id,
    );
  }

  // Fetch chat history
  @Get(':sessionId')
  async history(@Req() req, @Param('sessionId') sessionId: string) {
    const userId = req.user.uid;

    const session = await this.chat.resolveSession(userId, sessionId);

    return this.chat.getHistory(session.id);
  }
}
