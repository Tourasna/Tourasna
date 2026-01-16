import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { AuthModule } from '../auth/auth.module';
import { ProfilesModule } from '../profiles/profiles.module';
import { PlacesModule } from '../places/places.module';
import { StorytellingModule } from '../storytelling/storytelling.module';
import { RecommendationsModule } from '../recommendation/recommendations.module';
import { ContextModule } from '../context/context.module';
import { FavoritesModule } from '../favorites/favorites.module';
import { ChatModule } from './chat/chat.module'

@Module({
  imports: [
    AuthModule,
    DatabaseModule,
    ProfilesModule,
    PlacesModule,
    StorytellingModule,
    ChatModule,
    RecommendationsModule,
    ContextModule,
    FavoritesModule,

  ],
})
export class AppModule {}
