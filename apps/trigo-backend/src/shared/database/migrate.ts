import { pool } from './connection';
import { logger } from '../logging/logger';

export const migrate = async () => {
  const schemaSql = `
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";

    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email VARCHAR(255) UNIQUE NOT NULL,
      password_hash VARCHAR(255) NOT NULL,
      name VARCHAR(255) NOT NULL,
      phone VARCHAR(20) NOT NULL,
      role VARCHAR(20) NOT NULL CHECK (role IN ('customer', 'driver', 'admin')),
      profile_photo_url TEXT,
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS municipalities (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name VARCHAR(255) NOT NULL,
      province VARCHAR(255),
      center_lat DECIMAL(10, 8) NOT NULL,
      center_lng DECIMAL(11, 8) NOT NULL,
      radius_km DECIMAL(5, 2) NOT NULL,
      base_fare DECIMAL(10, 2) NOT NULL DEFAULT 30.00,
      per_km_rate DECIMAL(10, 2) NOT NULL DEFAULT 10.00,
      is_active BOOLEAN DEFAULT true,
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS driver_profiles (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      municipality_id UUID REFERENCES municipalities(id),
      license_number VARCHAR(50) NOT NULL,
      tricycle_plate_number VARCHAR(20) NOT NULL,
      tricycle_model VARCHAR(100),
      application_status VARCHAR(20) DEFAULT 'pending' CHECK (application_status IN ('pending', 'approved', 'rejected', 'suspended')),
      rejection_reason TEXT,
      is_online BOOLEAN DEFAULT false,
      current_lat DECIMAL(10, 8),
      current_lng DECIMAL(11, 8),
      average_rating DECIMAL(3, 2) DEFAULT 0,
      total_rides INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS driver_documents (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      driver_profile_id UUID REFERENCES driver_profiles(id) ON DELETE CASCADE,
      document_type VARCHAR(50) NOT NULL,
      document_url TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS rides (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      customer_id UUID REFERENCES users(id),
      driver_id UUID REFERENCES users(id),
      municipality_id UUID REFERENCES municipalities(id),
      pickup_lat DECIMAL(10, 8) NOT NULL,
      pickup_lng DECIMAL(11, 8) NOT NULL,
      pickup_address TEXT,
      dropoff_lat DECIMAL(10, 8) NOT NULL,
      dropoff_lng DECIMAL(11, 8) NOT NULL,
      dropoff_address TEXT,
      status VARCHAR(20) DEFAULT 'requested' CHECK (status IN ('requested', 'accepted', 'driver_arriving', 'in_progress', 'completed', 'cancelled')),
      fare_estimate DECIMAL(10, 2),
      fare_final DECIMAL(10, 2),
      distance_km DECIMAL(8, 2),
      cancellation_reason TEXT,
      cancelled_by VARCHAR(10) CHECK (cancelled_by IN ('customer', 'driver')),
      started_at TIMESTAMP,
      completed_at TIMESTAMP,
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS ride_ratings (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      ride_id UUID REFERENCES rides(id) ON DELETE CASCADE,
      customer_id UUID REFERENCES users(id),
      driver_id UUID REFERENCES users(id),
      rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
      comment TEXT,
      created_at TIMESTAMP DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS ride_tracking (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      ride_id UUID REFERENCES rides(id) ON DELETE CASCADE,
      driver_id UUID REFERENCES users(id),
      lat DECIMAL(10, 8) NOT NULL,
      lng DECIMAL(11, 8) NOT NULL,
      accuracy DECIMAL(6, 2),
      timestamp TIMESTAMP DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS payments (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      ride_id UUID REFERENCES rides(id),
      amount DECIMAL(10, 2) NOT NULL,
      method VARCHAR(20) DEFAULT 'cash' CHECK (method IN ('cash', 'gcash', 'card')),
      status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'refunded')),
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS notifications (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID REFERENCES users(id),
      title VARCHAR(255) NOT NULL,
      body TEXT NOT NULL,
      type VARCHAR(50),
      is_read BOOLEAN DEFAULT false,
      metadata JSONB,
      created_at TIMESTAMP DEFAULT NOW()
    );
  `;

  try {
    console.log('🔄 Connecting to PostgreSQL database to apply migrations...');
    await pool.query(schemaSql);
    console.log('✅ Database migrations applied successfully!');
    logger.info('Database migrations applied successfully.');
  } catch (error: any) {
    console.error('❌ Database migration failed:', error.message || error);
    logger.error('Database migration failed:', error);
    throw new Error(`Database migration failed: ${error.message || error}`);
  }
};

const isDirectCliCall = process.argv[1]?.includes('migrate');
if (isDirectCliCall) {
  migrate()
    .then(async () => {
      await pool.end().catch(() => {});
      process.exit(0);
    })
    .catch(async (err) => {
      console.error(err.message || err);
      await pool.end().catch(() => {});
      process.exit(1);
    });
}
