import { Injectable } from '@nestjs/common';
import { MySQLService } from '../database/mysql.service';
import * as https from 'https';
import * as http from 'http';
import * as crypto from 'crypto';

interface AwsCredentials {
  accessKeyId: string;
  secretAccessKey: string;
  sessionToken: string;
}

@Injectable()
export class AvatarService {
  private readonly bucket = 'tourasna-assets';
  private readonly region = 'eu-north-1';

  constructor(private readonly db: MySQLService) {}

  async uploadAvatar(userId: string, buffer: Buffer, mimetype: string): Promise<string> {
    const ext = mimetype === 'image/png' ? 'png' : 'jpg';
    const key = `avatars/${userId}.${ext}`;

    console.log(`[Avatar] Starting upload for user ${userId}, size: ${buffer.length} bytes`);

    const creds = await this.getInstanceCredentials();
    console.log(`[Avatar] Got credentials for key: ${creds.accessKeyId.substring(0, 8)}...`);

    await this.putObject(key, buffer, mimetype, creds);
    console.log(`[Avatar] S3 upload successful`);

    const url = `https://${this.bucket}.s3.${this.region}.amazonaws.com/${key}`;

    await this.db.pool.query(
      'UPDATE profiles SET avatar_url = ? WHERE id = ?',
      [url, userId],
    );

    console.log(`[Avatar] DB updated with url: ${url}`);
    return url;
  }

  async removeAvatar(userId: string): Promise<void> {
    const [rows]: any = await this.db.pool.query(
      'SELECT avatar_url FROM profiles WHERE id = ?',
      [userId],
    );

    if (!rows.length || !rows[0].avatar_url) return;

    const avatarUrl: string = rows[0].avatar_url;
    const url = new URL(avatarUrl);
    const key = url.pathname.slice(1);

    const creds = await this.getInstanceCredentials();
    await this.deleteObject(key, creds);

    await this.db.pool.query(
      'UPDATE profiles SET avatar_url = NULL WHERE id = ?',
      [userId],
    );

    console.log(`[Avatar] Avatar removed for user ${userId}`);
  }

  private async deleteObject(key: string, creds: AwsCredentials): Promise<void> {
    const region = this.region;
    const bucket = this.bucket;
    const now = new Date();
    const dateStamp = now.toISOString().slice(0, 10).replace(/-/g, '');
    const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '').slice(0, 15) + 'Z';
    const host = `${bucket}.s3.${region}.amazonaws.com`;
    const payloadHash = crypto.createHash('sha256').update('').digest('hex');

    const canonicalHeaders =
      `host:${host}\n` +
      `x-amz-content-sha256:${payloadHash}\n` +
      `x-amz-date:${amzDate}\n` +
      `x-amz-security-token:${creds.sessionToken}\n`;

    const signedHeaders = 'host;x-amz-content-sha256;x-amz-date;x-amz-security-token';
    const canonicalRequest = `DELETE\n/${key}\n\n${canonicalHeaders}\n${signedHeaders}\n${payloadHash}`;
    const credentialScope = `${dateStamp}/${region}/s3/aws4_request`;
    const stringToSign =
      `AWS4-HMAC-SHA256\n${amzDate}\n${credentialScope}\n` +
      crypto.createHash('sha256').update(canonicalRequest).digest('hex');

    const signingKey = this.getSigningKey(creds.secretAccessKey, dateStamp, region, 's3');
    const signature = crypto.createHmac('sha256', signingKey).update(stringToSign).digest('hex');
    const authHeader =
      `AWS4-HMAC-SHA256 Credential=${creds.accessKeyId}/${credentialScope}, ` +
      `SignedHeaders=${signedHeaders}, Signature=${signature}`;

    return new Promise((resolve, reject) => {
      const req = https.request({
        hostname: host,
        path: `/${key}`,
        method: 'DELETE',
        headers: {
          'x-amz-date': amzDate,
          'x-amz-content-sha256': payloadHash,
          'x-amz-security-token': creds.sessionToken,
          'Authorization': authHeader,
        },
      }, (res) => {
        res.on('data', () => {});
        res.on('end', () => {
          console.log(`[Avatar] S3 delete status: ${res.statusCode}`);
          if (res.statusCode === 204 || res.statusCode === 200) resolve();
          else reject(new Error(`S3 delete failed: ${res.statusCode}`));
        });
      });
      req.on('error', reject);
      req.end();
    });
  }

  private async getIMDSv2Token(): Promise<string> {
    return new Promise((resolve, reject) => {
      const req = http.request({
        hostname: '169.254.169.254',
        path: '/latest/api/token',
        method: 'PUT',
        headers: {
          'X-aws-ec2-metadata-token-ttl-seconds': '21600',
        },
      }, (res) => {
        let data = '';
        res.on('data', (chunk) => data += chunk);
        res.on('end', () => resolve(data.trim()));
      });
      req.on('error', reject);
      req.setTimeout(3000, () => { req.destroy(); reject(new Error('IMDSv2 token timeout')); });
      req.end();
    });
  }

  private async getInstanceCredentials(): Promise<AwsCredentials> {
    const token = await this.getIMDSv2Token();
    console.log(`[Avatar] Got IMDSv2 token`);

    const roleName = await this.httpGet(
      'http://169.254.169.254/latest/meta-data/iam/security-credentials/',
      token,
    );
    console.log(`[Avatar] IAM role: ${roleName.trim()}`);

    const credsJson = await this.httpGet(
      `http://169.254.169.254/latest/meta-data/iam/security-credentials/${roleName.trim()}`,
      token,
    );

    const creds = JSON.parse(credsJson);
    return {
      accessKeyId: creds.AccessKeyId,
      secretAccessKey: creds.SecretAccessKey,
      sessionToken: creds.Token,
    };
  }

  private httpGet(url: string, imdsToken?: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const headers: Record<string, string> = {};
      if (imdsToken) {
        headers['X-aws-ec2-metadata-token'] = imdsToken;
      }
      const req = http.get({ hostname: '169.254.169.254', path: url.replace('http://169.254.169.254', ''), headers }, (res) => {
        let data = '';
        res.on('data', (chunk) => data += chunk);
        res.on('end', () => resolve(data));
      });
      req.on('error', reject);
      req.setTimeout(5000, () => { req.destroy(); reject(new Error('Metadata request timeout')); });
    });
  }

  private async putObject(
    key: string,
    body: Buffer,
    contentType: string,
    creds: AwsCredentials,
  ): Promise<void> {
    const region = this.region;
    const bucket = this.bucket;

    const now = new Date();
    const dateStamp = now.toISOString().slice(0, 10).replace(/-/g, '');
    const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '').slice(0, 15) + 'Z';

    const host = `${bucket}.s3.${region}.amazonaws.com`;
    const payloadHash = crypto.createHash('sha256').update(body).digest('hex');

    const canonicalHeaders =
      `content-type:${contentType}\n` +
      `host:${host}\n` +
      `x-amz-content-sha256:${payloadHash}\n` +
      `x-amz-date:${amzDate}\n` +
      `x-amz-security-token:${creds.sessionToken}\n`;

    const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date;x-amz-security-token';
    const canonicalRequest = `PUT\n/${key}\n\n${canonicalHeaders}\n${signedHeaders}\n${payloadHash}`;

    const credentialScope = `${dateStamp}/${region}/s3/aws4_request`;
    const stringToSign =
      `AWS4-HMAC-SHA256\n${amzDate}\n${credentialScope}\n` +
      crypto.createHash('sha256').update(canonicalRequest).digest('hex');

    const signingKey = this.getSigningKey(creds.secretAccessKey, dateStamp, region, 's3');
    const signature = crypto.createHmac('sha256', signingKey).update(stringToSign).digest('hex');

    const authHeader =
      `AWS4-HMAC-SHA256 Credential=${creds.accessKeyId}/${credentialScope}, ` +
      `SignedHeaders=${signedHeaders}, Signature=${signature}`;

    return new Promise((resolve, reject) => {
      const req = https.request({
        hostname: host,
        path: `/${key}`,
        method: 'PUT',
        headers: {
          'Content-Type': contentType,
          'Content-Length': body.length,
          'x-amz-date': amzDate,
          'x-amz-content-sha256': payloadHash,
          'x-amz-security-token': creds.sessionToken,
          'Authorization': authHeader,
        },
      }, (res) => {
        let data = '';
        res.on('data', (chunk) => data += chunk);
        res.on('end', () => {
          console.log(`[Avatar] S3 response status: ${res.statusCode}`);
          if (res.statusCode === 200 || res.statusCode === 204) {
            resolve();
          } else {
            console.error(`[Avatar] S3 error response: ${data}`);
            reject(new Error(`S3 upload failed: ${res.statusCode} ${data}`));
          }
        });
      });
      req.on('error', (err) => {
        console.error(`[Avatar] S3 request error:`, err);
        reject(err);
      });
      req.write(body);
      req.end();
    });
  }

  private getSigningKey(secret: string, date: string, region: string, service: string): Buffer {
    const kDate = crypto.createHmac('sha256', `AWS4${secret}`).update(date).digest();
    const kRegion = crypto.createHmac('sha256', kDate).update(region).digest();
    const kService = crypto.createHmac('sha256', kRegion).update(service).digest();
    return crypto.createHmac('sha256', kService).update('aws4_request').digest();
  }
}
