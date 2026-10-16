import { DRIVER_APPLICATION_STATUS } from '../../shared/constants/roles';
import { DriverPaymentMethodSummary } from '../payments/payments.types';

export interface DriverProfileEntity {
  id: string;
  userId: string;
  municipalityId: string;
  licenseNumber: string;
  tricyclePlateNumber: string;
  tricycleModel?: string | null;
  applicationStatus: DRIVER_APPLICATION_STATUS;
  rejectionReason?: string | null;
  isOnline: boolean;
  currentLat?: number | null;
  currentLng?: number | null;
  averageRating: number;
  totalRides: number;
  createdAt: Date;
  updatedAt: Date;
  // Joined fields
  userName?: string;
  userPhone?: string;
  userEmail?: string;
  municipalityName?: string;
  documents?: DriverDocumentEntity[];
  /// Payment methods this driver accepts (cash always first). Lets a passenger
  /// see accepted methods while choosing a driver.
  paymentMethods?: DriverPaymentMethodSummary[];
}

export interface DriverDocumentEntity {
  id: string;
  driverProfileId: string;
  documentType: string;
  documentUrl: string;
  createdAt: Date;
}

export interface DriverApplicationInput {
  municipalityId: string;
  licenseNumber: string;
  tricyclePlateNumber: string;
  tricycleModel?: string;
  documents: {
    documentType: string;
    documentUrl: string;
  }[];
}
