import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';

// Initialize Firebase Admin ONCE (side-effect import)
import '../auth/firebase-admin';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // CORS (safe for Flutter + Swagger + NGINX)
  app.enableCors({
    origin: '*',
    allowedHeaders: ['Authorization', 'Content-Type'],
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  });

  // Global API prefix (matches NGINX /api)
  app.setGlobalPrefix('api');

  // Swagger configuration
  const config = new DocumentBuilder()
    .setTitle('Tourasna API')
    .setDescription('Tourasna Backend API')
    .setVersion('1.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
      },
      'access-token',
    )
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const port = Number(process.env.PORT) || 3000;

  await app.listen(port, '0.0.0.0');

  console.log('🚀 Backend running on port', port);
  console.log('📘 Swagger available at /api/docs');
  console.log('🤖 AI_SERVICE_URL =', process.env.AI_SERVICE_URL);
}

bootstrap();
