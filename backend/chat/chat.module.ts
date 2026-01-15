import { Module } from '@nestjs/common';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';
import { DatabaseModule } from '../database/database.module';
import { AIModule } from '../ai/ai.module';

@Module({
  imports: [
    DatabaseModule,
    AIModule, // 👈 REQUIRED
  ],
  controllers: [ChatController],
  providers: [ChatService],
})
export class ChatModule {}
