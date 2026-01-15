import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

// 🔥 Initialize Firebase Admin ONCE (side-effect import)
import '../auth/firebase-admin';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  await app.listen(process.env.PORT ?? 3000);

  console.log('Server running on port', process.env.PORT ?? 3000);
}

bootstrap();
