import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { jwtCheck } from './auth/jwt.middleware';
import { ensureProfile } from './auth/profile.bootstrap.middleware';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.use(jwtCheck);

  app.use((err, req, res, next) => {
    if (err.name === 'UnauthorizedError') {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    next(err);
  });

  app.use(ensureProfile);

  await app.listen(3000, '0.0.0.0');
  console.log('🚀 Server listening on http://localhost:3000');
}
bootstrap();
