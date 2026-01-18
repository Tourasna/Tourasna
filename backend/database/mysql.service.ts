import { Injectable, OnModuleInit } from '@nestjs/common';
import mysql, { Pool } from 'mysql2/promise';

@Injectable()
export class MySQLService implements OnModuleInit {
  public pool: Pool;

  private async createPool() {
    this.pool = mysql.createPool({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      port: Number(process.env.DB_PORT),
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
    });
  }

  async onModuleInit() {
    const maxRetries = 20;
    const delay = 3000;

    for (let i = 1; i <= maxRetries; i++) {
      try {
        await this.createPool();
        await this.pool.query('SELECT 1');
        console.log('MySQL connected');
        return;
      } catch (err) {
        console.log(`MySQL not ready (attempt ${i}/${maxRetries})`);
        if (i === maxRetries) {
          throw err;
        }
        await new Promise(res => setTimeout(res, delay));
      }
    }
  }

  getPool(): Pool {
    return this.pool;
  }
}
