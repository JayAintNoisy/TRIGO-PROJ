export interface RideMessageEntity {
  id: string;
  rideId: string;
  senderId: string;
  body: string;
  readAt: Date | null;
  createdAt: Date;
  // Joined fields
  senderName?: string;
}

export interface SendMessageInput {
  body: string;
}
