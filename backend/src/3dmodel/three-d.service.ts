import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import axios from 'axios';
import { randomUUID } from 'crypto';
import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';

const MODAL_SHAPE_URL =
  process.env.MODAL_SHAPE_URL || 'https://aliamostafa646--hunyuan3d-generate.modal.run';
const MODAL_TEXTURE_URL =
  process.env.MODAL_TEXTURE_URL || 'https://aliamostafa646--hunyuan3d-texture-status.modal.run';

const MIN_VERTICES           = 10_000;
const COLD_RETRIES           = 14;
const COLD_WAIT_MS           = 30_000;
const SHAPE_TIMEOUT_MS       = 120_000;
const TEXTURE_POLL_INTERVAL  = 30_000;
const TEXTURE_MAX_POLLS      = 100;

const BUCKET = process.env.MODELS_S3_BUCKET || 'tourasna-assets';
const REGION = process.env.AWS_REGION       || 'eu-north-1';

// Prefix for ALL 3D-related S3 keys in tourasna-assets.
const REFS_PREFIX = 'models/refs';
const GEN_PREFIX  = 'models/generated';

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * Sanitise a className to match the spec folder-naming formula:
 *   spaces → underscores, '/' → '-'
 * e.g. "Sphinx of Amenemhat III" → "Sphinx_of_Amenemhat_III"
 *      "Statue of Ra-Horakhty"   → "Statue_of_Ra-Horakhty"
 */
function sanitise(className: string): string {
  return className.replace(/ /g, '_').replace(/\//g, '-');
}

/**
 * Build the reference-view S3 folder key prefix for a monument.
 * Matches the bucket structure from the AI spec:
 *   models/refs/050_Sphinx_of_Amenemhat_III/
 */
function refFolder(classIndex: number, className: string): string {
  const idx = String(classIndex).padStart(3, '0');
  return `${REFS_PREFIX}/${idx}_${sanitise(className)}`;
}

interface ModelRow {
  class_name:      string;
  status:          'generating' | 'shape_ready' | 'textured' | 'failed';
  shape_glb_url:   string | null;
  texture_glb_url: string | null;
  texture_job_id:  string | null;
  multiview_used:  number;
  error_code:      string | null;
}

@Injectable()
export class ThreeDService implements OnModuleInit {
  private readonly logger = new Logger('ThreeDService');
  private readonly s3     = new S3Client({ region: REGION });

  // ── public API ────────────────────────────────────────────────

  async requestGeneration(className: string, classIndex: number, imageB64: string) {
    const row = await this.findByClass(className);

    if (row) {
      if (row.status === 'textured' || row.status === 'shape_ready') {
        return { status: row.status, shapeUrl: row.shape_glb_url, textureUrl: row.texture_glb_url };
      }
      if (row.status === 'generating') return { status: 'generating' };
      // failed → allow retry
      await this.updateByClass(className, { status: 'generating', error_code: null });
    } else {
      await this.insertGenerating(className);
    }

    void this.runGeneration(className, classIndex, imageB64).catch((e) =>
      this.logger.error(`runGeneration(${className}) crashed: ${e?.message || e}`),
    );
    return { status: 'generating' };
  }

  async getStatus(className: string) {
    const row = await this.findByClass(className);
    if (!row) return { status: 'not_found' };
    return {
      status:     row.status,
      shapeUrl:   row.shape_glb_url,
      textureUrl: row.texture_glb_url,
      errorCode:  row.error_code,
    };
  }

  /** Resume any texture polls interrupted by a container restart. */
  async onModuleInit() {
    try {
      const rows = await this.findResumable();
      for (const r of rows) {
        this.logger.log(`Resuming texture poll for "${r.class_name}"`);
        void this.pollTexture(r.class_name, r.texture_job_id!).catch(() => {});
      }
    } catch (e: any) {
      this.logger.warn(`Resume sweep skipped: ${e?.message || e}`);
    }
  }

  // ── background orchestration ───────────────────────────────────

  private async runGeneration(className: string, classIndex: number, imageB64: string) {
    try {
      // Fetch reference views from S3 using the spec folder scheme.
      const refs      = await this.getReferenceViews(classIndex, className);
      const multiview = refs.length === 2;

      // Priority: reference views → user scan photo → fail
      const images = refs.length > 0 ? refs : imageB64 ? [imageB64] : [];
      if (images.length === 0) {
        await this.fail(className, 'NO_IMAGES_PROVIDED');
        return;
      }

      this.logger.log(
        `Generating "${className}" (classIndex=${classIndex}, multiview=${multiview}, ` +
        `source=${refs.length > 0 ? 'reference' : 'user_scan'})`,
      );

      const result = await this.callModalShape({ images_b64: images, class_name: className, multiview });
      if (!result?.success || !result.glb_b64) {
        await this.fail(className, 'GENERATION_FAILED');
        return;
      }

      // Vertex sanity check — pure Node, no Python needed.
      const shapeBuf = Buffer.from(result.glb_b64, 'base64');
      let vertices = 0;
      try { vertices = this.countGlbVertices(shapeBuf); } catch { vertices = 0; }
      if (vertices < MIN_VERTICES) {
        this.logger.warn(`"${className}" only ${vertices} vertices (<${MIN_VERTICES})`);
        await this.fail(className, 'UNRECOGNIZED_SUBJECT');
        return;
      }

      const shapeKey = `${GEN_PREFIX}/shape_${randomUUID()}.glb`;
      await this.s3Put(shapeKey, shapeBuf, 'model/gltf-binary');
      const shapeUrl = this.publicUrl(shapeKey);

      await this.updateByClass(className, {
        status:        'shape_ready',
        shape_glb_url: shapeUrl,
        texture_job_id: result.texture_job_id || null,
        multiview_used: multiview ? 1 : 0,
        error_code:    null,
      });
      this.logger.log(`"${className}" shape_ready (${vertices} verts) → ${shapeUrl}`);

      if (result.texture_job_id) {
        void this.pollTexture(className, result.texture_job_id).catch(() => {});
      }
    } catch (e: any) {
      this.logger.error(`runGeneration(${className}) failed: ${e?.message || e}`);
      await this.fail(className, 'GENERATION_FAILED').catch(() => {});
    }
  }

  /**
   * Fetch reference views for a monument from S3.
   *
   * Priority:
   *   top + back  → 2 images, multiview=true
   *   top + side  → 2 images, multiview=true
   *   top only    → 1 image,  multiview=false  (still better than user scan)
   *   none        → []  (fallback to user scan photo)
   *
   * Folder naming matches the spec formula:
   *   {NNN}_{className_with_underscores}
   *   e.g. 050_Sphinx_of_Amenemhat_III
   */
  private async getReferenceViews(classIndex: number, className: string): Promise<string[]> {
    const folder = refFolder(classIndex, className);

    const top  = await this.s3Get(`${folder}/top.jpg`);
    if (!top) return []; // no reference at all → caller uses user scan

    const back = await this.s3Get(`${folder}/back.jpg`);
    if (back) return [top.toString('base64'), back.toString('base64')];

    const side = await this.s3Get(`${folder}/side.jpg`);
    if (side) return [top.toString('base64'), side.toString('base64')];

    // top only
    return [top.toString('base64')];
  }

  private async pollTexture(className: string, jobId: string) {
    for (let i = 0; i < TEXTURE_MAX_POLLS; i++) {
      await sleep(TEXTURE_POLL_INTERVAL);
      try {
        const r = await axios.get(MODAL_TEXTURE_URL, {
          params: { job_id: jobId }, timeout: 600_000,
          maxContentLength: Infinity,
          maxBodyLength: Infinity, validateStatus: () => true,
        });
        const data = r.data || {};
        if (data.status === 'done' && data.glb_b64) {
          const buf = Buffer.from(data.glb_b64, 'base64');
          const key = `${GEN_PREFIX}/textured_${randomUUID()}.glb`;
          await this.s3Put(key, buf, 'model/gltf-binary');
          const url = this.publicUrl(key);
          await this.updateByClass(className, { status: 'textured', texture_glb_url: url });
          this.logger.log(`"${className}" textured → ${url}`);
          return;
        }
        if (data.status === 'error') {
          this.logger.warn(`Texture job ${jobId} errored — shape still usable`);
          await this.updateByClass(className, { error_code: 'TEXTURE_FAILED' });
          return;
        }
      } catch (e: any) {
        this.logger.warn(`Texture poll transient error (${className}): ${e?.message}`);
      }
    }
    this.logger.warn(`Texture poll for "${className}" timed out — shape still available`);
  }

  private async callModalShape(payload: any): Promise<any | null> {
    for (let attempt = 1; attempt <= COLD_RETRIES; attempt++) {
      try {
        const r = await axios.post(MODAL_SHAPE_URL, payload, {
          timeout: SHAPE_TIMEOUT_MS, validateStatus: () => true,
        });
        if ([404, 408, 502, 503].includes(r.status)) {
          this.logger.log(`Modal cold start, retry ${attempt}/${COLD_RETRIES}`);
          await sleep(COLD_WAIT_MS);
          continue;
        }
        return r.data;
      } catch {
        this.logger.log(`Modal attempt ${attempt} timeout; retrying`);
        await sleep(COLD_WAIT_MS);
      }
    }
    this.logger.error('Modal unreachable after all retries');
    return null;
  }

  private countGlbVertices(buf: Buffer): number {
    if (buf.length < 20 || buf.readUInt32LE(0) !== 0x46546c67) throw new Error('not GLB');
    const jsonLen = buf.readUInt32LE(12);
    const json    = JSON.parse(buf.slice(20, 20 + jsonLen).toString('utf8'));
    const acc: any[] = json.accessors || [];
    let total = 0;
    for (const mesh of json.meshes || []) {
      for (const prim of mesh.primitives || []) {
        const pos = prim.attributes?.POSITION;
        if (pos != null && acc[pos]) total += acc[pos].count || 0;
      }
    }
    return total;
  }

  private async fail(className: string, code: string) {
    await this.updateByClass(className, { status: 'failed', error_code: code });
  }

  // ── DB (mysql2 pool — swap for your shared provider if preferred) ──

  private pool = require('mysql2/promise').createPool({
    host:            process.env.DB_HOST     || 'mysql',
    port:            Number(process.env.DB_PORT || 3306),
    user:            process.env.DB_USER     || 'tourasna',
    password:        process.env.DB_PASSWORD || 'strongpassword',
    database:        process.env.DB_NAME     || 'tourasna',
    connectionLimit: 3,
  });

  private async findByClass(className: string): Promise<ModelRow | null> {
    const [rows] = await this.pool.query(
      'SELECT * FROM model_glbs WHERE class_name = ? LIMIT 1', [className],
    );
    return (rows as ModelRow[])[0] || null;
  }

  private async insertGenerating(className: string) {
    await this.pool.query(
      `INSERT INTO model_glbs (class_name, status) VALUES (?, 'generating')
       ON DUPLICATE KEY UPDATE status='generating', error_code=NULL`,
      [className],
    );
  }

  private async updateByClass(className: string, fields: Partial<ModelRow>) {
    const keys = Object.keys(fields);
    if (!keys.length) return;
    const set  = keys.map((k) => `${k} = ?`).join(', ');
    const vals = keys.map((k) => (fields as any)[k]);
    await this.pool.query(
      `UPDATE model_glbs SET ${set} WHERE class_name = ?`, [...vals, className],
    );
  }

  private async findResumable(): Promise<ModelRow[]> {
    const [rows] = await this.pool.query(
      `SELECT * FROM model_glbs
       WHERE status='shape_ready' AND texture_glb_url IS NULL AND texture_job_id IS NOT NULL`,
    );
    return rows as ModelRow[];
  }

  // ── S3 ─────────────────────────────────────────────────────────

  private async s3Get(key: string): Promise<Buffer | null> {
    try {
      const out = await this.s3.send(new GetObjectCommand({ Bucket: BUCKET, Key: key }));
      const chunks: Buffer[] = [];
      for await (const c of out.Body as any) chunks.push(Buffer.from(c));
      return Buffer.concat(chunks);
    } catch {
      return null;
    }
  }

  private async s3Put(key: string, body: Buffer, contentType: string) {
    await this.s3.send(
      new PutObjectCommand({ Bucket: BUCKET, Key: key, Body: body, ContentType: contentType }),
    );
  }

  private publicUrl(key: string): string {
    return `https://${BUCKET}.s3.${REGION}.amazonaws.com/${encodeURI(key)}`;
  }
}
