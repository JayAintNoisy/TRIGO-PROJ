import { pool } from './connection';
import { logger } from '../logging/logger';
import { migrate } from './migrate';
import bcrypt from 'bcryptjs';

export const seedDatabase = async () => {
  console.log('🌱 Running database seed script...');
  logger.info('Running database seed script...');

  await migrate();

  const passwordHash = await bcrypt.hash('admin123', 10);
  const driverPasswordHash = await bcrypt.hash('driver123', 10);
  const customerPasswordHash = await bcrypt.hash('customer123', 10);

  const seedSql = `
    INSERT INTO users (id, email, password_hash, name, phone, role)
    VALUES 
      ('00000000-0000-0000-0000-000000000001', 'admin@trigo.ph', '${passwordHash}', 'Admin User', '09170000000', 'admin'),
      ('00000000-0000-0000-0000-000000000002', 'driver@trigo.ph', '${driverPasswordHash}', 'Juan Dela Cruz', '09171112222', 'driver'),
      ('00000000-0000-0000-0000-000000000003', 'customer@trigo.ph', '${customerPasswordHash}', 'Maria Clara', '09173334444', 'customer')
    ON CONFLICT (email) DO NOTHING;

    INSERT INTO municipalities (id, name, province, center_lat, center_lng, radius_km, base_fare, per_km_rate)
    VALUES 
      ('11111111-1111-1111-1111-111111111111', 'Lapu-Lapu City', 'Cebu', 10.3157, 123.9575, 15.0, 30.00, 10.00),
      ('22222222-2222-2222-2222-222222222222', 'Cordova', 'Cebu', 10.2522, 123.9508, 10.0, 30.00, 10.00)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO driver_profiles (id, user_id, municipality_id, license_number, tricycle_plate_number, tricycle_model, application_status, is_online, current_lat, current_lng)
    VALUES 
      ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'L-12345678', '123-ABC', 'Kawasaki Barako', 'approved', true, 10.3157, 123.9575)
    ON CONFLICT (id) DO NOTHING;
  `;

  try {
    await pool.query(seedSql);
    console.log('✅ Database seeding completed successfully.');
    logger.info('Database seeding completed successfully.');
  } catch (error: any) {
    console.error('❌ Database seeding failed:', error.message || error);
    logger.error('Database seeding failed:', error);
    throw new Error(`Database seeding failed: ${error.message || error}`);
  }
};

const isDirectCliCall = process.argv[1]?.includes('seed');
if (isDirectCliCall) {
  seedDatabase()
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
