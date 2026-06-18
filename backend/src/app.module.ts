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
import { ConfigModule } from '@nestjs/config';
import { AgendaModule } from './agenda/agenda.module';
import { PlacesSearchModule } from './places-search/places-search.module';
import { PlacesMapModule } from './places-map/places-map.module';
import { HieroglyphicsModule } from './hieroglyphics/hieroglyphics.module';
import { LandmarksModule } from './landmarks/landmarks.module';
import { ThreeDModule } from './3dmodel/three-d.module';

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
    AgendaModule,
    PlacesMapModule,
    FavoritesModule,
    PlacesSearchModule,
    HieroglyphicsModule,
    ThreeDModule,
    LandmarksModule,
    ConfigModule.forRoot({
      isGlobal: true,
    }),

  ],
})
export class AppModule {}
