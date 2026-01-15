// src/database/mysql.service.ts
import { Injectable, OnModuleInit } from '@nestjs/common';
import mysql from 'mysql2/promise';

@Injectable()
export class MySQLService implements OnModuleInit {
  pool: mysql.Pool;

  async onModuleInit() {
    this.pool = mysql.createPool({
      host: process.env.MYSQL_HOST,
      user: process.env.MYSQL_USER,
      password: process.env.MYSQL_PASSWORD,
      database: process.env.MYSQL_DATABASE,
    });

    await this.pool.query('SELECT 1');
    console.log('MySQL connected');
  }
}
