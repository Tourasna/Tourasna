import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { ChatService } from './chat.service';
import * as admin from 'firebase-admin';
import WebSocket from 'ws';

@WebSocketGateway({
  cors: { origin: '*' },
})
export class ChatGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private pythonSockets = new Map<string, WebSocket>();
  private responseBuffers = new Map<string, string>();
  private pendingMessages = new Map<string, string[]>();

  constructor(private readonly chatService: ChatService) {}

  // ─────────────────────────────────────────────
  // AUTH
  // ─────────────────────────────────────────────
  async handleConnection(client: Socket) {
    try {
      const token = client.handshake.auth?.token;
      if (!token) return client.disconnect();

      const decoded = await admin.auth().verifyIdToken(token);
      client.data.userId = decoded.uid;

      console.log('✅ WS AUTH:', decoded.uid);
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    const ws = this.pythonSockets.get(client.id);
    if (ws) ws.close();

    this.pythonSockets.delete(client.id);
    this.pendingMessages.delete(client.id);
    this.responseBuffers.delete(client.id);
  }

  // ─────────────────────────────────────────────
  // MESSAGE FROM FLUTTER
  // ─────────────────────────────────────────────
  @SubscribeMessage('message')
  async handleMessage(
    @MessageBody() body: { message: string },
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId;
    if (!userId) return;

    await this.chatService.saveUserMessage(userId, body.message);

    let pyWs = this.pythonSockets.get(client.id);

    if (!pyWs) {
      pyWs = this.chatService.createPythonConnection(userId);

      this.pythonSockets.set(client.id, pyWs);
      this.pendingMessages.set(client.id, []);
      this.responseBuffers.set(client.id, '');

      pyWs.on('open', () => {
        const queue = this.pendingMessages.get(client.id) || [];
        queue.forEach((msg) => pyWs!.send(msg));
        this.pendingMessages.set(client.id, []);
      });

      pyWs.on('message', (data) => {
        const chunk = data.toString();

        if (chunk === '__END__') {
          const full = this.responseBuffers.get(client.id) || '';

          this.chatService.saveAssistantMessage(userId, full);

          this.responseBuffers.set(client.id, '');
          client.emit('end');
          return;
        }

        const current = this.responseBuffers.get(client.id) || '';
        this.responseBuffers.set(client.id, current + chunk);

        client.emit('stream', chunk);
      });

      pyWs.on('close', () => {
        this.pythonSockets.delete(client.id);
        this.pendingMessages.delete(client.id);
        this.responseBuffers.delete(client.id);
      });

      pyWs.on('error', (err) => {
        console.error('❌ Python WS error:', err.message);
      });
    }

    const payload = JSON.stringify({ message: body.message });

    if (pyWs.readyState === WebSocket.OPEN) {
      pyWs.send(payload);
    } else {
      this.pendingMessages.get(client.id)!.push(payload);
    }
  }
}
