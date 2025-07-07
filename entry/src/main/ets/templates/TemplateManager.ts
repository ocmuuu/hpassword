import { CategoryTemplate } from './TemplateTypes';
import {
  LoginTemplate, SecureNoteTemplate, BankAccountTemplate, PaymentAccountTemplate,
  SecuritiesFundTemplate, EmailAccountTemplate, MembershipCardTemplate, SubscriptionTemplate,
  AddressBookTemplate, FamilyTemplate, CertificateTemplate, InsurancePolicyTemplate,
  UtilityAccountTemplate, MedicalRecordTemplate, LoyaltyProgramTemplate, KeyCertificateTemplate,
  ServerTemplate, DatabaseTemplate, IoTDeviceTemplate, VehicleInfoTemplate,
  RouterTemplate, ApiCredentialTemplate, SoftwareLicenseTemplate, CryptoWalletTemplate,
  OtherTemplate
} from './index';

/**
 * 模板管理器类
 * 负责模板查找和映射逻辑
 */
export class TemplateManager {
  // 所有可用的模板
  private static readonly ALL_TEMPLATES: CategoryTemplate[] = [
    LoginTemplate, SecureNoteTemplate, BankAccountTemplate, PaymentAccountTemplate,
    SecuritiesFundTemplate, EmailAccountTemplate, MembershipCardTemplate, SubscriptionTemplate,
    AddressBookTemplate, FamilyTemplate, CertificateTemplate, InsurancePolicyTemplate,
    UtilityAccountTemplate, MedicalRecordTemplate, LoyaltyProgramTemplate, KeyCertificateTemplate,
    ServerTemplate, DatabaseTemplate, IoTDeviceTemplate, VehicleInfoTemplate,
    RouterTemplate, ApiCredentialTemplate, SoftwareLicenseTemplate, CryptoWalletTemplate,
    OtherTemplate
  ];

  // 英文组名到中文模板名的映射关系
  private static readonly ENGLISH_NAME_MAPPING: Record<string, string> = {
    'Login': LoginTemplate.name,
    'SecureNote': SecureNoteTemplate.name,
    'BankAccount': BankAccountTemplate.name,
    'PaymentAccount': PaymentAccountTemplate.name,
    'SecuritiesFund': SecuritiesFundTemplate.name,
    'EmailAccount': EmailAccountTemplate.name,
    'MembershipCard': MembershipCardTemplate.name,
    'Subscription': SubscriptionTemplate.name,
    'AddressBook': AddressBookTemplate.name,
    'Family': FamilyTemplate.name,
    'Certificate': CertificateTemplate.name,
    'InsurancePolicy': InsurancePolicyTemplate.name,
    'UtilityAccount': UtilityAccountTemplate.name,
    'MedicalRecord': MedicalRecordTemplate.name,
    'LoyaltyProgram': LoyaltyProgramTemplate.name,
    'KeyCertificate': KeyCertificateTemplate.name,
    'Server': ServerTemplate.name,
    'Database': DatabaseTemplate.name,
    'IoTDevice': IoTDeviceTemplate.name,
    'VehicleInfo': VehicleInfoTemplate.name,
    'Router': RouterTemplate.name,
    'ApiCredential': ApiCredentialTemplate.name,
    'SoftwareLicense': SoftwareLicenseTemplate.name,
    'CryptoWallet': CryptoWalletTemplate.name,
    'Other': OtherTemplate.name
  };

  /**
   * 根据组名获取对应的模板
   * @param groupName 组名（中文或英文）
   * @returns 匹配的模板或undefined
   */
  static getTemplateByGroupName(groupName: string): CategoryTemplate | undefined {
    // 首先尝试中文名称精确匹配
    let matchedTemplate = this.ALL_TEMPLATES.find(template => template.name === groupName);
    
    // 如果没有找到，尝试通过英文名称映射
    if (!matchedTemplate) {
      const chineseName = this.ENGLISH_NAME_MAPPING[groupName];
      if (chineseName) {
        matchedTemplate = this.ALL_TEMPLATES.find(template => template.name === chineseName);
      }
    }
    
    // 如果仍未找到，尝试大小写不敏感的英文匹配
    if (!matchedTemplate) {
      const matchedEnglishKey = Object.keys(this.ENGLISH_NAME_MAPPING).find(key => 
        key.toLowerCase() === groupName.toLowerCase()
      );
      if (matchedEnglishKey) {
        const chineseName = this.ENGLISH_NAME_MAPPING[matchedEnglishKey];
        matchedTemplate = this.ALL_TEMPLATES.find(template => template.name === chineseName);
      }
    }
    
    return matchedTemplate;
  }

  /**
   * 获取所有模板
   * @returns 所有可用的模板数组
   */
  static getAllTemplates(): CategoryTemplate[] {
    return [...this.ALL_TEMPLATES];
  }

  /**
   * 获取所有系统模板名称（中文）
   * @returns 系统模板的中文名称数组
   */
  static getSystemTemplateNames(): string[] {
    return this.ALL_TEMPLATES.map(template => template.name);
  }

  /**
   * 检查是否为系统模板
   * @param groupName 组名
   * @returns 是否为系统模板
   */
  static isSystemTemplate(groupName: string): boolean {
    return this.getTemplateByGroupName(groupName) !== undefined;
  }

  /**
   * 获取英文到中文的映射关系
   * @returns 英文组名到中文模板名的映射
   */
  static getEnglishNameMapping(): Record<string, string> {
    return { ...this.ENGLISH_NAME_MAPPING };
  }
} 