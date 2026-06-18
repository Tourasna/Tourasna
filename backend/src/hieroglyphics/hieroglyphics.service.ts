import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import axios from 'axios';
import FormData = require('form-data');

@Injectable()
export class HieroglyphicsService {
  private readonly aiUrl = process.env.AI_SERVICE_URL || 'http://tourasna-ai:8000';

  async translate(imageBuffer: Buffer, mimetype: string, readingDirection: string = 'auto') {
    try {
      const form = new FormData();
      form.append('image', imageBuffer, {
        filename: 'inscription.jpg',
        contentType: mimetype,
      });
      form.append('reading_direction', readingDirection);
      const response = await axios.post(
        `${this.aiUrl}/hieroglyphics/translate`,
        form,
        {
          headers: form.getHeaders(),
          timeout: 120000,
          maxContentLength: 20 * 1024 * 1024,
        },
      );
      return response.data;
    } catch (error) {
      if (error.response) {
        throw new HttpException(
          error.response.data?.detail || 'Translation failed',
          error.response.status,
        );
      }
      throw new HttpException('AI service unavailable', HttpStatus.SERVICE_UNAVAILABLE);
    }
  }

  // Fetches an image from a URL (S3) and forwards it to the Python AI service.
  // Used exclusively by the public /demo endpoint.
  async translateFromUrl(imageUrl: string, readingDirection: string = 'auto') {
    let imageBuffer: Buffer;
    let mimetype: string;

    try {
      const response = await axios.get(imageUrl, {
        responseType: 'arraybuffer',
        timeout: 15000,
      });
      imageBuffer = Buffer.from(response.data);
      mimetype = response.headers['content-type'] || 'image/jpeg';
    } catch {
      throw new HttpException('Could not fetch sample image', HttpStatus.BAD_GATEWAY);
    }

    return this.translate(imageBuffer, mimetype, readingDirection);
  }

  async translateCodes(codes: string[]) {
    try {
      const response = await axios.post(
        `${this.aiUrl}/hieroglyphics/translate-codes`,
        { codes },
        { timeout: 60000 },
      );
      return response.data;
    } catch (error) {
      if (error.response) {
        throw new HttpException(
          error.response.data?.detail || 'Translation failed',
          error.response.status,
        );
      }
      throw new HttpException('AI service unavailable', HttpStatus.SERVICE_UNAVAILABLE);
    }
  }

  async health() {
    try {
      const response = await axios.get(`${this.aiUrl}/hieroglyphics/health`, { timeout: 5000 });
      return response.data;
    } catch {
      return { status: 'unreachable', models_loaded: false };
    }
  }
}