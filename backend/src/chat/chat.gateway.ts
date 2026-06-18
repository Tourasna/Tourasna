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

@WebSocketGateway({ cors: { origin: '*' } })
export class ChatGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  // 🔑 socket.id → python ws
  private pythonSockets = new Map<string, WebSocket>();

  // 🔑 socket.id → response buffer
  private buffers = new Map<string, string>();

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

      // 🔥 CRITICAL: socket identity, NOT DB session
      client.data.sessionId = client.id;

      console.log('✅ WS AUTH:', decoded.uid);
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    const sid = client.data.sessionId;
    if (!sid) return;

    this.pythonSockets.get(sid)?.close();
    this.pythonSockets.delete(sid);
    this.buffers.delete(sid);

    console.log('🔌 WS DISCONNECT', sid);
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
    const sid = client.data.sessionId;

    if (!userId || !sid || !body?.message) return;

    console.log('📨 MESSAGE:', body.message);

    // ✅ Persist using DB session (correct place)
    await this.chatService.saveUserMessage(userId, body.message);

    let pyWs = this.pythonSockets.get(sid);

    // ─────────────────────────────────────────────
    // CREATE PYTHON WS ONCE
    // ─────────────────────────────────────────────
    if (!pyWs || pyWs.readyState !== WebSocket.OPEN && pyWs.readyState !== WebSocket.CONNECTING) {
      console.log('🌐 Connecting to Python WS:', sid);

      pyWs = this.chatService.createPythonConnection(sid);

      this.pythonSockets.set(sid, pyWs);
      this.buffers.set(sid, '');

      pyWs.on('open', () => {
        console.log('🟢 Python WS OPEN', sid);
        pyWs!.send(JSON.stringify({ message: body.message }));
      });

      pyWs.on('message', async (data) => {
        const chunk = data.toString();

        if (chunk === '__END__') {
          const full = this.buffers.get(sid) || '';

          if (full.trim()) {
            await this.chatService.saveAssistantMessage(userId, full);
          }

          this.buffers.set(sid, '');
          client.emit('end');
          return;
        }

        this.buffers.set(sid, (this.buffers.get(sid) || '') + chunk);
        client.emit('stream', chunk);
      });

      pyWs.on('close', () => {
        console.log('🔌 Python WS CLOSED', sid);
        this.pythonSockets.delete(sid);
        this.buffers.delete(sid);
      });

      pyWs.on('error', (err) => {
        console.error('❌ Python WS error:', err.message);
        client.emit('end'); // never block UI
      });

      // 🛡 Safety timeout
      setTimeout(() => {
        if (this.buffers.get(sid)) {
          client.emit('end');
        }
      }, 300000);

      return;
    }

    // ─────────────────────────────────────────────
    // SEND MESSAGE IF ALREADY CONNECTED
    // ─────────────────────────────────────────────
    pyWs.send(JSON.stringify({ message: body.message }));
  }
}
