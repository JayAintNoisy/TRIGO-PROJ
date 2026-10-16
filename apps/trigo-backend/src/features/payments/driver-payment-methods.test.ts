import { describe, it, expect, vi, beforeEach } from 'vitest';
import { DriverPaymentMethodsService } from './driver-payment-methods.service';
import {
  DriverPaymentMethodsRepository,
  parsePaymentMethodSummaries,
  withBuiltInCash,
} from './driver-payment-methods.repository';
import { DriversRepository } from '../drivers/drivers.repository';
import { PAYMENT_METHOD } from '../../shared/constants/payment-status';
import { DRIVER_APPLICATION_STATUS } from '../../shared/constants/roles';

const driverProfile = {
  id: '33333333-3333-3333-3333-333333333333',
  userId: '00000000-0000-0000-0000-000000000002',
  municipalityId: '11111111-1111-1111-1111-111111111111',
  licenseNumber: 'N01-12-345678',
  tricyclePlateNumber: '123-ABC',
  tricycleModel: 'Kawasaki Barako 175',
  applicationStatus: DRIVER_APPLICATION_STATUS.APPROVED,
  isOnline: true,
  currentLat: 8.158,
  currentLng: 125.129,
  averageRating: 4.8,
  totalRides: 42,
  createdAt: new Date(),
  updatedAt: new Date(),
};

describe('DriverPaymentMethodsService', () => {
  const service = new DriverPaymentMethodsService();

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('lists the full catalog with cash on and the e-wallets off', async () => {
    vi.spyOn(DriversRepository.prototype, 'findByUserId').mockResolvedValue(driverProfile);
    vi.spyOn(DriverPaymentMethodsRepository.prototype, 'findByProfileId').mockResolvedValue([]);

    const methods = await service.getOwnPaymentMethods(driverProfile.userId);

    expect(methods.map((m) => m.method)).toEqual([
      PAYMENT_METHOD.CASH,
      PAYMENT_METHOD.GCASH,
      PAYMENT_METHOD.MAYA,
      PAYMENT_METHOD.GOTYME,
      PAYMENT_METHOD.MARIBANK,
    ]);
    expect(methods[0].isEnabled).toBe(true);
    expect(methods.slice(1).every((m) => m.isEnabled === false)).toBe(true);
  });

  it('reflects a stored method that has been switched on', async () => {
    vi.spyOn(DriversRepository.prototype, 'findByUserId').mockResolvedValue(driverProfile);
    vi.spyOn(DriverPaymentMethodsRepository.prototype, 'findByProfileId').mockResolvedValue([
      {
        id: 'pm-1',
        driverProfileId: driverProfile.id,
        method: PAYMENT_METHOD.GCASH,
        isEnabled: true,
        qrCodeUrl: '/uploads/payment-qr/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.png',
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);

    const methods = await service.getOwnPaymentMethods(driverProfile.userId);
    const gcash = methods.find((m) => m.method === PAYMENT_METHOD.GCASH);

    expect(gcash?.isEnabled).toBe(true);
    expect(gcash?.qrCodeUrl).toContain('/uploads/payment-qr/');
  });

  it('refuses to change the always-on cash method', async () => {
    await expect(
      service.updateOwnPaymentMethod(driverProfile.userId, PAYMENT_METHOD.CASH, { isEnabled: false })
    ).rejects.toThrow('Cash is always available and cannot be changed');
  });

  it('rejects a method outside the driver catalog', async () => {
    await expect(
      service.updateOwnPaymentMethod(driverProfile.userId, PAYMENT_METHOD.CARD, { isEnabled: true })
    ).rejects.toThrow('Unsupported payment method');
  });

  it('requires a QR code before a method can be enabled', async () => {
    vi.spyOn(DriversRepository.prototype, 'findByUserId').mockResolvedValue(driverProfile);
    vi.spyOn(DriverPaymentMethodsRepository.prototype, 'findByProfileAndMethod').mockResolvedValue(null);

    await expect(
      service.updateOwnPaymentMethod(driverProfile.userId, PAYMENT_METHOD.MAYA, { isEnabled: true })
    ).rejects.toThrow('Upload a QR code before enabling this payment method');
  });

  it('enables a method once its QR code is uploaded', async () => {
    const qrCodeUrl = '/uploads/payment-qr/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.png';
    vi.spyOn(DriversRepository.prototype, 'findByUserId').mockResolvedValue(driverProfile);
    vi.spyOn(DriverPaymentMethodsRepository.prototype, 'findByProfileAndMethod').mockResolvedValue(null);
    const upsertSpy = vi.spyOn(DriverPaymentMethodsRepository.prototype, 'upsert').mockResolvedValue({
      id: 'pm-2',
      driverProfileId: driverProfile.id,
      method: PAYMENT_METHOD.GCASH,
      isEnabled: true,
      qrCodeUrl,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const updated = await service.updateOwnPaymentMethod(driverProfile.userId, PAYMENT_METHOD.GCASH, {
      isEnabled: true,
      qrCodeUrl,
    });

    expect(upsertSpy).toHaveBeenCalledWith(driverProfile.id, PAYMENT_METHOD.GCASH, true, qrCodeUrl);
    expect(updated).toEqual({
      method: PAYMENT_METHOD.GCASH,
      isEnabled: true,
      qrCodeUrl,
    });
  });

  it('keeps the stored QR code when a method is switched off', async () => {
    const qrCodeUrl = '/uploads/payment-qr/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.png';
    vi.spyOn(DriversRepository.prototype, 'findByUserId').mockResolvedValue(driverProfile);
    vi.spyOn(DriverPaymentMethodsRepository.prototype, 'findByProfileAndMethod').mockResolvedValue({
      id: 'pm-2',
      driverProfileId: driverProfile.id,
      method: PAYMENT_METHOD.GCASH,
      isEnabled: true,
      qrCodeUrl,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    const upsertSpy = vi.spyOn(DriverPaymentMethodsRepository.prototype, 'upsert').mockResolvedValue({
      id: 'pm-2',
      driverProfileId: driverProfile.id,
      method: PAYMENT_METHOD.GCASH,
      isEnabled: false,
      qrCodeUrl,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const updated = await service.updateOwnPaymentMethod(driverProfile.userId, PAYMENT_METHOD.GCASH, {
      isEnabled: false,
    });

    expect(upsertSpy).toHaveBeenCalledWith(driverProfile.id, PAYMENT_METHOD.GCASH, false, null);
    expect(updated.isEnabled).toBe(false);
    expect(updated.qrCodeUrl).toBe(qrCodeUrl);
  });

  it('requires an approved driver profile', async () => {
    vi.spyOn(DriversRepository.prototype, 'findByUserId').mockResolvedValue(null);

    await expect(service.getOwnPaymentMethods('ghost-user')).rejects.toThrow('Driver profile not found');
  });

  it('reports cash first for passenger-facing lists', async () => {
    vi.spyOn(DriverPaymentMethodsRepository.prototype, 'findEnabledMethodsByDriverUserId')
      .mockResolvedValue([PAYMENT_METHOD.MAYA]);

    const enabled = await service.getEnabledMethodsByDriverUserId(driverProfile.userId);
    expect(enabled).toEqual([PAYMENT_METHOD.CASH, PAYMENT_METHOD.MAYA]);
  });
});

describe('payment method payload helpers', () => {
  it('parses the aggregated json column and ignores malformed rows', () => {
    expect(parsePaymentMethodSummaries('not-an-array')).toEqual([]);
    expect(
      parsePaymentMethodSummaries([
        { method: 'gcash', qrCodeUrl: '/uploads/payment-qr/x.png' },
        { qrCodeUrl: null },
        null,
      ])
    ).toEqual([{ method: PAYMENT_METHOD.GCASH, qrCodeUrl: '/uploads/payment-qr/x.png' }]);
  });

  it('always places the built-in cash method first', () => {
    const merged = withBuiltInCash([
      { method: PAYMENT_METHOD.GCASH, qrCodeUrl: '/uploads/payment-qr/x.png' },
      { method: PAYMENT_METHOD.CASH, qrCodeUrl: null },
    ]);

    expect(merged).toEqual([
      { method: PAYMENT_METHOD.CASH, qrCodeUrl: null },
      { method: PAYMENT_METHOD.GCASH, qrCodeUrl: '/uploads/payment-qr/x.png' },
    ]);
  });
});
