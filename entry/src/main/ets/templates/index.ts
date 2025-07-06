import { LoginTemplate } from './Login';
import { SecureNoteTemplate } from './SecureNote';
import { BankAccountTemplate } from './BankAccount';
import { PaymentAccountTemplate } from './PaymentAccount';
import { SecuritiesFundTemplate } from './SecuritiesFund';
import { EmailAccountTemplate } from './EmailAccount';
import { MembershipCardTemplate } from './MembershipCard';
import { SubscriptionTemplate } from './Subscription';
import { AddressBookTemplate } from './AddressBook';
import { FamilyTemplate } from './Family';
import { CertificateTemplate } from './Certificate';
import { InsurancePolicyTemplate } from './InsurancePolicy';
import { UtilityAccountTemplate } from './UtilityAccount';
import { MedicalRecordTemplate } from './MedicalRecord';
import { LoyaltyProgramTemplate } from './LoyaltyProgram';
import { KeyCertificateTemplate } from './KeyCertificate';
import { ServerTemplate } from './Server';
import { DatabaseTemplate } from './Database';
import { IoTDeviceTemplate } from './IoTDevice';
import { VehicleInfoTemplate } from './VehicleInfo';
import { RouterTemplate } from './Router';
import { ApiCredentialTemplate } from './ApiCredential';
import { SoftwareLicenseTemplate } from './SoftwareLicense';
import { CryptoWalletTemplate } from './CryptoWallet';
import { OtherTemplate } from './Other';
import { CategoryTemplate } from './TemplateTypes';

/** 所有分类模板集合，便于批量初始化测试数据 */
export const ALL_TEMPLATES: CategoryTemplate[] = [
  LoginTemplate,
  SecureNoteTemplate,
  BankAccountTemplate,
  PaymentAccountTemplate,
  SecuritiesFundTemplate,
  EmailAccountTemplate,
  MembershipCardTemplate,
  SubscriptionTemplate,
  AddressBookTemplate,
  FamilyTemplate,
  CertificateTemplate,
  InsurancePolicyTemplate,
  UtilityAccountTemplate,
  MedicalRecordTemplate,
  LoyaltyProgramTemplate,
  KeyCertificateTemplate,
  ServerTemplate,
  DatabaseTemplate,
  IoTDeviceTemplate,
  VehicleInfoTemplate,
  RouterTemplate,
  ApiCredentialTemplate,
  SoftwareLicenseTemplate,
  CryptoWalletTemplate,
  OtherTemplate
];

export * from './TemplateTypes';
export * from './Login';
export * from './SecureNote';
export * from './BankAccount';
export * from './PaymentAccount';
export * from './SecuritiesFund';
export * from './EmailAccount';
export * from './MembershipCard';
export * from './Subscription';
export * from './AddressBook';
export * from './Family';
export * from './Certificate';
export * from './InsurancePolicy';
export * from './UtilityAccount';
export * from './MedicalRecord';
export * from './LoyaltyProgram';
export * from './KeyCertificate';
export * from './Server';
export * from './Database';
export * from './IoTDevice';
export * from './VehicleInfo';
export * from './Router';
export * from './ApiCredential';
export * from './SoftwareLicense';
export * from './CryptoWallet';
export * from './Other'; 