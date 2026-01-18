import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { admin } from './firebase-admin';

@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest();

    console.log('--- AUTH GUARD HIT ---');

    const authHeader = req.headers.authorization;
    console.log('Auth header:', authHeader);

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.log('❌ Missing or invalid Authorization header');
      throw new UnauthorizedException('Missing Authorization header');
    }

    const token = authHeader.replace('Bearer ', '');
    console.log('Token length:', token.length);

    try {
      const decoded = await admin.auth().verifyIdToken(token);

      console.log('✅ Token verified:', decoded.uid);

      req.user = {
        uid: decoded.uid,
        email: decoded.email,
      };

      return true;
    } catch (err) {
      console.error('❌ Token verification failed:', err);
      throw new UnauthorizedException('Invalid Firebase ID token');
    }
  }
}
