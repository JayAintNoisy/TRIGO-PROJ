export interface NotificationEntity {
  id: string;
  userId: string;
  title: string;
  body: string;
  type?: string | null;
  isRead: boolean;
  metadata?: Record<string, any> | null;
  createdAt: Date;
}

export interface RegisterDeviceInput {
  fcmToken: string;
  platform: 'android' | 'ios' | 'web';
}
